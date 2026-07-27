#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=0327bea266ad1b1169a8bf612cc741992f92b7ee
ARM64_SOURCE=8633007f8d97174821bd9f200aa675e50e4bd9f2
CORE_FATAL_SOURCE=6f9a178101753ca7e5dab46d963609d34ea2cc23
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
DIAG=lts305-glink-resolution
OWNED_PATH=drivers/rpmsg/qcom_glink_native.c
TARGET_OBJECT=drivers/rpmsg/qcom_glink_native.o

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
git merge-base --is-ancestor "${ARM64_SOURCE}" "${START_HEAD}"
git merge-base --is-ancestor "${CORE_FATAL_SOURCE}" "${START_HEAD}"
test "$(git rev-parse "${SCAFFOLD}^1")" = "${SCAFFOLD_PARENT1}"
test "$(git rev-parse "${SCAFFOLD}^2")" = "${TARGET_COMMIT}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305
grep -Fq -- '- Semantically resolved conflicts: **9**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **24**' "${LEDGER}"

# The validated documentation push uses [skip ci], but retain an idempotent gate.
if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"; then
  grep -Fq -- '- Semantically resolved conflicts: **10**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **23**' "${LEDGER}"
  grep -Fq '### Qualcomm GLINK channel teardown and RX error propagation' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  exit 0
fi

git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
git config user.name "Miru LTS Integration Bot"
git config user.email "miru-lts-integration@users.noreply.github.com"

python3 scripts/miru/lts305_resolve_glink.py | tee "${DIAG}/resolver.txt"
test -s lts305-glink-resolution.patch
mv lts305-glink-resolution.patch "${DIAG}/source.patch"
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
git commit -m 'lts: resolve Qualcomm GLINK conflict for 4.14.305'
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
OUT_DIR="${ANDROID_ROOT}/out/h40-glink-targeted"
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

GLINK_SOURCE="${KERNEL_WORKTREE}/${OWNED_PATH}"
test "$(grep -c 'strscpy_pad(chinfo.name, channel->name, sizeof(chinfo.name));' "${GLINK_SOURCE}")" = 1
test "$(grep -c 'strlcpy(chinfo.name, channel->name, sizeof(chinfo.name));' "${GLINK_SOURCE}")" = 1
grep -Fq 'qcom_glink_rx_advance(glink, ALIGN(msglen, 8));' "${GLINK_SOURCE}"
grep -Fq 'qcom_glink_rx_advance(glink, ALIGN(sizeof(hdr) + chunk_size, 8));' "${GLINK_SOURCE}"
grep -Fq 'ret = -ENOENT;' "${GLINK_SOURCE}"
intr="$(sed -n '/static irqreturn_t qcom_glink_native_intr/,/\/\* Locally initiated rpmsg_create_ept \*\//p' "${GLINK_SOURCE}")"
! printf '%s\n' "${intr}" | grep -Fq 'if (ret == -ENOENT)'
printf '%s\n' "${intr}" | grep -Fq 'if (ret)'

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
  echo "patch_sha256=${PATCH_SHA}"
  echo "vendor_commit=${VENDOR_SHA}"
  echo "targeted_object=${TARGET_OBJECT}"
  echo "compiler=$(${CLANG} --version | head -n1)"
  echo "protected_glink_gates=PASS"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-glink-revert"
rm -rf "${REVERT_WORKTREE}"
git worktree add --detach "${REVERT_WORKTREE}" "${SOURCE_COMMIT}"
git -C "${REVERT_WORKTREE}" config user.name "Miru LTS Integration Bot"
git -C "${REVERT_WORKTREE}" config user.email "miru-lts-integration@users.noreply.github.com"
git -C "${REVERT_WORKTREE}" revert --no-edit "${SOURCE_COMMIT}" \
  > "${DIAG}/revert.stdout" 2> "${DIAG}/revert.stderr"
git -C "${REVERT_WORKTREE}" diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${OWNED_PATH}")" = \
     "$(git rev-parse "${SCAFFOLD}:${OWNED_PATH}")"
{
  echo "result=PASS"
  echo "owning_commit=${SOURCE_COMMIT}"
  echo "revert_commit=$(git -C "${REVERT_WORKTREE}" rev-parse HEAD)"
  echo "restored_scaffold=${SCAFFOLD}"
  echo "restored_path=${OWNED_PATH}"
} | tee "${DIAG}/reversal-summary.txt"

export SOURCE_COMMIT SCAFFOLD TARGET_COMMIT LEDGER PATCH_SHA
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ['LEDGER'])
text = path.read_text()
for old, new in {
    '- Semantically resolved conflicts: **9**': '- Semantically resolved conflicts: **10**',
    '- Remaining semantic conflicts: **24**': '- Remaining semantic conflicts: **23**',
}.items():
    if old not in text:
        raise SystemExit(f'missing ledger status: {old}')
    text = text.replace(old, new, 1)

source = os.environ['SOURCE_COMMIT']
pattern = re.compile(
    r'^(\| 16 \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$',
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit('missing unresolved GLINK manifest row 16')
replacement = (
    match.group(1) + 'resolved' +
    f' | `{source}` | targeted compile PASS | clean reversal PASS |'
)
text = text[:match.start()] + replacement + text[match.end():]

record = f'''
### Qualcomm GLINK channel teardown and RX error propagation

- Owning source commit: `{source}`
- Owned path: `drivers/rpmsg/qcom_glink_native.c`.
- Relevant Android Common commit: `12faed72cf1a7e32253cb7b839104e03a923cbff` (upstream `766279a8f85df32345dbda03b102ca1ee3d5ddea`).
- Downstream commits retained: `0ba2ae45391418c93ab9af4f7a24acbcfa678a11`, `bdd4cc49080e8a0a56c844600c4e243aa1ad7b97`, and `935b66cf9efbcbd40063e830935744b35a3d5cf`.
- Downstream intent retained: a missing channel intent advances the RX FIFO; a missing local intent drains the current payload before returning `-ENOENT`; and the native interrupt loop propagates all RX errors instead of suppressing `-ENOENT`.
- Android behavior imported: `qcom_glink_rx_close()` now uses `strscpy_pad()` for the fixed-size channel name, preserving NUL termination and the original padding contract without deprecated `strncpy()` semantics.
- Semantic decision: replace only the target-range `qcom_glink_rx_close()` copy. The downstream-only `qcom_glink_rx_close_ack()` teardown remains otherwise unchanged, and all Miru FIFO/error-propagation fixes are source-gated.
- Audited source patch SHA-256: `{os.environ['PATCH_SHA']}` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/rpmsg/qcom_glink_native.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Protected GLINK source gates: **PASS**.
- Clean reversal: **PASS**; reverting `{source}` restored the owned path exactly to scaffold `{os.environ['SCAFFOLD']}`.
- Validation workflow run: `{os.environ.get('GITHUB_RUN_ID', 'unknown')}`.
'''
if '### Qualcomm GLINK channel teardown and RX error propagation' in text:
    raise SystemExit('GLINK resolution record already exists')
text += record
path.write_text(text)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record Qualcomm GLINK resolution validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=10"
  echo "semantic_conflicts_remaining=23"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
