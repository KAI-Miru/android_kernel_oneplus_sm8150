#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_COMMON_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=7f238bf25c273d745390146c6d74f1fce99eb4ba
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
OWNED_PATH=drivers/usb/dwc3/core.c
TARGET_OBJECT=drivers/usb/dwc3/core.o
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
EXPECTED_BASE_BLOB=0e179274ba7cdd6a512dedd77068d5b40eb44f8f
EXPECTED_SCAFFOLD_BLOB=660868a5371f7f2737ce62ab3e13624477c6dcfb
EXPECTED_TARGET_BLOB=5a4bd093c311fd5a8abbbb45d85af3ef46a34ddd
DIAG=lts305-dwc3-core-resolution

rm -rf "${DIAG}"
mkdir -p "${DIAG}"
START_HEAD="$(git rev-parse HEAD)"
REMOTE_PRODUCTION="$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')"
REMOTE_INTEGRATION="$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')"
test "${REMOTE_PRODUCTION}" = "${PRODUCTION_SHA}"
test "${REMOTE_INTEGRATION}" = "${START_HEAD}"
git merge-base --is-ancestor "${PRODUCTION_SHA}" "${START_HEAD}"
git merge-base --is-ancestor "${TARGET_COMMIT}" "${START_HEAD}"
git merge-base --is-ancestor "${SCAFFOLD}" "${START_HEAD}"
git merge-base --is-ancestor "${PREVIOUS_VALIDATED_HEAD}" "${START_HEAD}"
git merge-base --is-ancestor "${PREVIOUS_COMMON_TARGET}" "${TARGET_COMMIT}"
test "$(git rev-parse "${SCAFFOLD}^1")" = "${SCAFFOLD_PARENT1}"
test "$(git rev-parse "${SCAFFOLD}^2")" = "${TARGET_COMMIT}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305

git log --format='%H%x09%s' "${PREVIOUS_COMMON_TARGET}..${TARGET_COMMIT}" -- "${OWNED_PATH}" \
  > "${DIAG}/target-history.tsv"
TARGET_ULPI_COMMIT=7c87f1a44a07becdb2439dc60e5551cedaf89ec4
TARGET_PHY_COMMIT=967d57368d9a49af4f2150c8d9d3c3da865117da
grep -Fq "${TARGET_ULPI_COMMIT}"$'\t' "${DIAG}/target-history.tsv"
grep -Fq "${TARGET_PHY_COMMIT}"$'\t' "${DIAG}/target-history.tsv"
git show --format= --unified=0 "${TARGET_ULPI_COMMIT}" -- "${OWNED_PATH}" \
  > "${DIAG}/target-ulpi.patch"
grep -Fq $'+\t\t\t\tret = -EPROBE_DEFER;' "${DIAG}/target-ulpi.patch"
grep -Fq $'+\t\t\t\tdwc3_core_soft_reset(dwc);' "${DIAG}/target-ulpi.patch"
git show --format= --unified=0 "${TARGET_PHY_COMMIT}" -- "${OWNED_PATH}" \
  > "${DIAG}/target-phy-disable.patch"
grep -Fq -- $'-\tusb_phy_shutdown(dwc->usb2_phy);' "${DIAG}/target-phy-disable.patch"
grep -Fq $'+\tusb_phy_shutdown(dwc->usb2_phy);' "${DIAG}/target-phy-disable.patch"
grep -Fq -- $'-\tphy_power_off(dwc->usb2_generic_phy);' "${DIAG}/target-phy-disable.patch"
grep -Fq $'+\tphy_power_off(dwc->usb2_generic_phy);' "${DIAG}/target-phy-disable.patch"
TARGET_DWC3_COMMITS=("${TARGET_ULPI_COMMIT}" "${TARGET_PHY_COMMIT}")
for sha in "${TARGET_DWC3_COMMITS[@]}"; do
  git merge-base --is-ancestor "${sha}" "${TARGET_COMMIT}"
done
printf '%s\n' "${TARGET_DWC3_COMMITS[@]}" > "${DIAG}/target-dwc3-commits.txt"
: > "${DIAG}/target-dwc3-upstream.txt"
for sha in "${TARGET_DWC3_COMMITS[@]}"; do
  git show -s --format=fuller "${sha}" >> "${DIAG}/target-dwc3-upstream.txt"
