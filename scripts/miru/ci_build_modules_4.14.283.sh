#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_KERNEL_SHA=20794dacf7a37dbff8fc01835edfb48bb0a94a94
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
EXPECTED_RELEASE=4.14.283-miru-h40-diag19-full283-extconfix+
EXPECTED_SYMVERS_SHA=1f967afbc4399aec43078370e4064f26fd81edae11c6eb90740927d7ee4b3755

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
: "${PRIOR_SYMVERS:?PRIOR_SYMVERS is required}"

ANDROID_ROOT="${RUNNER_TEMP}/android-root"
KERNEL_DIR="${ANDROID_ROOT}/kernel/msm-4.14"
VENDOR_SOURCE="${RUNNER_TEMP}/oneplus-sm8150-vendor-source"
VENDOR_ROOT="${ANDROID_ROOT}/vendor"
OUT_DIR="${ANDROID_ROOT}/out/h40-kernel"
TOOLCHAIN_ROOT="${RUNNER_TEMP}/miru-toolchains"
CLANG_DIR="${TOOLCHAIN_ROOT}/clang-repo/clang-r377782c"
GCC64_DIR="${TOOLCHAIN_ROOT}/gcc64"
GCC32_DIR="${TOOLCHAIN_ROOT}/gcc32"
AOSP_BUILD_TOOLS="${TOOLCHAIN_ROOT}/build-tools/linux-x86"
REPORT_DIR="${GITHUB_WORKSPACE}/build-diagnostics"
FINAL_DIR="${GITHUB_WORKSPACE}/final-report"

mkdir -p "${REPORT_DIR}" "${FINAL_DIR}"
exec > >(tee -a "${REPORT_DIR}/modules-only-console.log") 2>&1
trap 'status=$?; echo "${status}" > "${REPORT_DIR}/modules-only-exit-code.txt"; exit "${status}"' EXIT

printf '%s  %s\n' "${EXPECTED_SYMVERS_SHA}" "${PRIOR_SYMVERS}" | sha256sum -c -
test "$(git rev-parse HEAD^{tree})" = "$(git rev-parse HEAD^{tree})"
test "$(git ls-remote origin refs/heads/miru-h40 | awk '{print $1}')" = "${PRODUCTION_SHA}"
git cat-file -e "${SOURCE_KERNEL_SHA}^{commit}"
test "$(git show "${SOURCE_KERNEL_SHA}:Makefile" | sed -n 's/^SUBLEVEL = //p' | head -n1)" = 283
test "$(git show "${SOURCE_KERNEL_SHA}:drivers/extcon/extcon.c" | git hash-object --stdin)" = 3643c82ca1532c62d5596cff8e05878a4d52543f
git show "${SOURCE_KERNEL_SHA}:drivers/soc/qcom/early_random.c" | grep -Fq '#include <linux/random.h>'

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file p7zip-full zip unzip

rm -rf "${ANDROID_ROOT}" "${VENDOR_SOURCE}" "${TOOLCHAIN_ROOT}"
mkdir -p "${ANDROID_ROOT}/kernel" "${ANDROID_ROOT}/out" "${TOOLCHAIN_ROOT}"
git worktree add --detach "${KERNEL_DIR}" "${SOURCE_KERNEL_SHA}"
test "$(git -C "${KERNEL_DIR}" rev-parse HEAD)" = "${SOURCE_KERNEL_SHA}"

git init -q "${VENDOR_SOURCE}"
git -C "${VENDOR_SOURCE}" remote add origin \
  https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git
git -C "${VENDOR_SOURCE}" fetch -q --depth=1 --filter=blob:none origin "${VENDOR_SHA}"
git -C "${VENDOR_SOURCE}" checkout -q --detach FETCH_HEAD
test "$(git -C "${VENDOR_SOURCE}" rev-parse HEAD)" = "${VENDOR_SHA}"
mkdir -p "${VENDOR_ROOT}"
rsync -a "${VENDOR_SOURCE}/vendor/" "${VENDOR_ROOT}/"

