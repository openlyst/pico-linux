#!/bin/bash
#
# Pico Neo 2 — Restore original Android
#
# Flashes all original backup images via EDL to restore the device
# to a bootable Android state.
#
# Usage: ./restore-android.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/flash-edl.sh" restore
