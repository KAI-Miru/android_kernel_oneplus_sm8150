#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: h40-repro/build-h40.sh [--clean|--incremental]

Required toolchain environment:
  CLANG_DIR          directory containing bin/clang
  GCC64_DIR          AArch64 Android 4.9 binutils directory
  GCC32_DIR          ARM Android 4.9 binutils directory
  AOSP_BUILD_TOOLS   AOSP build-tools linux-x86 directory

Optional environment:
  ANDROID_ROOT, KERNEL_DIR, OUT_DIR, DTS_OUT_DIR, ARTIFACT_DIR, BUILD_LOG
  STOCK_CONFIG, CONFIG_MODE=stock|official, JOBS
  MODULE_SIGNING_KEY, STOCK_BOOT_IMAGE, EXTERNAL_DTC
  SKIP_PRODUCTION_DTS=1

Use a fixed MODULE_SIGNING_KEY and the same OUT_DIR for deterministic builds.
The supplied key must be a combined PEM accepted by certs/Makefile.
EOF
}

action=incremental
case "${1:-}" in
	--clean) action=clean ;;
	--incremental|'') ;;
	-h|--help) usage; exit 0 ;;
	*) usage >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="${KERNEL_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
ANDROID_ROOT="${ANDROID_ROOT:-$(cd "${KERNEL_DIR}/../.." && pwd)}"
OUT_DIR="${OUT_DIR:-${ANDROID_ROOT}/out/h40-kernel}"
DTS_OUT_DIR="${DTS_OUT_DIR:-${OUT_DIR}-production-dts}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${ANDROID_ROOT}/out/h40-artifacts}"
BUILD_LOG="${BUILD_LOG:-${ANDROID_ROOT}/out/h40-build.log}"
STOCK_CONFIG="${STOCK_CONFIG:-${SCRIPT_DIR}/config/GM1911_11_H.40.config}"
CONFIG_MODE="${CONFIG_MODE:-stock}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN)}"

: "${CLANG_DIR:?Set CLANG_DIR to the AOSP/Qualcomm Clang directory}"
: "${GCC64_DIR:?Set GCC64_DIR to the AArch64 Android 4.9 directory}"
: "${GCC32_DIR:?Set GCC32_DIR to the ARM Android 4.9 directory}"
: "${AOSP_BUILD_TOOLS:?Set AOSP_BUILD_TOOLS to build-tools/linux-x86}"

CLANG="${CLANG_DIR}/bin/clang"
CROSS64="${GCC64_DIR}/bin/aarch64-linux-android-"
CROSS32="${GCC32_DIR}/bin/arm-linux-androideabi-"
PYTHON2="${AOSP_BUILD_TOOLS}/bin/py2-cmd"
H40_AOSP_TOYBOX="${AOSP_BUILD_TOOLS}/bin/toybox"
H40_AOSP_BC="${AOSP_BUILD_TOOLS}/bin/gavinhoward-bc"

require_file() { [[ -e "$1" ]] || { echo "Required path missing: $1" >&2; exit 1; }; }
require_exec() { [[ -x "$1" ]] || { echo "Required executable missing: $1" >&2; exit 1; }; }

require_file "${KERNEL_DIR}/Makefile"
require_file "${KERNEL_DIR}/AndroidKernel.mk"
require_file "${ANDROID_ROOT}/vendor"
require_exec "${CLANG}"
require_exec "${CROSS64}ld"
require_exec "${CROSS32}ld"
require_exec "${PYTHON2}"
require_exec "${H40_AOSP_TOYBOX}"
require_exec "${H40_AOSP_BC}"
[[ "${CONFIG_MODE}" == stock || "${CONFIG_MODE}" == official ]] || {
	echo "CONFIG_MODE must be stock or official" >&2; exit 2;
}

if [[ "${action}" == clean ]]; then rm -rf "${OUT_DIR}" "${DTS_OUT_DIR}" "${ARTIFACT_DIR}"; fi
mkdir -p "${OUT_DIR}" "${ARTIFACT_DIR}" "$(dirname "${BUILD_LOG}")"

H40_REAL_CPIO=""
if command -v cpio >/dev/null 2>&1; then
	candidate="$(command -v cpio)"
	if "${candidate}" --help 2>&1 | grep -q -- '--quiet'; then H40_REAL_CPIO="${candidate}"; fi
