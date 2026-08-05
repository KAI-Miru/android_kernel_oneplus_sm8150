#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION=eb9451c0a1639e1aa49ee094681f98df0545f797
OPENELA352=6da009d8de389742d55219ebed50378f53937a5b
OPENELA356=a76b6a6556353484f6f29572989cd37b6cff90cc
STAGE352_MERGE=f5ebecc06992d60f50c21ebf9e9dc0538fa7b1c3
MODULES_SHA=3216c08bb3f97f865eb055296ea8034e1744caef
STALE_MODULES_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
CLANG_COMMIT=252aba16f513a857bc923172f67b0e55e23de35f
DWC3_REPAIR=a3192f52549713424a5d8352e4be381ca84434a0
STAGE356_MERGE="${STAGE356_MERGE:?STAGE356_MERGE is required}"
EXPECTED_REMOTE_HEAD="${EXPECTED_REMOTE_HEAD:?EXPECTED_REMOTE_HEAD is required}"
REPORT_ROOT="${GITHUB_WORKSPACE}/integration-evidence/compile-checkpoint-356"
TOOLCHAIN_ROOT="${RUNNER_TEMP}/miru-toolchains-356"
VENDOR_SOURCE="${RUNNER_TEMP}/miru-vendor-source-356"
ANDROID_ROOT="${RUNNER_TEMP}/android-stage356"
KERNEL_DIR="${ANDROID_ROOT}/kernel/msm-4.14"
OUT_DIR="${ANDROID_ROOT}/out/h40-kernel"
ARM_OUT="${ANDROID_ROOT}/out/arm-uaccess"

mkdir -p "${REPORT_ROOT}"
exec > >(tee -a "${REPORT_ROOT}/console.log") 2>&1
checkpoint_step() {
  printf '%s\n' "$1" | tee "${REPORT_ROOT}/LAST_STEP.txt"
}
trap 'rc=$?; printf "exit_code=%s\nproduction_write=NONE\n" "${rc}" > "${REPORT_ROOT}/EXIT.txt"; exit "${rc}"' EXIT

checkpoint_step verify-boundaries-and-topology
live_production="$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40 | awk 'NR==1{print $1}')"
live_integration="$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40-lts357-integration | awk 'NR==1{print $1}')"
live_modules="$(git ls-remote https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git refs/heads/oneplus/sm8150_s_12.1_op7pro | awk 'NR==1{print $1}')"
test "${live_production}" = "${PRODUCTION}"
test "${live_integration}" = "${EXPECTED_REMOTE_HEAD}"
test "${live_modules}" = "${MODULES_SHA}"
test "${live_modules}" != "${STALE_MODULES_SHA}"
test "$(git rev-parse HEAD)" = "${STAGE356_MERGE}"
git merge-base --is-ancestor "${PRODUCTION}" "${STAGE356_MERGE}"
git merge-base --is-ancestor "${STAGE352_MERGE}" "${STAGE356_MERGE}"
git merge-base --is-ancestor "${OPENELA352}" "${OPENELA356}"
parents="$(git rev-list --parents -n1 "${STAGE356_MERGE}")"
first_parent="$(printf '%s\n' "${parents}" | awk '{print $2}')"
second_parent="$(printf '%s\n' "${parents}" | awk '{print $3}')"
parent_count="$(printf '%s\n' "${parents}" | awk '{print NF-1}')"
test "${parent_count}" = 2
test "${first_parent}" = "${EXPECTED_REMOTE_HEAD}"
test "${second_parent}" = "${OPENELA356}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 356
test "$(sed -n 's/^EXTRAVERSION = //p' Makefile | head -n1)" = -openela
git merge-base --is-ancestor "${DWC3_REPAIR}" "${STAGE356_MERGE}"

checkpoint_step scan-merge-hygiene
conflict_paths=(
  arch/arm64/include/asm/cputype.h
  drivers/mmc/core/mmc_test.c
  drivers/net/usb/usbnet.c
  drivers/usb/dwc3/core.c
  fs/f2fs/inode.c
  fs/f2fs/namei.c
  include/linux/clk.h
  net/qrtr/qrtr.c
  security/selinux/selinuxfs.c
)
git diff --check "${first_parent}" "${STAGE356_MERGE}" -- \
  "${conflict_paths[@]}" Documentation/miru/lts-4.14.357-conflicts.md \
  > "${REPORT_ROOT}/MERGE_DIFF_CHECK.txt"
: > "${REPORT_ROOT}/CONFLICT_MARKER_SCAN.txt"
for path in "${conflict_paths[@]}"; do
  grep -nE '^(<<<<<<<|\|\|\|\|\|\|\||=======|>>>>>>>)' "${path}" >> "${REPORT_ROOT}/CONFLICT_MARKER_SCAN.txt" || true
