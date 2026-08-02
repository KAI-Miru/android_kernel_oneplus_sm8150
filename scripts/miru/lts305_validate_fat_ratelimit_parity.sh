#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
TARGET_CHANGE=4b5541035b59dfe77584e7fb5e283c4e00af5a25
DOWNSTREAM_CHANGE=f3dd33108513be195dfa294de94a6e4345698827
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=66fc0f9cbbaa616073f0aa227b541ec45c257d80
PIXEL_SEMANTIC=512d47f08402bf130a78e05a92341d62ae04c120
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
DIAG=lts305-fat-ratelimit-parity
OWNED_PATH=fs/fat/fatent.c
TARGET_OBJECT=fs/fat/fatent.o
EXPECTED_SCAFFOLD_BLOB=a552a9b80d17f2141886bfb80de7010fa58e17e3
EMPTY_PATCH_SHA256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

rm -rf "${DIAG}"
mkdir -p "${DIAG}"
START_HEAD="$(git rev-parse HEAD)"
REMOTE_PRODUCTION="$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')"
REMOTE_INTEGRATION="$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')"
test "${REMOTE_PRODUCTION}" = "${PRODUCTION_SHA}"
test "${REMOTE_INTEGRATION}" = "${START_HEAD}"
git merge-base --is-ancestor "${PRODUCTION_SHA}" "${START_HEAD}"
git merge-base --is-ancestor "${TARGET_COMMIT}" "${START_HEAD}"
git merge-base --is-ancestor "${TARGET_CHANGE}" "${TARGET_COMMIT}"
git merge-base --is-ancestor "${DOWNSTREAM_CHANGE}" "${SCAFFOLD}"
git merge-base --is-ancestor "${SCAFFOLD}" "${START_HEAD}"
git merge-base --is-ancestor "${PREVIOUS_VALIDATED_HEAD}" "${START_HEAD}"
git merge-base --is-ancestor "${PIXEL_SEMANTIC}" "${START_HEAD}"
test "$(git rev-parse "${SCAFFOLD}^1")" = "${SCAFFOLD_PARENT1}"
test "$(git rev-parse "${SCAFFOLD}^2")" = "${TARGET_COMMIT}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305

if grep -Fq '### FAT allocation-table read-error ratelimit parity' "${LEDGER}"; then
  grep -Fq -- '- Semantically resolved conflicts: **12**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **21**' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **11**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **22**' "${LEDGER}"
git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git rev-parse "${SCAFFOLD}:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "HEAD:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"

FAT12_SECTION="$(sed -n '/static int fat12_ent_bread/,/^}/p' "${OWNED_PATH}")"
FAT_SECTION="$(sed -n '/static int fat_ent_bread/,/^}/p' "${OWNED_PATH}")"
test "$(printf '%s\n' "${FAT12_SECTION}" | grep -c 'fat_msg_ratelimit(sb, KERN_ERR')" = 1
test "$(printf '%s\n' "${FAT_SECTION}" | grep -c 'fat_msg_ratelimit(sb, KERN_ERR')" = 1
! printf '%s\n' "${FAT12_SECTION}" | grep -qE '(^|[^_])fat_msg\(sb, KERN_ERR'
! printf '%s\n' "${FAT_SECTION}" | grep -qE '(^|[^_])fat_msg\(sb, KERN_ERR'
{
  echo "result=PASS"
  echo "owned_path=${OWNED_PATH}"
  echo "scaffold_blob=${EXPECTED_SCAFFOLD_BLOB}"
  echo "fat12_read_error_ratelimited=yes"
  echo "fat_read_error_ratelimited=yes"
  echo "source_delta=none"
} | tee "${DIAG}/parity-summary.txt"

git config user.name "Miru LTS Integration Bot"
git config user.email "miru-lts-integration@users.noreply.github.com"
git commit --allow-empty -m 'lts: confirm FAT read-error ratelimit parity for 4.14.305'
SOURCE_COMMIT="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${START_HEAD}"
test "$(git rev-parse "${SOURCE_COMMIT}^{tree}")" = "$(git rev-parse "${START_HEAD}^{tree}")"
test -z "$(git diff-tree --no-commit-id --name-only -r "${SOURCE_COMMIT}")"
ACTUAL_EMPTY_SHA="$(git diff --binary --full-index "${SOURCE_COMMIT}^" "${SOURCE_COMMIT}" | sha256sum | awk '{print $1}')"
test "${ACTUAL_EMPTY_SHA}" = "${EMPTY_PATCH_SHA256}"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file

ANDROID_ROOT="${RUNNER_TEMP}/android-root"
KERNEL_WORKTREE="${ANDROID_ROOT}/kernel/msm-4.14"
VENDOR_SOURCE="${RUNNER_TEMP}/oneplus-sm8150-vendor-source"
OUT_DIR="${ANDROID_ROOT}/out/h40-fat-targeted"
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

WORKTREE_PATH="${KERNEL_WORKTREE}/${OWNED_PATH}"
WORKTREE_FAT12="$(sed -n '/static int fat12_ent_bread/,/^}/p' "${WORKTREE_PATH}")"
WORKTREE_FAT="$(sed -n '/static int fat_ent_bread/,/^}/p' "${WORKTREE_PATH}")"
test "$(printf '%s\n' "${WORKTREE_FAT12}" | grep -c 'fat_msg_ratelimit(sb, KERN_ERR')" = 1
test "$(printf '%s\n' "${WORKTREE_FAT}" | grep -c 'fat_msg_ratelimit(sb, KERN_ERR')" = 1
make -C "${KERNEL_WORKTREE}" -j4 V=0 "${make_args[@]}" "${TARGET_OBJECT}" \
  2>&1 | tee "${DIAG}/targeted-compile.log"