fi
H40_REAL_TAR="$(command -v tar)"
export H40_REAL_CPIO H40_REAL_TAR H40_AOSP_TOYBOX H40_AOSP_BC
export PATH="${SCRIPT_DIR}/host-tools:${AOSP_BUILD_TOOLS}/bin:${CLANG_DIR}/bin:${GCC64_DIR}/bin:${GCC32_DIR}/bin:${PATH}"

export ARCH=arm64 SUBARCH=arm64
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-root}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-dg02-pool03-kvm154}"
export KBUILD_BUILD_VERSION="${KBUILD_BUILD_VERSION:-1}"
export KBUILD_BUILD_TIMESTAMP="${KBUILD_BUILD_TIMESTAMP:-Thu Mar 23 18:39:49 CST 2023}"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1679567989}"

make_args=(
	"O=${OUT_DIR}" "ARCH=arm64" "TARGET_PRODUCT=msmnile"
	"BRAND_SHOW_FLAG=oneplus" "TARGET_BUILD_VARIANT=user"
	"CROSS_COMPILE=${CROSS64}" "CROSS_COMPILE_ARM32=${CROSS32}"
	"REAL_CC=${CLANG}" "CLANG_TRIPLE=aarch64-linux-gnu-" "PYTHON=${PYTHON2}"
	"HOSTCC=gcc" "HOSTCXX=g++" "LOCALVERSION=+"
)

configure_stock() {
	require_file "${STOCK_CONFIG}"
	cp "${STOCK_CONFIG}" "${OUT_DIR}/.config"
	sed -i 's/\r$//' "${OUT_DIR}/.config"
	make -C "${KERNEL_DIR}" "${make_args[@]}" olddefconfig
}

if [[ ! -f "${OUT_DIR}/.config" || "${action}" == clean ]]; then
	if [[ "${CONFIG_MODE}" == stock ]]; then configure_stock
	else make -C "${KERNEL_DIR}" "${make_args[@]}" vendor/sm8150-perf_defconfig; fi
fi

if [[ -n "${MODULE_SIGNING_KEY:-}" ]]; then
	require_file "${MODULE_SIGNING_KEY}"
	mkdir -p "${OUT_DIR}/certs"
	cp "${SCRIPT_DIR}/host-tools/x509.genkey" "${OUT_DIR}/certs/x509.genkey"
	cp "${MODULE_SIGNING_KEY}" "${OUT_DIR}/certs/signing_key.pem"
else
	echo "WARNING: no fixed MODULE_SIGNING_KEY; the build will create a random test key." >&2
fi

{
	echo "kernel_dir=${KERNEL_DIR}"
	echo "android_root=${ANDROID_ROOT}"
	echo "out_dir=${OUT_DIR}"
	echo "dts_out_dir=${DTS_OUT_DIR}"
	echo "artifact_dir=${ARTIFACT_DIR}"
	echo "config_mode=${CONFIG_MODE}"
	echo "stock_config=${STOCK_CONFIG}"
	echo "jobs=${JOBS}"
	echo "KBUILD_BUILD_USER=${KBUILD_BUILD_USER}"
	echo "KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST}"
	echo "KBUILD_BUILD_VERSION=${KBUILD_BUILD_VERSION}"
	echo "KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP}"
	echo "SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
	"${CLANG}" --version | head -n 1
	"${CROSS64}ld" --version | head -n 1
	printf 'command: make -C %q -j%s' "${KERNEL_DIR}" "${JOBS}"
	printf ' %q' "${make_args[@]}"
	echo ' Image Image.gz Image.gz-dtb dtbs modules'
} | tee "${BUILD_LOG}"

set -o pipefail
make -C "${KERNEL_DIR}" -j"${JOBS}" V=0 "${make_args[@]}" \
	Image Image.gz Image.gz-dtb dtbs modules 2>&1 | tee -a "${BUILD_LOG}"

