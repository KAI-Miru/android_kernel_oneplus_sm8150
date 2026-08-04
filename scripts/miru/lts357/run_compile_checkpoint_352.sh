#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION=eb9451c0a1639e1aa49ee094681f98df0545f797
OPENELA352=6da009d8de389742d55219ebed50378f53937a5b
MODULES_SHA=3216c08bb3f97f865eb055296ea8034e1744caef
STALE_MODULES_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
CLANG_COMMIT=252aba16f513a857bc923172f67b0e55e23de35f
DWC3_REPAIR=a3192f52549713424a5d8352e4be381ca84434a0
STAGE352_MERGE="${STAGE352_MERGE:?STAGE352_MERGE is required}"
EXPECTED_REMOTE_HEAD="${EXPECTED_REMOTE_HEAD:?EXPECTED_REMOTE_HEAD is required}"
REPORT_ROOT="${GITHUB_WORKSPACE}/integration-evidence/compile-checkpoint-352"
TOOLCHAIN_ROOT="${RUNNER_TEMP}/miru-toolchains-352"
VENDOR_SOURCE="${RUNNER_TEMP}/miru-vendor-source-352"
ANDROID_ROOT="${RUNNER_TEMP}/android-stage352"
KERNEL_DIR="${ANDROID_ROOT}/kernel/msm-4.14"
OUT_DIR="${ANDROID_ROOT}/out/h40-kernel"
ARM_OUT="${ANDROID_ROOT}/out/arm-uaccess"

mkdir -p "${REPORT_ROOT}"
exec > >(tee -a "${REPORT_ROOT}/console.log") 2>&1
trap 'rc=$?; printf "exit_code=%s\nproduction_write=NONE\n" "${rc}" > "${REPORT_ROOT}/EXIT.txt"; exit "${rc}"' EXIT

live_production="$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40 | awk 'NR==1{print $1}')"
live_integration="$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40-lts357-integration | awk 'NR==1{print $1}')"
live_modules="$(git ls-remote https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git refs/heads/oneplus/sm8150_s_12.1_op7pro | awk 'NR==1{print $1}')"
test "${live_production}" = "${PRODUCTION}"
test "${live_integration}" = "${EXPECTED_REMOTE_HEAD}"
test "${live_modules}" = "${MODULES_SHA}"
test "${live_modules}" != "${STALE_MODULES_SHA}"
test "$(git rev-parse HEAD)" = "${STAGE352_MERGE}"

git merge-base --is-ancestor "${PRODUCTION}" "${STAGE352_MERGE}"
parents="$(git rev-list --parents -n1 "${STAGE352_MERGE}")"
first_parent="$(printf '%s\n' "${parents}" | awk '{print $2}')"
second_parent="$(printf '%s\n' "${parents}" | awk '{print $3}')"
parent_count="$(printf '%s\n' "${parents}" | awk '{print NF-1}')"
test "${parent_count}" = 2
test "${first_parent}" = "${EXPECTED_REMOTE_HEAD}"
test "${second_parent}" = "${OPENELA352}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 352
test "$(sed -n 's/^EXTRAVERSION = //p' Makefile | head -n1)" = -openela
git merge-base --is-ancestor "${DWC3_REPAIR}" "${STAGE352_MERGE}"

if git grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- ':!Documentation/miru/lts-4.14.357-conflicts.md'; then
  echo 'conflict markers remain' >&2
  exit 1
fi
if find . -type f \( -name '*.orig' -o -name '*.rej' \) -print -quit | grep -q .; then
  echo 'temporary merge files remain' >&2
  exit 1
fi
test -z "$(git ls-files -u)"

# Exact stage-352 semantic resolutions.
! grep -q '__GUP_CLOBBER_' arch/arm/include/asm/uaccess.h
test "$(grep -Fc '__asmbl_clobber("ip"), "lr", "cc"' arch/arm/include/asm/uaccess.h)" = 2
test "$(grep -Fc '__asmbl("", "ip", "__get_user_' arch/arm/include/asm/uaccess.h)" -ge 2
grep -Fq 'f2fs_err(sbi, "invalid journal entries nats %u sits %u\n",' fs/f2fs/segment.c
grep -Fq 'nats_in_cursum(nat_j), sits_in_cursum(sit_j)' fs/f2fs/segment.c
grep -Fq 'f2fs_err(sbi, "Failed to initialize F2FS segment manager (%d)",' fs/f2fs/super.c
grep -Fq 'f2fs_err(sbi, "Failed to initialize F2FS node manager (%d)",' fs/f2fs/super.c

