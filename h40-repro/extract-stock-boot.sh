#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
	echo "Usage: $0 STOCK_BOOT_IMG [OUTPUT_DIR]" >&2
	exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOT_IMAGE="$(realpath "$1")"
OUTPUT_DIR="${2:-stock-boot-extracted}"

[[ -f "${BOOT_IMAGE}" ]] || { echo "Not a file: ${BOOT_IMAGE}" >&2; exit 1; }
python3 "${SCRIPT_DIR}/extract-boot.py" "${BOOT_IMAGE}" "${OUTPUT_DIR}"
