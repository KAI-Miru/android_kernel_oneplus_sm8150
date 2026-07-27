#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_COMMON_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=3ed5b814698350c572a5e4874f64b30873548840
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
OWNED_PATH=drivers/usb/gadget/function/rndis.c
TARGET_OBJECT=drivers/usb/gadget/function/rndis.o
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
EXPECTED_BASE_BLOB=55be224b64a48690a309a136ce0dc3c3796ddf65
EXPECTED_SCAFFOLD_BLOB=d1737f27147067ea9044027fbae5cedf8bab6e6c
EXPECTED_TARGET_BLOB=b6c707246dadd7f727e1855b32d927df28db40c9
DIAG=lts305-rndis-target-equivalence

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
TARGET_RNDIS_COMMITS=()
while IFS=$'\t' read -r sha subject; do
  if git show --format= --unified=0 "${sha}" -- "${OWNED_PATH}" | \
      grep '^+' | grep -Fq 'BufOffset > RNDIS_MAX_TOTAL_SIZE'; then
    TARGET_RNDIS_COMMITS+=("${sha}")
  fi
done < "${DIAG}/target-history.tsv"
test "${#TARGET_RNDIS_COMMITS[@]}" = 1
TARGET_RNDIS_COMMIT="${TARGET_RNDIS_COMMITS[0]}"
git merge-base --is-ancestor "${TARGET_RNDIS_COMMIT}" "${TARGET_COMMIT}"
printf '%s\n' "${TARGET_RNDIS_COMMIT}" > "${DIAG}/target-rndis-commit.txt"
git show -s --format=fuller "${TARGET_RNDIS_COMMIT}" \
  > "${DIAG}/target-rndis-upstream.txt"
git show "${TARGET_COMMIT}:${OWNED_PATH}" > "${DIAG}/target-rndis.c"

if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"; then
  grep -Fq -- '- Semantically resolved conflicts: **25**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **8**' "${LEDGER}"
  grep -Fq '### RNDIS set-request bounds equivalence' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **24**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **9**' "${LEDGER}"
git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git rev-parse "${PREVIOUS_COMMON_TARGET}:${OWNED_PATH}")" = "${EXPECTED_BASE_BLOB}"
test "$(git rev-parse "${SCAFFOLD}:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "HEAD:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "${TARGET_COMMIT}:${OWNED_PATH}")" = "${EXPECTED_TARGET_BLOB}"

export OWNED_PATH PREVIOUS_COMMON_TARGET TARGET_COMMIT DIAG
python3 - <<'PY' | tee "${DIAG}/equivalence.txt"
from pathlib import Path
import os
import re
import subprocess

owned = Path(os.environ["OWNED_PATH"])
base = subprocess.check_output(
    ["git", "show", f"{os.environ['PREVIOUS_COMMON_TARGET']}:{os.environ['OWNED_PATH']}"],
    text=True,
)
current = owned.read_text()
target = subprocess.check_output(
    ["git", "show", f"{os.environ['TARGET_COMMIT']}:{os.environ['OWNED_PATH']}"],
    text=True,
)
marker = "BufOffset > RNDIS_MAX_TOTAL_SIZE"
if base.count(marker) != 0:
    raise SystemExit("merge-base unexpectedly contains the Android bounds check")
if current.count(marker) != 1 or target.count(marker) != 1:
    raise SystemExit("target-equivalent bounds check is not unique")

def canonical_guard(text: str) -> str:
    start = text.index("\tif ((BufLength > RNDIS_MAX_TOTAL_SIZE) ||")
    end = text.index("\n\n", start)
    return re.sub(r"\s+", "", text[start:end])

expected = (
    "if((BufLength>RNDIS_MAX_TOTAL_SIZE)||"
    "(BufOffset>RNDIS_MAX_TOTAL_SIZE)||"
    "(BufOffset+8>=RNDIS_MAX_TOTAL_SIZE))return-EINVAL;"
)
if canonical_guard(current) != expected:
    raise SystemExit("Miru guard is not semantically identical to Android Common")
if canonical_guard(target) != expected:
    raise SystemExit("Android Common guard is not the expected bounds check")

for marker in (
    "void rndis_flow_control(",
    "u32 rndis_get_dl_max_xfer_size(",
    "int rndis_ul_max_pkt_per_xfer_rcvd;",
):
    if current.count(marker) != 1:
        raise SystemExit(f"downstream RNDIS behavior marker missing: {marker}")