done
test ! -s "${REPORT_ROOT}/CONFLICT_MARKER_SCAN.txt"
find . -path './.git' -prune -o -type f \
  \( -name '*.orig' -o -name '*.rej' -o -name '*.pyc' \) -print \
  > "${REPORT_ROOT}/TEMPORARY_FILES.txt"
test ! -s "${REPORT_ROOT}/TEMPORARY_FILES.txt"
test -z "$(git ls-files -u)"

checkpoint_step verify-cumulative-stage352-semantics
! grep -q '__GUP_CLOBBER_' arch/arm/include/asm/uaccess.h
test "$(grep -Fc '__asmbl_clobber("ip"), "lr", "cc"' arch/arm/include/asm/uaccess.h)" = 2
grep -Fq 'f2fs_err(sbi, "invalid journal entries nats %u sits %u\n",' fs/f2fs/segment.c
grep -Fq 'f2fs_err(sbi, "Failed to initialize F2FS segment manager (%d)",' fs/f2fs/super.c
grep -Fq 'f2fs_err(sbi, "Failed to initialize F2FS node manager (%d)",' fs/f2fs/super.c
grep -Fq 'dwc3_interrupt(dwc->irq_gadget, dwc->ev_buf);' drivers/usb/dwc3/gadget.c
if grep -A15 -F 'dwc = evt->dwc;' drivers/usb/dwc3/gadget.c | grep -Fq 'pm_runtime_suspended(dwc->dev)'; then
  echo 'stale suspended-event DWC3 deferral returned' >&2
  exit 1
fi
if grep -A8 -F 'void dwc3_gadget_process_pending_events' drivers/usb/dwc3/gadget.c | grep -Fq 'dwc3_check_event_buf'; then
  echo 'stale pending-event DWC3 redispatch returned' >&2
  exit 1
fi

checkpoint_step verify-stage356-semantics
for id in ARM_CPU_PART_NEOVERSE_N3 MIDR_NEOVERSE_N3 ARM_CPU_PART_KRYO3S MIDR_KRYO3S ARM_CPU_PART_KRYO4G MIDR_KRYO4G; do
  grep -Fq "${id}" arch/arm64/include/asm/cputype.h
done
grep -Fq 'if (!test->highmem) {' drivers/mmc/core/mmc_test.c
grep -Fq 'count = -ENOMEM;' drivers/mmc/core/mmc_test.c
grep -Fq 'goto free_test_buffer;' drivers/mmc/core/mmc_test.c
grep -Fq 'free_test_buffer:' drivers/mmc/core/mmc_test.c
grep -Fq 'eth_hw_addr_random(net);' drivers/net/usb/usbnet.c
grep -Fq 'ipc_log_context_create' drivers/net/usb/usbnet.c
! grep -Fq 'eth_random_addr(node_id)' drivers/net/usb/usbnet.c
! grep -Fq 'static u8\tnode_id' drivers/net/usb/usbnet.c
! grep -Fq 'memcpy (net->dev_addr, node_id' drivers/net/usb/usbnet.c
grep -Fq 'void dwc3_en_sleep_mode' drivers/usb/dwc3/core.c
grep -Fq 'void dwc3_dis_sleep_mode' drivers/usb/dwc3/core.c
grep -Fq 'snps,dis-split-quirk' drivers/usb/dwc3/core.c
grep -Fq 'DWC3_GUCTL3_SPLITDISABLE' drivers/usb/dwc3/core.c
grep -Fq 'f2fs_readonly(F2FS_I_SB(inode)->sb)' fs/f2fs/inode.c
python3 - <<'PY'
from pathlib import Path
inode = Path('fs/f2fs/inode.c').read_text()
new = inode.index('if (is_inode_flag_set(inode, FI_NEW_INODE))')
ro = inode.index('if (f2fs_readonly(F2FS_I_SB(inode)->sb))', new)
dirty = inode.index('if (!is_inode_flag_set(inode, FI_DIRTY_INODE))', ro)
assert new < ro < dirty
namei = Path('fs/f2fs/namei.c').read_text()
new = namei.index('set_inode_flag(inode, FI_NEW_INODE);')
encrypt = namei.index('f2fs_may_encrypt(dir, inode)', new)
assert new < encrypt
PY
grep -Fq 'clk_get_optional' include/linux/clk.h
grep -Fq '#if defined(CONFIG_OF)' include/linux/clk.h
grep -Fq 'pskb_copy(skb, GFP_KERNEL)' net/qrtr/qrtr.c
grep -Fq 'list_for_each_entry(node, &qrtr_all_epts, item)' net/qrtr/qrtr.c
grep -Fq 'down_read(&qrtr_node_lock)' net/qrtr/qrtr.c
python3 - <<'PY'
from pathlib import Path
text = Path('security/selinux/selinuxfs.c').read_text()
start = text.index('static ssize_t sel_write_load')
for needle in ('/* no partial writes */', 'if (!count)', 'count > 64 * 1024 * 1024'):
    assert text.index(needle, start) < text.index('mutex_lock(&fsi->mutex)', start)