done
git show "${TARGET_COMMIT}:${OWNED_PATH}" > "${DIAG}/target-core.c"

if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"; then
  grep -Fq -- '- Semantically resolved conflicts: **26**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **7**' "${LEDGER}"
  grep -Fq '### DWC3 PHY lifecycle and ULPI timeout recovery' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **25**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **8**' "${LEDGER}"
git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git rev-parse "${PREVIOUS_COMMON_TARGET}:${OWNED_PATH}")" = "${EXPECTED_BASE_BLOB}"
test "$(git rev-parse "${SCAFFOLD}:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "HEAD:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "${TARGET_COMMIT}:${OWNED_PATH}")" = "${EXPECTED_TARGET_BLOB}"

git config user.name "Miru LTS Integration Bot"
git config user.email "miru-lts-integration@users.noreply.github.com"
export OWNED_PATH TARGET_COMMIT DIAG
python3 - <<'PY' | tee "${DIAG}/resolver.txt"
from pathlib import Path
import hashlib
import os
import subprocess

owned = Path(os.environ["OWNED_PATH"])
current = owned.read_text()
target = subprocess.check_output(
    ["git", "show", f"{os.environ['TARGET_COMMIT']}:{os.environ['OWNED_PATH']}"],
    text=True,
)

ulpi_current = (
    "\tif (!dwc->ulpi_ready) {\n"
    "\t\tret = dwc3_core_ulpi_init(dwc);\n"
    "\t\tif (ret)\n"
    "\t\t\tgoto err0;\n"
    "\t\tdwc->ulpi_ready = true;\n"
    "\t}\n"
)
ulpi_target = (
    "\tif (!dwc->ulpi_ready) {\n"
    "\t\tret = dwc3_core_ulpi_init(dwc);\n"
    "\t\tif (ret) {\n"
    "\t\t\tif (ret == -ETIMEDOUT) {\n"
    "\t\t\t\tdwc3_core_soft_reset(dwc);\n"
    "\t\t\t\tret = -EPROBE_DEFER;\n"
    "\t\t\t}\n"
    "\t\t\tgoto err0;\n"
    "\t\t}\n"
    "\t\tdwc->ulpi_ready = true;\n"
    "\t}\n"
)
exit_current = (
    "static void dwc3_core_exit(struct dwc3 *dwc)\n"
    "{\n"
    "\tdwc3_event_buffers_cleanup(dwc);\n\n"
    "\tusb_phy_shutdown(dwc->usb2_phy1);\n"
    "\tusb_phy_shutdown(dwc->usb2_phy);\n"
    "\tusb_phy_shutdown(dwc->usb3_phy1);\n"
    "\tusb_phy_shutdown(dwc->usb3_phy);\n"
    "\tphy_exit(dwc->usb2_generic_phy);\n"
    "\tphy_exit(dwc->usb3_generic_phy);\n\n"
    "\tusb_phy_set_suspend(dwc->usb2_phy1, 1);\n"
    "\tusb_phy_set_suspend(dwc->usb2_phy, 1);\n"
    "\tusb_phy_set_suspend(dwc->usb3_phy1, 1);\n"
    "\tusb_phy_set_suspend(dwc->usb3_phy, 1);\n"
    "\tphy_power_off(dwc->usb2_generic_phy);\n"
    "\tphy_power_off(dwc->usb3_generic_phy);\n"
    "}\n"
)
exit_target_core = (
    "\tdwc3_event_buffers_cleanup(dwc);\n\n"
    "\tusb_phy_set_suspend(dwc->usb2_phy, 1);\n"
    "\tusb_phy_set_suspend(dwc->usb3_phy, 1);\n"
    "\tphy_power_off(dwc->usb2_generic_phy);\n"
    "\tphy_power_off(dwc->usb3_generic_phy);\n\n"
    "\tusb_phy_shutdown(dwc->usb2_phy);\n"
    "\tusb_phy_shutdown(dwc->usb3_phy);\n"
    "\tphy_exit(dwc->usb2_generic_phy);\n"
    "\tphy_exit(dwc->usb3_generic_phy);\n"
)
exit_resolved = (
    "static void dwc3_core_exit(struct dwc3 *dwc)\n"
    "{\n"
    "\tdwc3_event_buffers_cleanup(dwc);\n\n"
    "\tusb_phy_set_suspend(dwc->usb2_phy1, 1);\n"
    "\tusb_phy_set_suspend(dwc->usb2_phy, 1);\n"
    "\tusb_phy_set_suspend(dwc->usb3_phy1, 1);\n"
    "\tusb_phy_set_suspend(dwc->usb3_phy, 1);\n"
    "\tphy_power_off(dwc->usb2_generic_phy);\n"
    "\tphy_power_off(dwc->usb3_generic_phy);\n\n"
    "\tusb_phy_shutdown(dwc->usb2_phy1);\n"
    "\tusb_phy_shutdown(dwc->usb2_phy);\n"
    "\tusb_phy_shutdown(dwc->usb3_phy1);\n"
    "\tusb_phy_shutdown(dwc->usb3_phy);\n"
    "\tphy_exit(dwc->usb2_generic_phy);\n"
    "\tphy_exit(dwc->usb3_generic_phy);\n"
    "}\n"
)
init_error = (
    "err3:\n"
    "\tphy_power_off(dwc->usb2_generic_phy);\n\n"
    "err2:\n"
    "\tusb_phy_set_suspend(dwc->usb2_phy1, 1);\n"
    "\tusb_phy_set_suspend(dwc->usb3_phy1, 1);\n"
    "\tusb_phy_set_suspend(dwc->usb2_phy, 1);\n"
    "\tusb_phy_set_suspend(dwc->usb3_phy, 1);\n"
    "\tdwc3_free_scratch_buffers(dwc);\n\n"
    "err1:\n"
    "\tusb_phy_shutdown(dwc->usb2_phy1);\n"
    "\tusb_phy_shutdown(dwc->usb3_phy1);\n"
    "\tusb_phy_shutdown(dwc->usb2_phy);\n"
    "\tusb_phy_shutdown(dwc->usb3_phy);\n"
    "\tphy_exit(dwc->usb2_generic_phy);\n"
    "\tphy_exit(dwc->usb3_generic_phy);\n"
)