if [[ "${SKIP_PRODUCTION_DTS:-0}" != 1 ]]; then
	dts_make_args=("${make_args[@]}")
	dts_make_args[0]="O=${DTS_OUT_DIR}"
	mkdir -p "${DTS_OUT_DIR}"
	cp "${OUT_DIR}/.config" "${DTS_OUT_DIR}/.config"
	make -C "${KERNEL_DIR}" "${dts_make_args[@]}" olddefconfig 2>&1 | tee -a "${BUILD_LOG}"
	production_base_dts=()
	for project in 18821 18857 18865 19801 19863; do
		for tree in sm8150 sm8150-v2 sm8150p sm8150p-v2; do
			production_base_dts+=("${project}/${tree}.dtb")
		done
	done
	{
		printf 'base device-tree command: make -C %q -j%s' "${KERNEL_DIR}" "${JOBS}"
		printf ' %q' "${dts_make_args[@]}" CONFIG_BUILD_ARM64_DT_OVERLAY=y 'DTC_FLAGS=-@ -H epapr'
		printf ' %q' "${production_base_dts[@]}"
		echo
		echo "WARNING: stock also contains project 19861/18961 trees; that source is absent from the official repositories."
	} | tee -a "${BUILD_LOG}"
	make -C "${KERNEL_DIR}" -j"${JOBS}" V=0 "${dts_make_args[@]}" \
		CONFIG_BUILD_ARM64_DT_OVERLAY=y DTC_FLAGS='-@ -H epapr' \
		"${production_base_dts[@]}" 2>&1 | tee -a "${BUILD_LOG}"
	if [[ -n "${EXTERNAL_DTC:-}" ]]; then
		require_exec "${EXTERNAL_DTC}"
		make -C "${KERNEL_DIR}" -j"${JOBS}" V=0 "${dts_make_args[@]}" \
			CONFIG_BUILD_ARM64_DT_OVERLAY=y DTC_FLAGS='-@ -H epapr' \
			DTC="${EXTERNAL_DTC}" dtbs 2>&1 | tee -a "${BUILD_LOG}"
	else
		echo "WARNING: overlay DTBOs skipped: bundled DTC 1.4.4 cannot parse the published overlay syntax; set EXTERNAL_DTC to a compatible AOSP DTC." | tee -a "${BUILD_LOG}" >&2
	fi
fi

rm -rf "${ARTIFACT_DIR}"
mkdir -p "${ARTIFACT_DIR}"
copy_output() {
	local source="$1" rel
	[[ -f "${source}" ]] || return 0
	rel="${source#${OUT_DIR}/}"
	mkdir -p "${ARTIFACT_DIR}/$(dirname "${rel}")"
	cp "${source}" "${ARTIFACT_DIR}/${rel}"
}

for rel in .config vmlinux System.map Module.symvers modules.order modules.builtin \
	modules.builtin.modinfo arch/arm64/boot/Image arch/arm64/boot/Image.gz \
	arch/arm64/boot/Image.gz-dtb; do copy_output "${OUT_DIR}/${rel}"; done
while IFS= read -r -d '' output; do copy_output "${output}"; done < <(
	find "${OUT_DIR}/arch/arm64/boot/dts" -type f \( -name '*.dtb' -o -name '*.dtbo' \) -print0
)
if [[ -d "${DTS_OUT_DIR}/arch/arm64/boot/dts" ]]; then
	while IFS= read -r -d '' output; do
		rel="production-dts/${output#${DTS_OUT_DIR}/}"
		mkdir -p "${ARTIFACT_DIR}/$(dirname "${rel}")"
		cp "${output}" "${ARTIFACT_DIR}/${rel}"
	done < <(find "${DTS_OUT_DIR}/arch/arm64/boot/dts" -type f \( -name '*.dtb' -o -name '*.dtbo' \) -print0)
fi
while IFS= read -r -d '' output; do copy_output "${output}"; done < <(find "${OUT_DIR}" -type f -name '*.ko' -print0)

(
	cd "${ARTIFACT_DIR}"
	find . -type f ! -name SHA256SUMS ! -name FILE-SIZES.txt -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
	find . -type f ! -name FILE-SIZES.txt -printf '%s  %P\n' | sort -k2 > FILE-SIZES.txt
)

echo "Build outputs collected under ${ARTIFACT_DIR}"
if [[ -n "${STOCK_BOOT_IMAGE:-}" ]]; then
	"${SCRIPT_DIR}/compare-stock-kernel.sh" "${STOCK_BOOT_IMAGE}" \
		"${ARTIFACT_DIR}/arch/arm64/boot/Image" \
		"${ARTIFACT_DIR}/stock-kernel-comparison.txt" || true
fi