cd "${GITHUB_WORKSPACE}"
python3 scripts/miru/prepare_vendor_v6_linewise.py
python3 scripts/miru/apply_vendor_lts190_compat_v6.py \
  "${VENDOR_ROOT}" --report "${REPORT_DIR}/vendor-lts190-compat-report.txt"
python3 scripts/miru/fix_vendor_lts190_format_quotes.py \
  "${VENDOR_ROOT}" --report "${REPORT_DIR}/vendor-lts190-format-quote-report.txt"

test -L "${KERNEL_DIR}/block/oplus_foreground_io_opt"
test -f "${KERNEL_DIR}/block/oplus_foreground_io_opt/Kconfig"
test -d "${VENDOR_ROOT}/oplus"
test -d "${VENDOR_ROOT}/qcom/opensource/audio-kernel"
test -d "${VENDOR_ROOT}/qcom/opensource/wlan"

fetch_root() {
  local url="$1" commit="$2" dest="$3"
  git init -q "${dest}"
  git -C "${dest}" remote add origin "${url}"
  git -C "${dest}" fetch -q --depth=1 --filter=blob:none origin "${commit}"
  git -C "${dest}" checkout -q --detach FETCH_HEAD
}

fetch_sparse() {
  local url="$1" commit="$2" dest="$3" sparse_path="$4"
  git init -q "${dest}"
  git -C "${dest}" remote add origin "${url}"
  git -C "${dest}" sparse-checkout init --cone
  git -C "${dest}" sparse-checkout set "${sparse_path}"
  git -C "${dest}" fetch -q --depth=1 --filter=blob:none origin "${commit}"
  git -C "${dest}" checkout -q --detach FETCH_HEAD
}

fetch_sparse \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
  252aba16f513a857bc923172f67b0e55e23de35f \
  "${TOOLCHAIN_ROOT}/clang-repo" clang-r377782c
fetch_root \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 \
  606f80986096476912e04e5c2913685a8f2c3b65 "${GCC64_DIR}"
fetch_root \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 \
  b0c6a654327ca8796bed1e61dffcf523d04dceaa "${GCC32_DIR}"
fetch_sparse \
  https://android.googlesource.com/platform/prebuilts/build-tools \
  7322db1e1e4715fe217a27f721613e6be8438676 \
  "${TOOLCHAIN_ROOT}/build-tools" linux-x86

printf '%s  %s\n' \
  6618ecab73b79a70b79263d2f477f669e564d81ca802112d2e5f93c74c6b22ca \
  "${CLANG_DIR}/bin/clang" | sha256sum -c -
printf '%s  %s\n' \
  2a663de4ce3d702fe3f2a0de48cac366be676f850c2f5732d9cc2e4acb9335e2 \
  "${GCC64_DIR}/bin/aarch64-linux-android-ld" | sha256sum -c -
printf '%s  %s\n' \
  2f78058a8549bc5c099dbea16d9f3dc571e072b1ade906c3539e419787b502dd \
  "${GCC32_DIR}/bin/arm-linux-androideabi-as" | sha256sum -c -
printf '%s  %s\n' \
  5630a485d7c597d137fa462626213007e8865cf549677e1f727d131695ec830c \
  "${AOSP_BUILD_TOOLS}/bin/py2-cmd" | sha256sum -c -

export PATH="${KERNEL_DIR}/h40-repro/host-tools:${AOSP_BUILD_TOOLS}/bin:${CLANG_DIR}/bin:${GCC64_DIR}/bin:${GCC32_DIR}/bin:${PATH}"
export ARCH=arm64 SUBARCH=arm64
export KBUILD_BUILD_USER=miru
export KBUILD_BUILD_HOST=github-actions
export KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_TIMESTAMP="$(git -C "${KERNEL_DIR}" show -s --format=%cD HEAD)"
export SOURCE_DATE_EPOCH="$(git -C "${KERNEL_DIR}" show -s --format=%ct HEAD)"
export TARGET_BUILD_VARIANT=user