if target.count(ulpi_target) != 1:
    raise SystemExit("target ULPI timeout recovery block is not exact")
if target.count(exit_target_core) != 2:
    raise SystemExit("target PHY disable ordering must occur in core-exit and probe-error paths")
if current.count(ulpi_current) != 1:
    raise SystemExit("scaffold ULPI anchor is not exact")
if current.count(exit_current) != 1:
    raise SystemExit("scaffold DWC3 core-exit block is not exact")
if current.count(init_error) != 1:
    raise SystemExit("scaffold DWC3 init-error cleanup is not exact")
if ulpi_target in current or exit_resolved in current:
    raise SystemExit("scaffold unexpectedly already contains a target safety sequence")

downstream_markers = [
    "static struct dwc3 *dwc3_instance[DWC_CTRL_COUNT];",
    "void dwc3_usb3_phy_suspend(struct dwc3 *dwc, int suspend)",
    "dwc3_notify_event(dwc, DWC3_CONTROLLER_POST_RESET_EVENT, 0);",
]
for marker in downstream_markers:
    if current.count(marker) != 1:
        raise SystemExit(f"missing downstream DWC3 marker: {marker}")

resolved = current.replace(ulpi_current, ulpi_target, 1)
resolved = resolved.replace(exit_current, exit_resolved, 1)
for marker in downstream_markers:
    if resolved.count(marker) != 1:
        raise SystemExit(f"downstream DWC3 marker lost or duplicated: {marker}")
if resolved.count(init_error) != 1:
    raise SystemExit("DWC3 init-error cleanup changed unexpectedly")

reversed_text = resolved.replace(ulpi_target, ulpi_current, 1)
reversed_text = reversed_text.replace(exit_resolved, exit_current, 1)
if reversed_text != current:
    raise SystemExit("resolver does not exactly reverse to the scaffold file")

exit_start = resolved.index("static void dwc3_core_exit")
exit_end = resolved.index("\n}\n", exit_start) + 3
exit_body = resolved[exit_start:exit_end]
if not (
    exit_body.index("usb_phy_set_suspend(dwc->usb2_phy1, 1)") <
    exit_body.index("phy_power_off(dwc->usb2_generic_phy)") <
    exit_body.index("usb_phy_shutdown(dwc->usb2_phy1)") <
    exit_body.index("phy_exit(dwc->usb2_generic_phy)")
):
    raise SystemExit("resolved DWC3 core-exit PHY ordering is unsafe")

