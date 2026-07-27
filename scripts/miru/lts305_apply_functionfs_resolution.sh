#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_COMMON_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=e4289047e630314e7e0d9f3e7d77db4e11ac6995
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
OWNED_PATH=drivers/usb/gadget/function/f_fs.c
TARGET_OBJECT=drivers/usb/gadget/function/f_fs.o
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
EXPECTED_BASE_BLOB=13a38ed806df9734035311dc2e736bfa20bc4ac7
EXPECTED_SCAFFOLD_BLOB=30da2ae088d7796ffc4d2f6a35562be9426344fe
EXPECTED_TARGET_BLOB=946cf039edddb7d5cf4b144c61703218a24d6c41
DIAG=lts305-functionfs-resolution

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
TARGET_RACE_COMMITS=()
TARGET_DEQUEUE_COMMITS=()
while IFS=$'\t' read -r sha subject; do
  patch="$(git show --format= --unified=0 "${sha}" -- "${OWNED_PATH}")"
  if printf '%s\n' "${patch}" | grep '^+' | grep -Fq $'\tif (!req)' &&
     printf '%s\n' "${patch}" | grep '^+' | grep -Fq $'\t\treturn -EINVAL;'; then
    TARGET_RACE_COMMITS+=("${sha}")
  fi
  if printf '%s\n' "${patch}" | grep '^+' | \
       grep -Fq $'\t\tusb_ep_dequeue(ffs->gadget->ep0, ffs->ep0req);'; then
    TARGET_DEQUEUE_COMMITS+=("${sha}")
  fi
done < "${DIAG}/target-history.tsv"
test "${#TARGET_RACE_COMMITS[@]}" = 1
test "${#TARGET_DEQUEUE_COMMITS[@]}" = 1
test "${TARGET_RACE_COMMITS[0]}" != "${TARGET_DEQUEUE_COMMITS[0]}"
TARGET_FFS_COMMITS=("${TARGET_RACE_COMMITS[0]}" "${TARGET_DEQUEUE_COMMITS[0]}")
for sha in "${TARGET_FFS_COMMITS[@]}"; do
  git merge-base --is-ancestor "${sha}" "${TARGET_COMMIT}"
done
printf '%s\n' "${TARGET_FFS_COMMITS[@]}" > "${DIAG}/target-functionfs-commits.txt"
: > "${DIAG}/target-functionfs-upstream.txt"
for sha in "${TARGET_FFS_COMMITS[@]}"; do
  git show -s --format=fuller "${sha}" >> "${DIAG}/target-functionfs-upstream.txt"
done
git show "${TARGET_COMMIT}:${OWNED_PATH}" > "${DIAG}/target-f_fs.c"

if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"; then
  grep -Fq -- '- Semantically resolved conflicts: **24**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **9**' "${LEDGER}"
  grep -Fq '### FunctionFS EP0 lifetime safety' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **23**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **10**' "${LEDGER}"
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

queue_needle = (
    "\tstruct usb_request *req = ffs->ep0req;\n"
    "\tint ret;\n\n"
    "\treq->zero     = len < le16_to_cpu(ffs->ev.setup.wLength);\n"
)
queue_target_block = (
    "\tstruct usb_request *req = ffs->ep0req;\n"
    "\tint ret;\n\n"
    "\tif (!req)\n"
    "\t\treturn -EINVAL;\n\n"
    "\treq->zero     = len < le16_to_cpu(ffs->ev.setup.wLength);\n"
)
queue_replacement = queue_target_block