MAKE_COMMON=(
  "O=${OUT_DIR}" "ARCH=arm64" "TARGET_PRODUCT=msmnile"
  "BRAND_SHOW_FLAG=oneplus" "TARGET_BUILD_VARIANT=user"
  "CROSS_COMPILE=${GCC64_DIR}/bin/aarch64-linux-android-"
  "CROSS_COMPILE_ARM32=${GCC32_DIR}/bin/arm-linux-androideabi-"
  "REAL_CC=${CLANG_DIR}/bin/clang" "CLANG_TRIPLE=aarch64-linux-gnu-"
  "PYTHON=${AOSP_BUILD_TOOLS}/bin/py2-cmd"
  "HOSTCC=gcc" "HOSTCXX=g++" "LOCALVERSION=+"
)

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
cp "${KERNEL_DIR}/h40-repro/config/GM1911_11_H.40.config" "${OUT_DIR}/.config"
sed -i 's/\r$//' "${OUT_DIR}/.config"
make -C "${KERNEL_DIR}" "${MAKE_COMMON[@]}" olddefconfig
"${KERNEL_DIR}/scripts/config" --file "${OUT_DIR}/.config" \
  --set-str LOCALVERSION "-miru-h40-diag19-full283-extconfix"
"${KERNEL_DIR}/scripts/config" --file "${OUT_DIR}/.config" --disable MODULE_SIG_FORCE
make -C "${KERNEL_DIR}" "${MAKE_COMMON[@]}" olddefconfig
make -C "${KERNEL_DIR}" -j4 V=0 "${MAKE_COMMON[@]}" modules_prepare

cp "${PRIOR_SYMVERS}" "${OUT_DIR}/Module.symvers"
printf '%s  %s\n' "${EXPECTED_SYMVERS_SHA}" "${OUT_DIR}/Module.symvers" | sha256sum -c -

test "$(make -s -C "${KERNEL_DIR}" "${MAKE_COMMON[@]}" kernelrelease)" = "${EXPECTED_RELEASE}"
test -s "${OUT_DIR}/include/generated/utsrelease.h"
grep -Fq 'CONFIG_LOCALVERSION="-miru-h40-diag19-full283-extconfix"' "${OUT_DIR}/.config"
grep -Fq '# CONFIG_MODULE_SIG_FORCE is not set' "${OUT_DIR}/.config"
grep -Fq 'CONFIG_MODVERSIONS=y' "${OUT_DIR}/.config"

make -C "${KERNEL_DIR}" -j4 V=0 "${MAKE_COMMON[@]}" \
  drivers/media/platform/msm/dvb/adapter/mpq-adapter.ko \
  drivers/media/platform/msm/dvb/demux/mpq-dmx-hw-plugin.ko \
  drivers/platform/msm/msm_11ad/msm_11ad_proxy.ko \
  drivers/char/rdbg.ko \
  drivers/media/platform/msm/broadcast/tspp.ko \
  drivers/net/wireless/ath/wil6210/wil6210.ko

for rel in \
  drivers/media/platform/msm/dvb/adapter/mpq-adapter.ko \
  drivers/media/platform/msm/dvb/demux/mpq-dmx-hw-plugin.ko \
  drivers/platform/msm/msm_11ad/msm_11ad_proxy.ko \
  drivers/char/rdbg.ko \
  drivers/media/platform/msm/broadcast/tspp.ko \
  drivers/net/wireless/ath/wil6210/wil6210.ko; do
  test -s "${OUT_DIR}/${rel}"
done
printf '%s  %s\n' "${EXPECTED_SYMVERS_SHA}" "${OUT_DIR}/Module.symvers" | sha256sum -c -