print("status=target-equivalent-no-source-delta")
print("merge_base_bounds_check=absent")
print("miru_bounds_check=present")
print("android_bounds_check=present")
print("canonical_guard=" + expected)
print("downstream_rndis_extensions_preserved=yes")
PY

git show "${SCAFFOLD}:${OWNED_PATH}" > "${DIAG}/scaffold-rndis.c"
git show "HEAD:${OWNED_PATH}" > "${DIAG}/head-rndis.c"
cmp "${DIAG}/scaffold-rndis.c" "${DIAG}/head-rndis.c"
sha256sum "${DIAG}/scaffold-rndis.c" "${DIAG}/head-rndis.c" \
  > "${DIAG}/source-identity.sha256"
IDENTITY_SHA="$(sha256sum "${DIAG}/source-identity.sha256" | awk '{print $1}')"
git diff --quiet -- "${OWNED_PATH}"
git diff --check

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file

ANDROID_ROOT="${RUNNER_TEMP}/android-root"
KERNEL_WORKTREE="${ANDROID_ROOT}/kernel/msm-4.14"
VENDOR_SOURCE="${RUNNER_TEMP}/oneplus-sm8150-vendor-source"
OUT_DIR="${ANDROID_ROOT}/out/h40-rndis-targeted"
TOOLCHAIN_ROOT="${RUNNER_TEMP}/miru-toolchains"
rm -rf "${ANDROID_ROOT}" "${VENDOR_SOURCE}" "${TOOLCHAIN_ROOT}"
mkdir -p "${ANDROID_ROOT}/kernel" "${ANDROID_ROOT}/out" "${TOOLCHAIN_ROOT}"
git worktree prune
git worktree add --detach "${KERNEL_WORKTREE}" "${START_HEAD}"

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
grep -Fq 'CONFIG_USB_CONFIGFS_RNDIS=y' "${OUT_DIR}/.config"
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
  echo "target_object=${TARGET_OBJECT}"
  echo "source_delta=none"
  echo "target_bounds_check=retained"
  echo "downstream_rndis_extensions=retained"
  echo "compiler=$("${CLANG}" --version | head -n1)"
} | tee "${DIAG}/targeted-compile-summary.txt"

export LEDGER OWNED_PATH
python3 - <<'PY'
from pathlib import Path
import os

path = Path(os.environ["LEDGER"])
text = path.read_text()
anchor = f"""
### RNDIS no-source-delta ownership anchor

- Owned path: {chr(96)}{os.environ['OWNED_PATH']}{chr(96)}.
- This documentation-only anchor establishes explicit ownership for a target-equivalence validation. No kernel source change is made by this commit.
"""
if "### RNDIS no-source-delta ownership anchor" in text:
    raise SystemExit("RNDIS ownership anchor already exists")
path.write_text(text + anchor)
PY

git config user.name "Miru LTS Integration Bot"
git config user.email "miru-lts-integration@users.noreply.github.com"
git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: establish RNDIS no-source-delta ownership [skip ci]'
OWNERSHIP_COMMIT="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${START_HEAD}"
test "$(git diff-tree --no-commit-id --name-only -r "${OWNERSHIP_COMMIT}")" = "${LEDGER}"

export LEDGER TARGET_RNDIS_COMMIT TARGET_COMMIT SCAFFOLD EXPECTED_SCAFFOLD_BLOB EXPECTED_TARGET_BLOB IDENTITY_SHA OWNERSHIP_COMMIT
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["LEDGER"])
text = path.read_text()
for old, new in {
    "- Semantically resolved conflicts: **24**": "- Semantically resolved conflicts: **25**",
    "- Remaining semantic conflicts: **9**": "- Remaining semantic conflicts: **8**",
}.items():
    if old not in text:
        raise SystemExit(f"missing ledger status: {old}")
    text = text.replace(old, new, 1)