test -s "${OUT_DIR}/${TARGET_OBJECT}"
if grep -nE '(^|[[:space:]])(warning|error):' "${DIAG}/targeted-compile.log" \
    > "${DIAG}/targeted-diagnostics.txt"; then
  cat "${DIAG}/targeted-diagnostics.txt"
  exit 1
else
  : > "${DIAG}/targeted-diagnostics.txt"
fi
{
  echo "result=PASS"
  echo "semantic_commit=${SOURCE_COMMIT}"
  echo "source_tree_identical_to_parent=yes"
  echo "source_delta_sha256=${EMPTY_PATCH_SHA256}"
  echo "vendor_commit=${VENDOR_SHA}"
  echo "targeted_object=${TARGET_OBJECT}"
  echo "compiler=$(${CLANG} --version | head -n1)"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-fat-revert"
rm -rf "${REVERT_WORKTREE}"
git worktree add --detach "${REVERT_WORKTREE}" "${SOURCE_COMMIT}"
git -C "${REVERT_WORKTREE}" config user.name "Miru LTS Integration Bot"
git -C "${REVERT_WORKTREE}" config user.email "miru-lts-integration@users.noreply.github.com"
git -C "${REVERT_WORKTREE}" revert --no-commit "${SOURCE_COMMIT}" \
  > "${DIAG}/revert.stdout" 2> "${DIAG}/revert.stderr"
test -z "$(git -C "${REVERT_WORKTREE}" status --porcelain --untracked-files=no)"
git -C "${REVERT_WORKTREE}" commit --allow-empty \
  -m 'Revert "lts: confirm FAT read-error ratelimit parity for 4.14.305"'
REVERT_COMMIT="$(git -C "${REVERT_WORKTREE}" rev-parse HEAD)"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "${REVERT_COMMIT}^{tree}")" = \
     "$(git rev-parse "${START_HEAD}^{tree}")"
{
  echo "result=PASS"
  echo "owning_commit=${SOURCE_COMMIT}"
  echo "revert_commit=${REVERT_COMMIT}"
  echo "restored_scaffold=${SCAFFOLD}"
  echo "restored_path=${OWNED_PATH}"
  echo "no_source_delta=yes"
} | tee "${DIAG}/reversal-summary.txt"

export SOURCE_COMMIT SCAFFOLD LEDGER EMPTY_PATCH_SHA256
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ['LEDGER'])
text = path.read_text()
for old, new in {
    '- Semantically resolved conflicts: **11**': '- Semantically resolved conflicts: **12**',
    '- Remaining semantic conflicts: **22**': '- Remaining semantic conflicts: **21**',
}.items():
    if old not in text:
        raise SystemExit(f'missing ledger status: {old}')
    text = text.replace(old, new, 1)

source = os.environ['SOURCE_COMMIT']
pattern = re.compile(
    r'^(\| 23 \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$',
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit('missing unresolved FAT manifest row 23')
replacement = (
    match.group(1) + 'resolved' +
    f' | `{source}` | targeted compile PASS | clean reversal PASS |'
)
text = text[:match.start()] + replacement + text[match.end():]

pixel_anchor = '- Validation workflow run: `30241067412`.\n'
pixel_evidence = (
    '- Validation artifact: run `30241067412`, artifact `8643348682`, '
    'digest `sha256:956158e1b997af205636cfe77a71bd01f9f972926984203421396f75a767c31b`, '
    'size `7065` bytes.\n'
)
if pixel_anchor not in text:
    raise SystemExit('missing pixel-clock validation anchor')
if 'artifact `8643348682`' not in text:
    text = text.replace(pixel_anchor, pixel_anchor + pixel_evidence, 1)

record = f'''
### FAT allocation-table read-error ratelimit parity

- Owning semantic commit: `{source}` (empty source commit; tree identical to its parent).
- Owned path: `fs/fat/fatent.c`.
- Relevant Android Common commit: `4b5541035b59dfe77584e7fb5e283c4e00af5a25`.
- Downstream commit retained: `f3dd33108513be195dfa294de94a6e4345698827`.
- Target behavior: both FAT12 boundary-read failure and normal FAT entry-read failure use `fat_msg_ratelimit()` to prevent repeated I/O errors from flooding the kernel log.
- Downstream behavior retained: the Miru scaffold already ratelimits both paths; its owned-path blob is `a552a9b80d17f2141886bfb80de7010fa58e17e3`.
- Semantic decision: **no source delta**. The earlier Qualcomm implementation already contains the complete Android target behavior; formatting differences do not change semantics.
- Canonical source delta SHA-256: `{os.environ['EMPTY_PATCH_SHA256']}` (empty `git diff --binary --full-index`).
- Targeted compilation: **PASS** for `fs/fat/fatent.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Clean reversal: **PASS**; reverting the empty semantic commit preserved the complete integration tree, while the owned path remained byte-identical to scaffold `{os.environ['SCAFFOLD']}`.
- Validation workflow run: `{os.environ.get('GITHUB_RUN_ID', 'unknown')}`.
'''
if '### FAT allocation-table read-error ratelimit parity' in text:
    raise SystemExit('FAT parity record already exists')
text += record
path.write_text(text)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record FAT ratelimit parity validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "semantic_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=12"
  echo "semantic_conflicts_remaining=21"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/semantic-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
