#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
	echo "Usage: $0 STOCK_BOOT_IMG [REBUILT_IMAGE] [REPORT]" >&2
	exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANDROID_ROOT="$(cd "${KERNEL_DIR}/../.." && pwd)"
BOOT_IMAGE="$(realpath "$1")"
REBUILT_IMAGE="${2:-${ANDROID_ROOT}/out/h40-artifacts/arch/arm64/boot/Image}"
REPORT="${3:-${SCRIPT_DIR}/stock-kernel-comparison.txt}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

"${SCRIPT_DIR}/extract-stock-boot.sh" "${BOOT_IMAGE}" "${WORK_DIR}/stock" >/dev/null
STOCK_IMAGE="${WORK_DIR}/stock/Image"
[[ -f "${REBUILT_IMAGE}" ]] || { echo "Missing rebuild: ${REBUILT_IMAGE}" >&2; exit 1; }

stock_hash="$(sha256sum "${STOCK_IMAGE}" | awk '{print $1}')"
rebuild_hash="$(sha256sum "${REBUILT_IMAGE}" | awk '{print $1}')"
if cmp -s "${STOCK_IMAGE}" "${REBUILT_IMAGE}"; then
	result=IDENTICAL
	difference=none
else
	result=DIFFERENT
	difference="$(cmp "${STOCK_IMAGE}" "${REBUILT_IMAGE}" 2>&1 || true)"
fi

mkdir -p "$(dirname "${REPORT}")"
{
	echo "result=${result}"
	echo "stock_raw_image_sha256=${stock_hash}"
	echo "rebuilt_image_sha256=${rebuild_hash}"
	echo "stock_size=$(stat -c %s "${STOCK_IMAGE}")"
	echo "rebuilt_size=$(stat -c %s "${REBUILT_IMAGE}")"
	echo "first_difference=${difference}"
	echo
	echo "stock_banner:"
	strings "${STOCK_IMAGE}" | grep -m1 '^Linux version ' || true
	echo
	echo "rebuilt_banner:"
	strings "${REBUILT_IMAGE}" | grep -m1 '^Linux version ' || true
} > "${REPORT}"

if [[ "${result}" == DIFFERENT ]] && command -v diffoscope >/dev/null 2>&1; then
	diffoscope "${STOCK_IMAGE}" "${REBUILT_IMAGE}" \
		> "${REPORT%.txt}.diffoscope.txt" || true
fi

cat "${REPORT}"
[[ "${result}" == IDENTICAL ]]