pattern = re.compile(
    r"^(\| 20 \| .*? \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$",
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit("missing unresolved RNDIS manifest row 20")
owner = os.environ["OWNERSHIP_COMMIT"]
replacement = (
    match.group(1) + "resolved" +
    f" | {chr(96)}{owner}{chr(96)} | rndis.o PASS | identity + reversal PASS |"
)
text = text[:match.start()] + replacement + text[match.end():]

bt = chr(96)
record = f"""
### RNDIS set-request bounds equivalence

- Owning no-source-delta validation commit: {bt}{owner}{bt}.
- Owned path: {bt}drivers/usb/gadget/function/rndis.c{bt}.
- Relevant Android Common commit: {bt}{os.environ['TARGET_RNDIS_COMMIT']}{bt}, target-reachable from {bt}{os.environ['TARGET_COMMIT']}{bt}.
- Merge-base behavior: the original stage lacks the {bt}BufOffset > RNDIS_MAX_TOTAL_SIZE{bt} bounds check.
- Android and retained Miru behavior: both contain exactly one canonical guard rejecting an oversize information-buffer offset before response allocation.
- Downstream intent retained: Miru's RNDIS flow-control, negotiated transfer-size, packet aggregation, and locking extensions remain byte-for-byte at scaffold identity.
- Semantic decision: make no whitespace-only source commit. The retained Miru guard is behaviorally identical to Android Common while preserving downstream coding style and all local RNDIS extensions.
- Source identity: scaffold and resolution-head blobs are both {bt}{os.environ['EXPECTED_SCAFFOLD_BLOB']}{bt}; the target blob is {bt}{os.environ['EXPECTED_TARGET_BLOB']}{bt}. Source-identity manifest SHA-256: {bt}{os.environ['IDENTITY_SHA']}{bt}.
- Targeted compilation: **PASS** for {bt}drivers/usb/gadget/function/rndis.o{bt} using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Target-guard equivalence and downstream-extension preservation gates: **PASS**.
- Clean reversal: **PASS**; reverting the validation and ownership documentation commits in reverse order restores the complete pre-resolution integration tree, while the owned RNDIS source path remains exactly at scaffold identity.
- Validation workflow run: {bt}{os.environ.get('GITHUB_RUN_ID', 'unknown')}{bt}.
"""
if "### RNDIS set-request bounds equivalence" in text:
    raise SystemExit("RNDIS equivalence record already exists")
path.write_text(text + record)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record RNDIS target-equivalence validation [skip ci]'
VALIDATION_COMMIT="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${OWNERSHIP_COMMIT}"
test "$(git diff-tree --no-commit-id --name-only -r "${VALIDATION_COMMIT}")" = "${LEDGER}"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-rndis-equivalence-revert"
rm -rf "${REVERT_WORKTREE}"
git worktree add --detach "${REVERT_WORKTREE}" "${VALIDATION_COMMIT}"
git -C "${REVERT_WORKTREE}" config user.name "Miru LTS Integration Bot"
git -C "${REVERT_WORKTREE}" config user.email "miru-lts-integration@users.noreply.github.com"
git -C "${REVERT_WORKTREE}" revert --no-edit "${VALIDATION_COMMIT}" \
  > "${DIAG}/revert-validation.stdout" 2> "${DIAG}/revert-validation.stderr"
git -C "${REVERT_WORKTREE}" revert --no-edit "${OWNERSHIP_COMMIT}" \
  > "${DIAG}/revert-ownership.stdout" 2> "${DIAG}/revert-ownership.stderr"
git -C "${REVERT_WORKTREE}" diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${OWNED_PATH}")" = \
     "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse 'HEAD^{tree}')" = \
     "$(git rev-parse "${START_HEAD}^{tree}")"
{
  echo "result=PASS"
  echo "owning_commit=${OWNERSHIP_COMMIT}"
  echo "validation_commit=${VALIDATION_COMMIT}"
  echo "revert_commit=$(git -C "${REVERT_WORKTREE}" rev-parse HEAD)"
  echo "source_delta=none"
  echo "restored_scaffold=${SCAFFOLD}"
  echo "restored_path=${OWNED_PATH}"
  echo "restored_start_tree=$(git rev-parse "${START_HEAD}^{tree}")"
} | tee "${DIAG}/reversal-summary.txt"

{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "ownership_commit=${OWNERSHIP_COMMIT}"
  echo "documentation_head=${VALIDATION_COMMIT}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=25"
  echo "semantic_conflicts_remaining=8"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${OWNERSHIP_COMMIT}" > "${DIAG}/ownership-commit.txt"
git show --stat --oneline "${VALIDATION_COMMIT}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${VALIDATION_COMMIT}:refs/heads/${INTEGRATION_BRANCH}"