unbind_current_block = (
    "\tif (!WARN_ON(!ffs->gadget)) {\n"
    "\t\tusb_ep_free_request(ffs->gadget->ep0, ffs->ep0req);\n"
    "\t\tffs->ep0req = NULL;\n"
    "\t\tffs->gadget = NULL;\n"
    "\t\tclear_bit(FFS_FL_BOUND, &ffs->flags);\n"
    "\t\tffs_log(\"state %d setup_state %d flag %lu gadget %pK\\n\",\n"
    "\t\t\tffs->state, ffs->setup_state, ffs->flags, ffs->gadget);\n"
    "\t\tffs_data_put(ffs);\n"
    "\t}\n"
)
unbind_target_block = (
    "\tif (!WARN_ON(!ffs->gadget)) {\n"
    "\t\t/* dequeue before freeing ep0req */\n"
    "\t\tusb_ep_dequeue(ffs->gadget->ep0, ffs->ep0req);\n"
    "\t\tmutex_lock(&ffs->mutex);\n"
    "\t\tusb_ep_free_request(ffs->gadget->ep0, ffs->ep0req);\n"
    "\t\tffs->ep0req = NULL;\n"
    "\t\tffs->gadget = NULL;\n"
    "\t\tclear_bit(FFS_FL_BOUND, &ffs->flags);\n"
    "\t\tmutex_unlock(&ffs->mutex);\n"
    "\t\tffs_data_put(ffs);\n"
    "\t}\n"
)
unbind_replacement = (
    "\tif (!WARN_ON(!ffs->gadget)) {\n"
    "\t\t/* dequeue before freeing ep0req */\n"
    "\t\tusb_ep_dequeue(ffs->gadget->ep0, ffs->ep0req);\n"
    "\t\tmutex_lock(&ffs->mutex);\n"
    "\t\tusb_ep_free_request(ffs->gadget->ep0, ffs->ep0req);\n"
    "\t\tffs->ep0req = NULL;\n"
    "\t\tffs->gadget = NULL;\n"
    "\t\tclear_bit(FFS_FL_BOUND, &ffs->flags);\n"
    "\t\tffs_log(\"state %d setup_state %d flag %lu gadget %pK\\n\",\n"
    "\t\t\tffs->state, ffs->setup_state, ffs->flags, ffs->gadget);\n"
    "\t\tmutex_unlock(&ffs->mutex);\n"
    "\t\tffs_data_put(ffs);\n"
    "\t}\n"
)

if target.count(queue_target_block) != 1:
    raise SystemExit("target queue safety block is not exact")
if target.count(unbind_target_block) != 1:
    raise SystemExit("target unbind safety block is not exact")
if current.count(queue_needle) != 1:
    raise SystemExit("scaffold queue anchor is not exact")
if current.count(unbind_current_block) != 1:
    raise SystemExit("scaffold unbind anchor is not exact")
if queue_target_block in current or unbind_target_block in current:
    raise SystemExit("scaffold unexpectedly already contains a target safety block")

downstream_logs = [
    'ffs_log("enter: state %d setup_state %d flags %lu"',
    'ffs_log("exit: state %d setup_state %d flags %lu"',
    'ffs_log("state %d setup_state %d flag %lu gadget %pK\\n"',
]
for marker in downstream_logs:
    if current.count(marker) != 1:
        raise SystemExit(f"unexpected downstream log marker: {marker}")

resolved = current.replace(queue_needle, queue_replacement, 1)
resolved = resolved.replace(unbind_current_block, unbind_replacement, 1)
for marker in downstream_logs:
    if resolved.count(marker) != 1:
        raise SystemExit(f"downstream log lost or duplicated: {marker}")

reversed_text = resolved.replace(queue_replacement, queue_needle, 1)
reversed_text = reversed_text.replace(unbind_replacement, unbind_current_block, 1)
if reversed_text != current:
    raise SystemExit("resolver does not exactly reverse to the scaffold file")

unbind_start = resolved.index("static void functionfs_unbind")
unbind_end = resolved.index("\n}\n", unbind_start) + 3
unbind = resolved[unbind_start:unbind_end]
for marker in (
    "/* dequeue before freeing ep0req */",
    "usb_ep_dequeue(ffs->gadget->ep0, ffs->ep0req);",
    "mutex_lock(&ffs->mutex);",
    "mutex_unlock(&ffs->mutex);",
):
    if unbind.count(marker) != 1:
        raise SystemExit(f"resolved unbind safety marker missing: {marker}")
if not (
    unbind.index("usb_ep_dequeue") < unbind.index("mutex_lock") <
    unbind.index("usb_ep_free_request") < unbind.index("clear_bit") <
    unbind.index("ffs_log") < unbind.index("mutex_unlock") <
    unbind.index("ffs_data_put")
):
    raise SystemExit("resolved unbind ordering is unsafe")

owned.write_text(resolved)
print("status=resolved")
print("android_safety_blocks=2")
print("downstream_functionfs_logs_preserved=yes")
print("queue_guard_sha256=" + hashlib.sha256(queue_target_block.encode()).hexdigest())
print("unbind_safety_sha256=" + hashlib.sha256(unbind_target_block.encode()).hexdigest())
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
assert text.count("\tif (!req)\n\t\treturn -EINVAL;\n") == 1
start = text.index("static void functionfs_unbind")
end = text.index("\n}\n", start) + 3
unbind = text[start:end]
for marker in (
    "\t\t/* dequeue before freeing ep0req */\n",
    "\t\tusb_ep_dequeue(ffs->gadget->ep0, ffs->ep0req);\n",
    "\t\tmutex_lock(&ffs->mutex);\n",
    "\t\tmutex_unlock(&ffs->mutex);\n",
):
    assert unbind.count(marker) == 1, marker