# Qualcomm DWC3 direct-dispatch repair must remain exact.
grep -Fq 'dwc3_interrupt(dwc->irq_gadget, dwc->ev_buf);' drivers/usb/dwc3/gadget.c
if grep -A15 -F 'dwc = evt->dwc;' drivers/usb/dwc3/gadget.c | grep -Fq 'pm_runtime_suspended(dwc->dev)'; then
  echo 'stale suspended-event DWC3 deferral returned' >&2
  exit 1
fi
if grep -A8 -F 'void dwc3_gadget_process_pending_events' drivers/usb/dwc3/gadget.c | grep -Fq 'dwc3_check_event_buf'; then
  echo 'stale pending-event DWC3 redispatch returned' >&2
  exit 1
fi

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file

rm -rf "${VENDOR_SOURCE}" "${TOOLCHAIN_ROOT}" "${ANDROID_ROOT}"
git init -q "${VENDOR_SOURCE}"
git -C "${VENDOR_SOURCE}" remote add origin \
  https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git
git -C "${VENDOR_SOURCE}" fetch -q --depth=1 --filter=blob:none origin "${MODULES_SHA}"
git -C "${VENDOR_SOURCE}" checkout -q --detach FETCH_HEAD
test "$(git -C "${VENDOR_SOURCE}" rev-parse HEAD)" = "${MODULES_SHA}"
test -d "${VENDOR_SOURCE}/vendor"
grep -RqsF 'EXPORT_SYMBOL_GPL(extend_codec_i2s_be_dailinks);' "${VENDOR_SOURCE}/vendor"

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
  "${CLANG_COMMIT}" "${TOOLCHAIN_ROOT}/clang-repo" clang-r377782c
fetch_root \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 \
  606f80986096476912e04e5c2913685a8f2c3b65 "${TOOLCHAIN_ROOT}/gcc64"
fetch_root \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 \
  b0c6a654327ca8796bed1e61dffcf523d04dceaa "${TOOLCHAIN_ROOT}/gcc32"
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

mkdir -p "${ANDROID_ROOT}/kernel" "${ANDROID_ROOT}/vendor" "${OUT_DIR}" "${ARM_OUT}"
git worktree add --detach "${KERNEL_DIR}" "${STAGE352_MERGE}"
rsync -a "${VENDOR_SOURCE}/vendor/" "${ANDROID_ROOT}/vendor/"
test "$(git -C "${KERNEL_DIR}" rev-parse HEAD)" = "${STAGE352_MERGE}"

export H40_REAL_CPIO="$(command -v cpio)"
export H40_REAL_TAR="$(command -v tar)"
export H40_AOSP_TOYBOX="${AOSP_BUILD_TOOLS}/bin/toybox"
export H40_AOSP_BC="${AOSP_BUILD_TOOLS}/bin/gavinhoward-bc"
export PATH="${KERNEL_DIR}/h40-repro/host-tools:${AOSP_BUILD_TOOLS}/bin:${CLANG_DIR}/bin:${GCC64_DIR}/bin:${GCC32_DIR}/bin:${PATH}"
export KBUILD_BUILD_USER=miru KBUILD_BUILD_HOST=github-actions KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_TIMESTAMP="$(git -C "${KERNEL_DIR}" show -s --format=%cD HEAD)"
export SOURCE_DATE_EPOCH="$(git -C "${KERNEL_DIR}" show -s --format=%ct HEAD)"

cp "${KERNEL_DIR}/h40-repro/config/GM1911_11_H.40.config" "${OUT_DIR}/.config"
sed -i 's/\r$//' "${OUT_DIR}/.config"
make_args=(
  "O=${OUT_DIR}" ARCH=arm64 SUBARCH=arm64 TARGET_PRODUCT=msmnile
  BRAND_SHOW_FLAG=oneplus TARGET_BUILD_VARIANT=user
  "CROSS_COMPILE=${GCC64_DIR}/bin/aarch64-linux-android-"
  "CROSS_COMPILE_ARM32=${GCC32_DIR}/bin/arm-linux-androideabi-"
  "REAL_CC=${CLANG_DIR}/bin/clang" CLANG_TRIPLE=aarch64-linux-gnu-
  "PYTHON=${AOSP_BUILD_TOOLS}/bin/py2-cmd"
  "CC=${AOSP_BUILD_TOOLS}/bin/py2-cmd ${KERNEL_DIR}/scripts/gcc-wrapper.py ${CLANG_DIR}/bin/clang"
  HOSTCC=gcc HOSTCXX=g++ LOCALVERSION=+ V=1
)

