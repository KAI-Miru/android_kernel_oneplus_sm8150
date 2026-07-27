#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
UPSTREAM_FIX=bca1a1004615efe141fd78f360ecc48c60bc4ad5
TARGET_SUBJECT='mailbox: forward the hrtimer if not queued and under a lock'
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=ac2ed52f37c6d67d2bf0c55639f15e59eb6b1d31
EDAC_SOURCE=e5e15c01d846b479836c7c8625c98794e9094302
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
DIAG=lts305-mailbox-resolution
OWNED_PATH=drivers/mailbox/mailbox.c
HEADER_PATH=include/linux/mailbox_controller.h
TARGET_OBJECT=drivers/mailbox/mailbox.o
EXPECTED_HEADER_BLOB=4868590fa0d52c9307f6afc9607b75720a1c063e

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
git merge-base --is-ancestor "${EDAC_SOURCE}" "${START_HEAD}"
test "$(git rev-parse "${SCAFFOLD}^1")" = "${SCAFFOLD_PARENT1}"
test "$(git rev-parse "${SCAFFOLD}^2")" = "${TARGET_COMMIT}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305

mapfile -t TARGET_FIXES < <(
  git log --full-history --format='%H%x09%s' "${TARGET_COMMIT}" -- "${OWNED_PATH}" |
    awk -F '\t' -v subject="${TARGET_SUBJECT}" '$2 == subject {print $1}'
)
test "${#TARGET_FIXES[@]}" -eq 1
TARGET_FIX="${TARGET_FIXES[0]}"
git merge-base --is-ancestor "${TARGET_FIX}" "${TARGET_COMMIT}"
git show --format=fuller --stat "${TARGET_FIX}" > "${DIAG}/target-fix.txt"
git show --format= -- "${TARGET_FIX}" -- "${OWNED_PATH}" "${HEADER_PATH}" \
  > "${DIAG}/target-fix.patch"
grep -Fq 'poll_hrt_lock' "${DIAG}/target-fix.patch"
grep -Fq 'hrtimer_is_queued' "${DIAG}/target-fix.patch"
{
  echo "target_fix=${TARGET_FIX}"
  echo "upstream_fix=${UPSTREAM_FIX}"
  echo "subject=${TARGET_SUBJECT}"
} | tee "${DIAG}/target-history-summary.txt"

if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"; then
  grep -Fq -- '- Semantically resolved conflicts: **14**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **19**' "${LEDGER}"
  grep -Fq '### Mailbox polling hrtimer serialization' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **13**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **20**' "${LEDGER}"
git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git rev-parse "${SCAFFOLD}:${HEADER_PATH}")" = "${EXPECTED_HEADER_BLOB}"
test "$(git rev-parse "HEAD:${HEADER_PATH}")" = "${EXPECTED_HEADER_BLOB}"

git config user.name "Miru LTS Integration Bot"
git config user.email "miru-lts-integration@users.noreply.github.com"
python3 scripts/miru/lts305_resolve_mailbox.py | tee "${DIAG}/resolver.txt"
test -s lts305-mailbox-resolution.patch
mv lts305-mailbox-resolution.patch "${DIAG}/source.patch"
PATCH_SHA="$(sha256sum "${DIAG}/source.patch" | awk '{print $1}')"
git diff --check
if git grep -nE '^(<<<<<<< .+|>>>>>>> .+|\|\|\|\|\|\|\| .+)$' -- "${OWNED_PATH}" \
    > "${DIAG}/conflict-markers.txt"; then
  cat "${DIAG}/conflict-markers.txt"
  exit 1
else
  : > "${DIAG}/conflict-markers.txt"
fi

git add -- "${OWNED_PATH}"
test "$(git diff --cached --name-only)" = "${OWNED_PATH}"
git commit -m 'lts: resolve mailbox polling timer conflict for 4.14.305'
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
OUT_DIR="${ANDROID_ROOT}/out/h40-mailbox-targeted"
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

MAILBOX_SOURCE="${KERNEL_WORKTREE}/${OWNED_PATH}"
MAILBOX_HEADER="${KERNEL_WORKTREE}/${HEADER_PATH}"
test "$(git -C "${KERNEL_WORKTREE}" rev-parse "HEAD:${HEADER_PATH}")" = "${EXPECTED_HEADER_BLOB}"
grep -Fq 'spinlock_t poll_hrt_lock;' "${MAILBOX_HEADER}"
grep -Fq 'static int __msg_submit(struct mbox_chan *chan)' "${MAILBOX_SOURCE}"
grep -Fq '} while (err == -EAGAIN);' "${MAILBOX_SOURCE}"
! grep -Fq 'hrtimer_active(&chan->mbox->poll_hrt)' "${MAILBOX_SOURCE}"
test "$(grep -c 'spin_lock_irqsave(&chan->mbox->poll_hrt_lock, flags);' "${MAILBOX_SOURCE}")" = 1
test "$(grep -c 'spin_lock_irqsave(&mbox->poll_hrt_lock, flags);' "${MAILBOX_SOURCE}")" = 1
test "$(grep -c 'spin_lock_init(&mbox->poll_hrt_lock);' "${MAILBOX_SOURCE}")" = 1
test "$(grep -c 'if (!hrtimer_is_queued(hrtimer))' "${MAILBOX_SOURCE}")" = 1
test "$(grep -c 'resched = true;' "${MAILBOX_SOURCE}")" = 1

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
  echo "source_commit=${SOURCE_COMMIT}"
  echo "target_fix=${TARGET_FIX}"
  echo "upstream_fix=${UPSTREAM_FIX}"
  echo "patch_sha256=${PATCH_SHA}"
  echo "vendor_commit=${VENDOR_SHA}"
  echo "targeted_object=${TARGET_OBJECT}"
  echo "compiler=$(${CLANG} --version | head -n1)"
  echo "downstream_eagain_retry_retained=yes"
  echo "poll_timer_serialization_imported=yes"
  echo "clean_header_lock_retained=yes"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-mailbox-revert"
