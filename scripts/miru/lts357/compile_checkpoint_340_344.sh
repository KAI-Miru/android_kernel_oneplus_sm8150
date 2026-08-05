#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION=eb9451c0a1639e1aa49ee094681f98df0545f797
STAGE340=e714dcc91781cc51118b3761d5be1b74645cd9af
STAGE344=4ca04340dfd5abd1b7e4d9b72c3f9223331cd118
OPENELA340=9b7ef2749ffa187d86acd0033327338c0fc299bf
OPENELA344=7a22fc46cc7a72d72b6dfdcbbc46e18c9f2caab0
MODULES_SHA=3216c08bb3f97f865eb055296ea8034e1744caef
STALE_MODULES_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
REPORT_ROOT="${GITHUB_WORKSPACE}/integration-evidence/compile-checkpoints-340-344"
TOOLCHAIN_ROOT="${RUNNER_TEMP}/miru-toolchains"
VENDOR_SOURCE="${RUNNER_TEMP}/miru-vendor-source"

mkdir -p "${REPORT_ROOT}"
exec > >(tee -a "${REPORT_ROOT}/console.log") 2>&1
trap 'rc=$?; echo "exit_code=${rc}" > "${REPORT_ROOT}/EXIT.txt"; exit "${rc}"' EXIT

# Immutable live refs and authentic merge topology.
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40 | awk 'NR==1{print $1}')" = "${PRODUCTION}"
test "$(git ls-remote https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git refs/heads/oneplus/sm8150_s_12.1_op7pro | awk 'NR==1{print $1}')" = "${MODULES_SHA}"
test "${MODULES_SHA}" != "${STALE_MODULES_SHA}"
git merge-base --is-ancestor "${PRODUCTION}" "${STAGE340}"
git merge-base --is-ancestor "${STAGE340}" "${STAGE344}"
test "$(git rev-list --parents -n1 "${STAGE340}")" = "${STAGE340} $(git rev-list --parents -n1 "${STAGE340}" | awk '{print $2}') ${OPENELA340}"
test "$(git rev-list --parents -n1 "${STAGE344}")" = "${STAGE344} $(git rev-list --parents -n1 "${STAGE344}" | awk '{print $2}') ${OPENELA344}"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file

rm -rf "${VENDOR_SOURCE}" "${TOOLCHAIN_ROOT}"
git init -q "${VENDOR_SOURCE}"
git -C "${VENDOR_SOURCE}" remote add origin \
  https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git
git -C "${VENDOR_SOURCE}" fetch -q --depth=1 --filter=blob:none origin "${MODULES_SHA}"
git -C "${VENDOR_SOURCE}" checkout -q --detach FETCH_HEAD
test "$(git -C "${VENDOR_SOURCE}" rev-parse HEAD)" = "${MODULES_SHA}"
test -d "${VENDOR_SOURCE}/vendor"
git -C "${VENDOR_SOURCE}" merge-base --is-ancestor "${STALE_MODULES_SHA}" HEAD && {
  echo 'stale modules commit is unexpectedly in pinned modules ancestry' >&2
  exit 1
} || true

test -R "${VENDOR_SOURCE}/vendor/oplus/kernel/audio/codecs/audio_extend/audio_extend.c" || true
grep -RqsF 'EXPORT_SYMBOL_GPL(extend_codec_i2s_be_dailinks);' .

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

mkdir -p "${TOOLCHAIN_ROOT}"
fetch_sparse \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
  252aba16f513a857bc923172f67b0e55e23de35f \
  "${TOOLCHAIN_ROOT}/clang-repo" clang-r377782c
fetch_root \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 \
  606f80986096476912e04e5c2913685a8f2c3b65 \
  "${TOOLCHAIN_ROOT}/gcc64"
fetch_root \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 \
  b0c6a654327ca8796bed1e61dffcf523d04dceaa \
  "${TOOLCHAIN_ROOT}/gcc32"
fetch_sparse \
  https://android.googlesource.com/platform/prebuilts/build-tools \
  7322db1e1e4715fe217a27f721613e6be8438676 \
  "${TOOLCHAIN_ROOT}/build-tools" linux-x86

CLANG_DIR="${TOOLCHAIN_ROOT}/clang-repo/clang-r377782c"
GCC64_DIR="${TOOLCHAIN_ROOT}/gcc64"
GCC32_DIR="${TOOLCHAIN_ROOT}/gcc32"
AOSP_BUILD_TOOLS="${TOOLCHAIN_ROOT}/build-tools/linux-x86"
printf '%s  %s\n' \
  6618ecab73b79a70b79263d2f477f669e564d81ca802112d2e5f93c74c6b22ca \
  "${CLANG_DIR}/bin/clang" | sha256sum -c -
printf '%s  %s\n' \
  2a663de4ce3d702fe3f2a0de48cac366be676f850c2f5732d9cc2e4acb9335e2 \
  "${GCC64_DIR}/bin/aarch64-linux-android-ld" | sha256sum -c -
printf '%s  %s\n' \
  9565b7fc362bdf87032d44eea1087f25dcdd3a6655b39caa6f934640791f15d8 \
  "${GCC64_DIR}/bin/aarch64-linux-android-as" | sha256sum -c -
printf '%s  %s\n' \
  2f78058a8549bc5c099dbea16d9f3dc571e072b1ade906c3539e419787b502dd \
  "${GCC32_DIR}/bin/arm-linux-androideabi-as" | sha256sum -c -
