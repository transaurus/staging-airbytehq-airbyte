#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/airbytehq/airbyte"
BRANCH="master"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR/docusaurus"

# --- Node version ---
# package.json engines: "node": ">=20 <22", Volta pin: 20.20.0
# System Node 20.x satisfies this. Verify.
node_major=$(node --version | cut -d. -f1 | tr -d 'v')
if [ "$node_major" -lt 20 ] || [ "$node_major" -ge 22 ]; then
    echo "[ERROR] Node version $(node --version) does not satisfy >=20 <22"
    exit 1
fi
echo "[INFO] Node $(node --version) OK"

# --- Package manager: pnpm 9.4.0 ---
if ! command -v pnpm &>/dev/null || [ "$(pnpm --version | cut -d. -f1)" != "9" ]; then
    echo "[INFO] Installing pnpm 9.4.0..."
    npm install -g pnpm@9.4.0
fi
echo "[INFO] pnpm $(pnpm --version) OK"

# --- Dependencies ---
# Use --ignore-scripts to avoid postman-code-generators postinstall failure
# (that package has a broken yarn corepack setup in its sub-packages).
# We manually run the critical postinstall scripts after.
pnpm install --frozen-lockfile --ignore-scripts
# Run critical native-module postinstall scripts
node node_modules/@swc/core/postinstall.js 2>/dev/null || true
(cd node_modules/@parcel/watcher && node scripts/build-from-source.js) 2>/dev/null || true

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

echo "[DONE] Repository is ready for docusaurus commands."