rm -rf "${REVERT_WORKTREE}"
git worktree add --detach "${REVERT_WORKTREE}" "${SOURCE_COMMIT}"
git -C "${REVERT_WORKTREE}" config user.name "Miru LTS Integration Bot"
git -C "${REVERT_WORKTREE}" config user.email "miru-lts-integration@users.noreply.github.com"
git -C "${REVERT_WORKTREE}" revert --no-edit "${SOURCE_COMMIT}" \
  > "${DIAG}/revert.stdout" 2> "${DIAG}/revert.stderr"
git -C "${REVERT_WORKTREE}" diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${OWNED_PATH}")" = \
     "$(git rev-parse "${SCAFFOLD}:${OWNED_PATH}")"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${HEADER_PATH}")" = \
     "${EXPECTED_HEADER_BLOB}"
{
  echo "result=PASS"
  echo "owning_commit=${SOURCE_COMMIT}"
  echo "revert_commit=$(git -C "${REVERT_WORKTREE}" rev-parse HEAD)"
  echo "restored_scaffold=${SCAFFOLD}"
  echo "restored_path=${OWNED_PATH}"
  echo "header_blob=${EXPECTED_HEADER_BLOB}"
} | tee "${DIAG}/reversal-summary.txt"

export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA TARGET_FIX UPSTREAM_FIX
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ['LEDGER'])
text = path.read_text()
for old, new in {
    '- Semantically resolved conflicts: **13**': '- Semantically resolved conflicts: **14**',
    '- Remaining semantic conflicts: **20**': '- Remaining semantic conflicts: **19**',
}.items():
    if old not in text:
        raise SystemExit(f'missing ledger status: {old}')
    text = text.replace(old, new, 1)

source = os.environ['SOURCE_COMMIT']
pattern = re.compile(
    r'^(\| 11 \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$',
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit('missing unresolved mailbox manifest row 11')
replacement = (
    match.group(1) + 'resolved' +
    f' | `{source}` | targeted compile PASS | clean reversal PASS |'
)
text = text[:match.start()] + replacement + text[match.end():]

edac_anchor = '- Validation workflow run: `30242138170`.\n'
edac_evidence = (
    '- Validation artifact: run `30242138170`, artifact `8643726041`, '
    'digest `sha256:88f9eed2aff39e90a5c0449315d622c004377d2a9f784b4bb921e923d46ec957`, '
    'size `8793` bytes.\n'
)
if edac_anchor not in text:
    raise SystemExit('missing EDAC validation anchor')
if 'artifact `8643726041`' not in text:
    text = text.replace(edac_anchor, edac_anchor + edac_evidence, 1)

record = f'''
### Mailbox polling hrtimer serialization

- Owning source commit: `{source}`.
- Owned path: `drivers/mailbox/mailbox.c`.
- Cleanly merged dependency: `include/linux/mailbox_controller.h` already contains `poll_hrt_lock`; scaffold blob `4868590fa0d52c9307f6afc9607b75720a1c063e` was preserved unchanged.
- Relevant Android Common commit: `{os.environ['TARGET_FIX']}` (upstream `{os.environ['UPSTREAM_FIX']}`).
- Downstream behavior retained: Miru's split `__msg_submit()` helper and the retry loop for controller `-EAGAIN` responses remain intact.
- Android behavior imported: polling-timer starts and forwards are serialized with `poll_hrt_lock`; the timer is forwarded only when it is not already queued; and rescheduling is requested only when an active transfer remains incomplete.
- Semantic decision: apply the upstream timer-race fix around the downstream retrying submission path rather than replacing that path with the target's single-attempt implementation.
- Audited source patch SHA-256: `{os.environ['PATCH_SHA']}` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/mailbox/mailbox.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Mailbox source-behavior and clean-header gates: **PASS**.
- Clean reversal: **PASS**; reverting `{source}` restored the owned path exactly to scaffold `{os.environ['SCAFFOLD']}` while preserving the cleanly merged header blob.
- Validation workflow run: `{os.environ.get('GITHUB_RUN_ID', 'unknown')}`.
'''
if '### Mailbox polling hrtimer serialization' in text:
    raise SystemExit('mailbox resolution record already exists')
text += record
path.write_text(text)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record mailbox resolution validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=14"
  echo "semantic_conflicts_remaining=19"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
