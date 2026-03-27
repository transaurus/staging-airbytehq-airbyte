#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for airbytehq/airbyte
# Runs on existing source tree (already in docusaurus/ directory). Installs deps, runs pre-build steps, builds.

# --- Node version ---
# package.json engines: "node": ">=20 <22", Volta pin: 20.20.0
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
pnpm install --frozen-lockfile

# --- Build (prebuild hook runs automatically: prepare-registry-cache, prepare-agent-connector-manifest, prepare-agent-engine-api) ---
# Airbyte docs is a large site; increase Node heap to avoid OOM during Rspack/docusaurus build
export NODE_OPTIONS="--max-old-space-size=6144"
pnpm run build

echo "[DONE] Build complete."