PY
grep -Fq '## Stage 5 — 4.14.352 to 4.14.356' Documentation/miru/lts-4.14.357-conflicts.md

checkpoint_step install-host-dependencies
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file

checkpoint_step fetch-exact-modules-and-toolchains
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
printf '%s  %s\n' 6618ecab73b79a70b79263d2f477f669e564d81ca802112d2e5f93c74c6b22ca "${CLANG_DIR}/bin/clang" | sha256sum -c -
printf '%s  %s\n' 2a663de4ce3d702fe3f2a0de48cac366be676f850c2f5732d9cc2e4acb9335e2 "${GCC64_DIR}/bin/aarch64-linux-android-ld" | sha256sum -c -
printf '%s  %s\n' 9565b7fc362bdf87032d44eea1087f25dcdd3a6655b39caa6f934640791f15d8 "${GCC64_DIR}/bin/aarch64-linux-android-as" | sha256sum -c -
printf '%s  %s\n' 2f78058a8549bc5c099dbea16d9f3dc571e072b1ade906c3539e419787b502dd "${GCC32_DIR}/bin/arm-linux-androideabi-as" | sha256sum -c -
printf '%s  %s\n' 5630a485d7c597d137fa462626213007e8865cf549677e1f727d131695ec830c "${AOSP_BUILD_TOOLS}/bin/py2-cmd" | sha256sum -c -

checkpoint_step prepare-exact-build-tree
mkdir -p "${ANDROID_ROOT}/kernel" "${ANDROID_ROOT}/vendor" "${OUT_DIR}" "${ARM_OUT}"
git worktree add --detach "${KERNEL_DIR}" "${STAGE356_MERGE}"
rsync -a "${VENDOR_SOURCE}/vendor/" "${ANDROID_ROOT}/vendor/"
test "$(git -C "${KERNEL_DIR}" rev-parse HEAD)" = "${STAGE356_MERGE}"

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

checkpoint_step prepare-arm64-configuration
make -C "${KERNEL_DIR}" "${make_args[@]}" olddefconfig
"${KERNEL_DIR}/scripts/config" --file "${OUT_DIR}/.config" \
  --set-str LOCALVERSION -miru-h40-lts356-stage5 --disable MODULE_SIG_FORCE
make -C "${KERNEL_DIR}" "${make_args[@]}" olddefconfig prepare modules_prepare

checkpoint_step compile-arm64-regression-targets
built_targets=(
  arch/arm64/kernel/cpuinfo.o
  drivers/mmc/core/mmc_test.o
  drivers/net/usb/usbnet.o
  drivers/usb/dwc3/core.o
  drivers/usb/dwc3/gadget.o
  drivers/clk/clk-devres.o
  fs/f2fs/inode.o
  fs/f2fs/namei.o
  fs/f2fs/segment.o
  fs/f2fs/super.o
  net/qrtr/qrtr.o
  security/selinux/selinuxfs.o
  drivers/android/binder.o
  fs/aio.o
  mm/page_alloc.o
  mm/memory.o
  net/core/filter.o
)
for target in "${built_targets[@]}"; do
  echo "checkpoint_target_start=${target}"
  make -C "${KERNEL_DIR}" -j4 "${make_args[@]}" "${target}"
  test -s "${OUT_DIR}/${target}"
  echo "checkpoint_target_pass=${target}"
done

checkpoint_step compile-controlled-arm32-uaccess-probe
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

checkpoint_step verify-release-and-remote-boundaries
release="$(cat "${OUT_DIR}/include/config/kernel.release")"
release_make="$(make -s -C "${KERNEL_DIR}" "${make_args[@]}" kernelrelease)"
expected_release=4.14.356-openela-miru-h40-lts356-stage5+
test "${release}" = "${expected_release}"
test "${release_make}" = "${expected_release}"
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40 | awk 'NR==1{print $1}')" = "${PRODUCTION}"
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40-lts357-integration | awk 'NR==1{print $1}')" = "${EXPECTED_REMOTE_HEAD}"
test "$(git ls-remote https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git refs/heads/oneplus/sm8150_s_12.1_op7pro | awk 'NR==1{print $1}')" = "${MODULES_SHA}"

checkpoint_step complete
{
  echo result=PASS
  echo "integration_source_sha=${STAGE356_MERGE}"
  echo "stage356_merge=${STAGE356_MERGE}"
  echo "openela_second_parent=${OPENELA356}"
  echo "kernel_release=${release}"
  echo "compiler_commit=${CLANG_COMMIT}"
  echo compiler_identity=clang-r377782c
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