owned.write_text(resolved)
print("status=resolved")
print("android_safety_sequences=2")
print("dual_port_phy_order_preserved=yes")
print("target_exit_sequence_sha256=" + hashlib.sha256(exit_target_core.encode()).hexdigest())
print("ulpi_timeout_sequence_sha256=" + hashlib.sha256(ulpi_target.encode()).hexdigest())
PY

git diff --binary --full-index > "${DIAG}/source.patch"
test -s "${DIAG}/source.patch"
PATCH_SHA="$(sha256sum "${DIAG}/source.patch" | awk '{print $1}')"
git diff --check
if git grep -nE '^(<<<<<<< .+|>>>>>>> .+|\|\|\|\|\|\|\| .+)$' -- "${OWNED_PATH}" \
    > "${DIAG}/conflict-markers.txt"; then
  cat "${DIAG}/conflict-markers.txt"
  exit 1
else
  : > "${DIAG}/conflict-markers.txt"
fi
python3 - "${OWNED_PATH}" <<'PY' | tee "${DIAG}/source-behavior.txt"
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
assert text.count("if (ret == -ETIMEDOUT)") == 1
assert text.count("ret = -EPROBE_DEFER;") == 1
start = text.index("static void dwc3_core_exit")
end = text.index("\n}\n", start) + 3
body = text[start:end]
assert body.index("usb_phy_set_suspend(dwc->usb2_phy1, 1)") < body.index("phy_power_off(dwc->usb2_generic_phy)")
assert body.index("phy_power_off(dwc->usb2_generic_phy)") < body.index("usb_phy_shutdown(dwc->usb2_phy1)")
assert body.index("usb_phy_shutdown(dwc->usb2_phy1)") < body.index("phy_exit(dwc->usb2_generic_phy)")
print("source_behavior_gates=PASS")
PY
git add -- "${OWNED_PATH}"
test "$(git diff --cached --name-only)" = "${OWNED_PATH}"
git commit -m 'lts: resolve DWC3 PHY lifecycle safety for 4.14.305'
SOURCE_COMMIT="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${START_HEAD}"
test "$(git diff-tree --no-commit-id --name-only -r "${SOURCE_COMMIT}")" = "${OWNED_PATH}"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file

ANDROID_ROOT="${RUNNER_TEMP}/android-root"
KERNEL_WORKTREE="${ANDROID_ROOT}/kernel/msm-4.14"
VENDOR_SOURCE="${RUNNER_TEMP}/oneplus-sm8150-vendor-source"
OUT_DIR="${ANDROID_ROOT}/out/h40-dwc3-core-targeted"
TOOLCHAIN_ROOT="${RUNNER_TEMP}/miru-toolchains"
rm -rf "${ANDROID_ROOT}" "${VENDOR_SOURCE}" "${TOOLCHAIN_ROOT}"
mkdir -p "${ANDROID_ROOT}/kernel" "${ANDROID_ROOT}/out" "${TOOLCHAIN_ROOT}"
git worktree prune
git worktree add --detach "${KERNEL_WORKTREE}" "${SOURCE_COMMIT}"

git init -q "${VENDOR_SOURCE}"
git -C "${VENDOR_SOURCE}" remote add origin \
  https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git
git -C "${VENDOR_SOURCE}" fetch -q --depth=1 --filter=blob:none origin "${VENDOR_SHA}"
git -C "${VENDOR_SOURCE}" checkout -q --detach FETCH_HEAD
test "$(git -C "${VENDOR_SOURCE}" rev-parse HEAD)" = "${VENDOR_SHA}"
mkdir -p "${ANDROID_ROOT}/vendor"
rsync -a "${VENDOR_SOURCE}/vendor/" "${ANDROID_ROOT}/vendor/"
test -f "${KERNEL_WORKTREE}/block/oplus_foreground_io_opt/Kconfig"