printf '%s  %s\n' \
  5630a485d7c597d137fa462626213007e8865cf549677e1f727d131695ec830c \
  "${AOSP_BUILD_TOOLS}/bin/py2-cmd" | sha256sum -c -

compile_stage() {
  local label="$1" sha="$2" sublevel="$3" localversion="$4"
  shift 4
  local android_root="${RUNNER_TEMP}/android-${label}"
  local kernel_dir="${android_root}/kernel/msm-4.14"
  local out_dir="${android_root}/out/h40-kernel"
  local report="${REPORT_ROOT}/${label}"
  local target

  rm -rf "${android_root}"
  mkdir -p "${android_root}/kernel" "${android_root}/vendor" "${out_dir}" "${report}"
  git worktree add --detach "${kernel_dir}" "${sha}"
  rsync -a "${VENDOR_SOURCE}/vendor/" "${android_root}/vendor/"

  test "$(git -C "${kernel_dir}" rev-parse HEAD)" = "${sha}"
  test "$(sed -n 's/^SUBLEVEL = //p' "${kernel_dir}/Makefile" | head -n1)" = "${sublevel}"
  test -L "${kernel_dir}/block/oplus_foreground_io_opt"
  test -f "${kernel_dir}/block/oplus_foreground_io_opt/Kconfig"

  export H40_REAL_CPIO="$(command -v cpio)"
  export H40_REAL_TAR="$(command -v tar)"
  export H40_AOSP_TOYBOX="${AOSP_BUILD_TOOLS}/bin/toybox"
  export H40_AOSP_BC="${AOSP_BUILD_TOOLS}/bin/gavinhoward-bc"
  export PATH="${kernel_dir}/h40-repro/host-tools:${AOSP_BUILD_TOOLS}/bin:${CLANG_DIR}/bin:${GCC64_DIR}/bin:${GCC32_DIR}/bin:${PATH}"
  export ARCH=arm64 SUBARCH=arm64
  export KBUILD_BUILD_USER=miru KBUILD_BUILD_HOST=github-actions KBUILD_BUILD_VERSION=1
  export KBUILD_BUILD_TIMESTAMP="$(git -C "${kernel_dir}" show -s --format=%cD HEAD)"
  export SOURCE_DATE_EPOCH="$(git -C "${kernel_dir}" show -s --format=%ct HEAD)"

  cp "${kernel_dir}/h40-repro/config/GM1911_11_H.40.config" "${out_dir}/.config"
  sed -i 's/\r$//' "${out_dir}/.config"

  make_args=(
    "O=${out_dir}" ARCH=arm64 TARGET_PRODUCT=msmnile
    BRAND_SHOW_FLAG=oneplus TARGET_BUILD_VARIANT=user
    "CROSS_COMPILE=${GCC64_DIR}/bin/aarch64-linux-android-"
    "CROSS_COMPILE_ARM32=${GCC32_DIR}/bin/arm-linux-androideabi-"
    "REAL_CC=${CLANG_DIR}/bin/clang" CLANG_TRIPLE=aarch64-linux-gnu-
    "PYTHON=${AOSP_BUILD_TOOLS}/bin/py2-cmd" HOSTCC=gcc HOSTCXX=g++ LOCALVERSION=+
  )

  make -C "${kernel_dir}" "${make_args[@]}" olddefconfig
  "${kernel_dir}/scripts/config" --file "${out_dir}/.config" \
    --set-str LOCALVERSION "-${localversion}" --disable MODULE_SIG_FORCE
  make -C "${kernel_dir}" "${make_args[@]}" olddefconfig prepare modules_prepare

  for target in "$@"; do
    make -C "${kernel_dir}" -j4 "${make_args[@]}" "${target}"
    test -s "${out_dir}/${target}"
  done

  release="$(make -s -C "${kernel_dir}" "${make_args[@]}" kernelrelease)"
  test "${release}" = "4.14.${sublevel}-${localversion}+"
  {
    echo result=PASS
    echo "label=${label}"
    echo "source_sha=${sha}"
    echo "kernel_release=${release}"
    echo "modules_sha=${MODULES_SHA}"
    echo "target_count=$#"
    printf 'target=%s\n' "$@"
    echo production_write=NONE
  } | tee "${report}/SUMMARY.txt"
  sha256sum "${out_dir}/.config" "${out_dir}/include/config/kernel.release" \
    > "${report}/SHA256SUMS.txt"
  git worktree remove --force "${kernel_dir}"
}

compile_stage stage340 "${STAGE340}" 340 miru-h40-lts340-stage1 \
  drivers/android/binder_alloc.o \
  fs/aio.o fs/f2fs/namei.o mm/memory-failure.o mm/swap.o \
  drivers/usb/dwc3/gadget.o net/qrtr/qrtr.o

compile_stage stage344 "${STAGE344}" 344 miru-h40-lts344-stage2 \
  drivers/android/binder.o fs/select.o net/ipv4/sysctl_net_ipv4.o \
  net/ipv4/tcp_ipv4.o net/netfilter/xt_owner.o sound/usb/stream.o \
  drivers/usb/dwc3/gadget.o net/qrtr/qrtr.o

{
  echo result=PASS
  echo stage340=${STAGE340}
  echo stage344=${STAGE344}
  echo modules_sha=${MODULES_SHA}
  echo clang_commit=252aba16f513a857bc923172f67b0e55e23de35f
  echo production_write=NONE
} | tee "${REPORT_ROOT}/SUMMARY.txt"
