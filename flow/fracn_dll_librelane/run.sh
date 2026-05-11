#!/bin/bash
# Run LibreLane to harden the DLL macro
#
# Prerequisites:
#   export PDK_ROOT=/path/to/sky130A
#   LibreLane installed (pip install librelane or docker)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PDK="${PDK_ROOT:?PDK_ROOT must be set}/sky130A"

librelane --config "$SCRIPT_DIR/config.json" \
    --pdk "$PDK" \
    --output "$SCRIPT_DIR/runs" \
    "$@"
