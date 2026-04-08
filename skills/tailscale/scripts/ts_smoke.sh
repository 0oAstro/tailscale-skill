#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Safe read-only smoke checks — no API key or network required.

"$SCRIPT_DIR/ts_catalog.sh" --search list --method GET >/dev/null
"$SCRIPT_DIR/ts_call.sh" listTailnetDevices \
  --params-json '{"tailnet":"example.ts.net"}' \
  --dry-run >/dev/null

echo "OK: tailscale scripts smoke checks passed"