fetch_root() {
  local url="$1" commit="$2" dest="$3"
  git init -q "${dest}"
  git -C "${dest}" remote add origin "${url}"
  git -C "${dest}" fetch -q --depth=1 --filter=blob:none origin "${commit}"
  git -C "${dest}" checkout -q --detach FETCH_HEAD
  test "$(git -C "${dest}" rev-parse HEAD)" = "${commit}"
}
fetch_sparse() {
  local url="$1" commit="$2" dest="$3" sparse_path="$4"
  git init -q "${dest}"
  git -C "${dest}" remote add origin "${url}"
  git -C "${dest}" sparse-checkout init --cone
  git -C "${dest}" sparse-checkout set "${sparse_path}"
  git -C "${dest}" fetch -q --depth=1 --filter=blob:none origin "${commit}"
  git -C "${dest}" checkout -q --detach FETCH_HEAD
  test "$(git -C "${dest}" rev-parse HEAD)" = "${commit}"
}
fetch_sparse \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
  252aba16f513a857bc923172f67b0e55e23de35f \
  "${TOOLCHAIN_ROOT}/clang-repo" clang-r377782c
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
  2f78058a8549bc5c099dbea16d9f3dc571e072b1ade906c3539e419787b502dd \
  "${GCC32_DIR}/bin/arm-linux-androideabi-as" | sha256sum -c -
printf '%s  %s\n' \
  5630a485d7c597d137fa462626213007e8865cf549677e1f727d131695ec830c \
  "${AOSP_BUILD_TOOLS}/bin/py2-cmd" | sha256sum -c -

mkdir -p "${OUT_DIR}"
cp "${KERNEL_WORKTREE}/h40-repro/config/GM1911_11_H.40.config" "${OUT_DIR}/.config"
sed -i 's/\r$//' "${OUT_DIR}/.config"
CLANG="${CLANG_DIR}/bin/clang"
CROSS64="${GCC64_DIR}/bin/aarch64-linux-android-"
CROSS32="${GCC32_DIR}/bin/arm-linux-androideabi-"
PYTHON2="${AOSP_BUILD_TOOLS}/bin/py2-cmd"
export PATH="${AOSP_BUILD_TOOLS}/bin:${CLANG_DIR}/bin:${GCC64_DIR}/bin:${GCC32_DIR}/bin:${PATH}"
export ARCH=arm64 SUBARCH=arm64
make_args=(
  "O=${OUT_DIR}" "ARCH=arm64" "TARGET_PRODUCT=msmnile"
  "BRAND_SHOW_FLAG=oneplus" "TARGET_BUILD_VARIANT=user"
  "CROSS_COMPILE=${CROSS64}" "CROSS_COMPILE_ARM32=${CROSS32}"
  "REAL_CC=${CLANG}" "CLANG_TRIPLE=aarch64-linux-gnu-" "PYTHON=${PYTHON2}"
  "HOSTCC=gcc" "HOSTCXX=g++" "LOCALVERSION=+"
)
make -C "${KERNEL_WORKTREE}" "${make_args[@]}" olddefconfig \
  2>&1 | tee "${DIAG}/olddefconfig.log"
grep -Fq 'CONFIG_MODVERSIONS=y' "${OUT_DIR}/.config"
grep -Fq 'CONFIG_USB_DWC3=y' "${OUT_DIR}/.config"
cp "${OUT_DIR}/.config" "${DIAG}/resolved.config"
make -C "${KERNEL_WORKTREE}" -j4 V=0 "${make_args[@]}" "${TARGET_OBJECT}" \
  2>&1 | tee "${DIAG}/targeted-compile.log"
test -s "${OUT_DIR}/${TARGET_OBJECT}"
if grep -nE '(^|[[:space:]])(warning|error):' \
    "${DIAG}/olddefconfig.log" "${DIAG}/targeted-compile.log" \
    > "${DIAG}/targeted-diagnostics.txt"; then
  cat "${DIAG}/targeted-diagnostics.txt"
  exit 1
else
  : > "${DIAG}/targeted-diagnostics.txt"