assert unbind.index("usb_ep_dequeue") < unbind.index("mutex_lock")
assert unbind.index("mutex_lock") < unbind.index("usb_ep_free_request")
assert unbind.index("usb_ep_free_request") < unbind.index("mutex_unlock")
assert unbind.index("mutex_unlock") < unbind.index("ffs_data_put")
print("source_behavior_gates=PASS")
PY
git add -- "${OWNED_PATH}"
test "$(git diff --cached --name-only)" = "${OWNED_PATH}"
git commit -m 'lts: resolve FunctionFS EP0 lifetime safety for 4.14.305'
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
OUT_DIR="${ANDROID_ROOT}/out/h40-functionfs-targeted"
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
grep -Fq 'CONFIG_USB_CONFIGFS_F_FS=y' "${OUT_DIR}/.config"
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
  echo "functionfs_enabled=yes"
  echo "android_safety_blocks=2"
  echo "downstream_functionfs_logs_retained=yes"
  echo "compiler=$("${CLANG}" --version | head -n1)"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-functionfs-revert"
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

TARGET_FFS_COMMITS_CSV="$(IFS=,; echo "${TARGET_FFS_COMMITS[*]}")"
export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA TARGET_FFS_COMMITS_CSV TARGET_COMMIT EXPECTED_SCAFFOLD_BLOB EXPECTED_TARGET_BLOB
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["LEDGER"])
text = path.read_text()
for old, new in {
    "- Semantically resolved conflicts: **23**": "- Semantically resolved conflicts: **24**",
    "- Remaining semantic conflicts: **10**": "- Remaining semantic conflicts: **9**",
}.items():
    if old not in text:
        raise SystemExit(f"missing ledger status: {old}")
    text = text.replace(old, new, 1)

source = os.environ["SOURCE_COMMIT"]
pattern = re.compile(
    r"^(\| 19 \| .*? \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$",
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit("missing unresolved FunctionFS manifest row 19")
replacement = (
    match.group(1) + "resolved" +
    f" | {chr(96)}{source}{chr(96)} | f_fs.o PASS | clean reversal PASS |"
)
text = text[:match.start()] + replacement + text[match.end():]

bt = chr(96)
record = f"""
### FunctionFS EP0 lifetime safety

- Owning source commit: {bt}{source}{bt}.
- Owned path: {bt}drivers/usb/gadget/function/f_fs.c{bt}.
- Relevant Android Common commits: {bt}{os.environ['TARGET_FFS_COMMITS_CSV']}{bt}, both target-reachable from {bt}{os.environ['TARGET_COMMIT']}{bt}.
- Provenance verification: each listed safety marker was checked as an added line in its own target-reachable commit.
- Android behavior imported: guard the EP0 request before queueing it, dequeue it before freeing it, and serialize the unbind state transition with the FunctionFS mutex.
- Downstream intent retained: Miru's three FunctionFS state diagnostics remain exactly once; the unbind diagnostic stays within the new mutex-protected state transition.
- Semantic decision: apply the Android lifetime-safety sequence without removing Miru diagnostics or changing any unrelated FunctionFS behavior.
- Scaffold blob: {bt}{os.environ['EXPECTED_SCAFFOLD_BLOB']}{bt}. Target blob: {bt}{os.environ['EXPECTED_TARGET_BLOB']}{bt}.
- Audited source patch SHA-256: {bt}{os.environ['PATCH_SHA']}{bt} using {bt}git diff --binary --full-index{bt}.
- Targeted compilation: **PASS** for {bt}drivers/usb/gadget/function/f_fs.o{bt} using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android safety-sequence and downstream-diagnostic preservation gates: **PASS**.
- Clean reversal: **PASS**; reverting {bt}{source}{bt} restored {bt}drivers/usb/gadget/function/f_fs.c{bt} exactly to scaffold {bt}{os.environ['SCAFFOLD']}{bt} and restored the complete pre-resolution integration tree.
- Validation workflow run: {bt}{os.environ.get('GITHUB_RUN_ID', 'unknown')}{bt}.
"""
if "### FunctionFS EP0 lifetime safety" in text:
    raise SystemExit("FunctionFS resolution record already exists")
path.write_text(text + record)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record FunctionFS lifetime validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=24"
  echo "semantic_conflicts_remaining=9"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