"${KERNEL_DIR}/scripts/diffconfig" \
  "${KERNEL_DIR}/h40-repro/config/GM1911_11_H.40.config" "${OUT_DIR}/.config" \
  > "${REPORT_DIR}/config-diff.txt" || true
{
  echo result=SUCCESS
  echo build_mode=modules-only
  echo "kernel_source=${SOURCE_KERNEL_SHA}"
  echo "kernel_release=${EXPECTED_RELEASE}"
  echo "vendor_source=${VENDOR_SHA}"
  echo "module_symvers_sha256=${EXPECTED_SYMVERS_SHA}"
  echo selected_in_tree_modules=6
  echo kernel_image_rebuilt=no
  echo dtbs_rebuilt=no
} | tee "${REPORT_DIR}/module-preparation-summary.txt"

cd "${GITHUB_WORKSPACE}"
python3 scripts/miru/prepare_external_modules_toolchain.py
python3 scripts/miru/prepare_external_pinctrl_headers.py
python3 scripts/miru/prepare_wlan_response_link.py
python3 - <<'PY'
from pathlib import Path
path = Path('scripts/miru/build_external_modules_4.14.190.sh')
text = path.read_text()
old_release = '4.14.190-miru-h40-lts190-ci1+'
new_release = '4.14.283-miru-h40-diag19-full283-extconfix+'
if text.count(old_release) != 1:
    raise SystemExit(f'unexpected old release count: {text.count(old_release)}')
text = text.replace(old_release, new_release, 1)
text = text.replace('4.14.190', '4.14.283')
path.write_text(text)
PY
bash -n scripts/miru/build_external_modules_4.14.190.sh
bash scripts/miru/build_external_modules_4.14.190.sh

MODULE_DIR="${RUNNER_TEMP}/miru-external-modules/dropin"
test "$(find "${MODULE_DIR}" -maxdepth 1 -type f -name '*.ko' | wc -l)" = 32
grep -Fq 'errors=0' external-module-diagnostics/MODULE-ABI-REPORT.txt
test "$(grep -F ": ${EXPECTED_RELEASE} SMP preempt mod_unload modversions aarch64" \
  external-module-diagnostics/vermagic.txt | wc -l)" = 32

{
  echo result=SUCCESS
  echo build_mode=modules-only
  echo "kernel_source=${SOURCE_KERNEL_SHA}"
  echo "kernel_release=${EXPECTED_RELEASE}"
  echo "module_source=${VENDOR_SHA}"
  echo "module_symvers_sha256=${EXPECTED_SYMVERS_SHA}"
  echo module_count=32
  echo module_abi_errors=0
  echo kernel_image_rebuilt=no
  echo dtbs_rebuilt=no
  echo "run_id=${GITHUB_RUN_ID:-local}"
} | tee "${FINAL_DIR}/VALIDATION-SUMMARY.txt"
cp "${REPORT_DIR}/module-preparation-summary.txt" "${FINAL_DIR}/"
cp "${REPORT_DIR}/config-diff.txt" "${FINAL_DIR}/CONFIG-DELTA.txt"
cp external-module-diagnostics/MODULE-ABI-REPORT.txt "${FINAL_DIR}/"
cp external-module-diagnostics/BUILD-MANIFEST.txt "${FINAL_DIR}/MODULE-BUILD-MANIFEST.txt"
cp external-module-diagnostics/PACKAGE-SUMMARY.txt "${FINAL_DIR}/MODULE-PACKAGE-SUMMARY.txt"
cp external-module-diagnostics/vermagic.txt "${FINAL_DIR}/"
find "${MODULE_DIR}" -maxdepth 1 -type f -name '*.ko' -print0 | sort -z | xargs -0 sha256sum \
  > "${FINAL_DIR}/MODULE-FILES-SHA256.txt"
sha256sum \
  "${RUNNER_TEMP}/android-root/out/miru-v3-modules-dropin-4.14.283.7z" \
  "${RUNNER_TEMP}/android-root/out/miru-v3-modules-dropin-4.14.283-audit.zip" \
  > "${FINAL_DIR}/MODULE-PACKAGES-SHA256.txt"