make -C "${KERNEL_DIR}" "${make_args[@]}" olddefconfig
"${KERNEL_DIR}/scripts/config" --file "${OUT_DIR}/.config" \
  --set-str LOCALVERSION -miru-h40-lts352-stage4 --disable MODULE_SIG_FORCE
make -C "${KERNEL_DIR}" "${make_args[@]}" olddefconfig prepare modules_prepare

built_targets=(
  drivers/usb/dwc3/core.o
  drivers/usb/dwc3/gadget.o
  drivers/media/pci/cx18/cx18-streams.o
  fs/f2fs/segment.o
  fs/f2fs/super.o
  fs/f2fs/namei.o
  drivers/android/binder.o
  fs/aio.o
  mm/page_alloc.o
  mm/memory.o
  net/core/filter.o
  net/qrtr/qrtr.o
)
for target in "${built_targets[@]}"; do
  echo "checkpoint_target_start=${target}"
  make -C "${KERNEL_DIR}" -j4 "${make_args[@]}" "${target}"
  test -s "${OUT_DIR}/${target}"
  echo "checkpoint_target_pass=${target}"
done

# Controlled ARM32 compatibility probe; this does not alter the phone defconfig.
arm_make_args=(
  "O=${ARM_OUT}" ARCH=arm SUBARCH=arm
  "CROSS_COMPILE=${GCC32_DIR}/bin/arm-linux-androideabi-"
  "REAL_CC=${CLANG_DIR}/bin/clang" CLANG_TRIPLE=arm-linux-gnueabi-
  "PYTHON=${AOSP_BUILD_TOOLS}/bin/py2-cmd"
  "CC=${AOSP_BUILD_TOOLS}/bin/py2-cmd ${KERNEL_DIR}/scripts/gcc-wrapper.py ${CLANG_DIR}/bin/clang"
  HOSTCC=gcc HOSTCXX=g++ V=1
)
make -C "${KERNEL_DIR}" "${arm_make_args[@]}" multi_v7_defconfig
make -C "${KERNEL_DIR}" "${arm_make_args[@]}" prepare modules_prepare
make -C "${KERNEL_DIR}" -j4 "${arm_make_args[@]}" arch/arm/lib/uaccess_with_memcpy.o
test -s "${ARM_OUT}/arch/arm/lib/uaccess_with_memcpy.o"
arm_probe=arch/arm/lib/uaccess_with_memcpy.o

release="$(cat "${OUT_DIR}/include/config/kernel.release")"
release_make="$(make -s -C "${KERNEL_DIR}" "${make_args[@]}" kernelrelease)"
expected_release=4.14.352-openela-miru-h40-lts352-stage4+
test "${release}" = "${expected_release}"
test "${release_make}" = "${expected_release}"

# Re-check remote boundaries immediately before reporting success.
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40 | awk 'NR==1{print $1}')" = "${PRODUCTION}"
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40-lts357-integration | awk 'NR==1{print $1}')" = "${EXPECTED_REMOTE_HEAD}"
test "$(git ls-remote https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git refs/heads/oneplus/sm8150_s_12.1_op7pro | awk 'NR==1{print $1}')" = "${MODULES_SHA}"

{
  echo result=PASS
  echo "integration_source_sha=${STAGE352_MERGE}"
  echo "stage352_merge=${STAGE352_MERGE}"
  echo "openela_second_parent=${OPENELA352}"
  echo "kernel_release=${release}"
  echo "compiler_commit=${CLANG_COMMIT}"
  echo "compiler_identity=clang-r377782c"
  echo "modules_sha=${MODULES_SHA}"
  echo "arm_probe=${arm_probe}"
  printf 'built_target=%s\n' "${built_targets[@]}"
  echo exit_code=0
  echo production_write=NONE
} | tee "${REPORT_ROOT}/SUMMARY.txt"
sha256sum \
  "${OUT_DIR}/.config" \
  "${OUT_DIR}/include/config/kernel.release" \
  "${ARM_OUT}/arch/arm/lib/uaccess_with_memcpy.o" \
  > "${REPORT_ROOT}/SHA256SUMS.txt"

git worktree remove --force "${KERNEL_DIR}"