fi
{
  echo "result=PASS"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "target_object=${TARGET_OBJECT}"
  echo "dwc3_enabled=yes"
  echo "android_safety_sequences=2"
  echo "dual_port_phy_order_retained=yes"
  echo "compiler=$("${CLANG}" --version | head -n1)"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-dwc3-core-revert"
rm -rf "${REVERT_WORKTREE}"
git worktree add --detach "${REVERT_WORKTREE}" "${SOURCE_COMMIT}"
git -C "${REVERT_WORKTREE}" config user.name "Miru LTS Integration Bot"
git -C "${REVERT_WORKTREE}" config user.email "miru-lts-integration@users.noreply.github.com"
git -C "${REVERT_WORKTREE}" revert --no-edit "${SOURCE_COMMIT}" \
  > "${DIAG}/revert.stdout" 2> "${DIAG}/revert.stderr"
git -C "${REVERT_WORKTREE}" diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${OWNED_PATH}")" = \
     "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse 'HEAD^{tree}')" = \
     "$(git rev-parse "${START_HEAD}^{tree}")"
{
  echo "result=PASS"
  echo "owning_commit=${SOURCE_COMMIT}"
  echo "revert_commit=$(git -C "${REVERT_WORKTREE}" rev-parse HEAD)"
  echo "restored_scaffold=${SCAFFOLD}"
  echo "restored_path=${OWNED_PATH}"
  echo "restored_start_tree=$(git rev-parse "${START_HEAD}^{tree}")"
} | tee "${DIAG}/reversal-summary.txt"

TARGET_DWC3_COMMITS_CSV="$(IFS=,; echo "${TARGET_DWC3_COMMITS[*]}")"
export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA TARGET_DWC3_COMMITS_CSV TARGET_COMMIT EXPECTED_SCAFFOLD_BLOB EXPECTED_TARGET_BLOB
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["LEDGER"])
text = path.read_text()
for old, new in {
    "- Semantically resolved conflicts: **25**": "- Semantically resolved conflicts: **26**",
    "- Remaining semantic conflicts: **8**": "- Remaining semantic conflicts: **7**",
}.items():
    if old not in text:
        raise SystemExit(f"missing ledger status: {old}")
    text = text.replace(old, new, 1)

source = os.environ["SOURCE_COMMIT"]
pattern = re.compile(
    r"^(\| 18 \| .*? \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$",
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit("missing unresolved DWC3 manifest row 18")
replacement = (
    match.group(1) + "resolved" +
    f" | {chr(96)}{source}{chr(96)} | core.o PASS | clean reversal PASS |"
)
text = text[:match.start()] + replacement + text[match.end():]

bt = chr(96)
record = f"""
### DWC3 PHY lifecycle and ULPI timeout recovery

- Owning source commit: {bt}{source}{bt}.
- Owned path: {bt}drivers/usb/dwc3/core.c{bt}.
- Relevant Android Common commits: {bt}{os.environ['TARGET_DWC3_COMMITS_CSV']}{bt}, both target-reachable from {bt}{os.environ['TARGET_COMMIT']}{bt}.
- Provenance verification: the ULPI deferred-probe sequence and the PHY disable reordering were each checked as an added/removal sequence in their own target-reachable commit.
- Android behavior imported: retry an ULPI timeout through a core soft reset and deferred probe; suspend legacy PHYs and power off Generic PHYs before shutting either down or exiting it.
- Downstream intent retained: Miru dual-port PHY1 ordering, controller-instance bookkeeping, USB3 suspend helper, and controller-notify hook are preserved.
- Semantic decision: apply Android's two safety sequences to the matching Miru core-init and runtime-suspend topology. The existing core-init failure cleanup is asserted unchanged because it already performs generic power-off before Generic PHY exit and legacy suspend before legacy shutdown.
- Scaffold blob: {bt}{os.environ['EXPECTED_SCAFFOLD_BLOB']}{bt}. Target blob: {bt}{os.environ['EXPECTED_TARGET_BLOB']}{bt}.
- Audited source patch SHA-256: {bt}{os.environ['PATCH_SHA']}{bt} using {bt}git diff --binary --full-index{bt}.
- Targeted compilation: **PASS** for {bt}drivers/usb/dwc3/core.o{bt} using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android safety-sequence, dual-port preservation, and unchanged error-cleanup gates: **PASS**.
- Clean reversal: **PASS**; reverting {bt}{source}{bt} restored {bt}drivers/usb/dwc3/core.c{bt} exactly to scaffold {bt}{os.environ['SCAFFOLD']}{bt} and restored the complete pre-resolution integration tree.
- Validation workflow run: {bt}{os.environ.get('GITHUB_RUN_ID', 'unknown')}{bt}.
"""
if "### DWC3 PHY lifecycle and ULPI timeout recovery" in text:
    raise SystemExit("DWC3 resolution record already exists")
path.write_text(text + record)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record DWC3 core validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=26"
  echo "semantic_conflicts_remaining=7"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
