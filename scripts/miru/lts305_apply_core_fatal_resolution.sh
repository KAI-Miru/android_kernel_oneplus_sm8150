#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
ARM64_SOURCE=8633007f8d97174821bd9f200aa675e50e4bd9f2
ARM64_DOC=8ea7246a493e8a59d2e72cdc4d8b73dda9948553
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
DIAG=lts305-core-fatal-resolution

OWNED_PATHS=(kernel/exit.c kernel/panic.c)
TARGET_OBJECTS=(kernel/exit.o kernel/panic.o)

rm -rf "${DIAG}"
mkdir -p "${DIAG}"
START_HEAD="$(git rev-parse HEAD)"
REMOTE_PRODUCTION="$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')"
REMOTE_INTEGRATION="$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')"
test "${REMOTE_PRODUCTION}" = "${PRODUCTION_SHA}"
test "${REMOTE_INTEGRATION}" = "${START_HEAD}"
git merge-base --is-ancestor "${PRODUCTION_SHA}" "${START_HEAD}"
git merge-base --is-ancestor "${SCAFFOLD}" "${START_HEAD}"
git merge-base --is-ancestor "${TARGET_COMMIT}" "${START_HEAD}"
git merge-base --is-ancestor "${ARM64_SOURCE}" "${START_HEAD}"
git merge-base --is-ancestor "${ARM64_DOC}" "${START_HEAD}"
test "$(git rev-parse "${SCAFFOLD}^1")" = "${SCAFFOLD_PARENT1}"
test "$(git rev-parse "${SCAFFOLD}^2")" = "${TARGET_COMMIT}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305
grep -Fq -- '- Semantically resolved conflicts: **7**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **26**' "${LEDGER}"

# A push caused by the validated result is a read-only no-op.
if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATHS[@]}"; then
  grep -Fq -- '- Semantically resolved conflicts: **9**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **24**' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  exit 0
fi
for path in "${OWNED_PATHS[@]}"; do
  git diff --quiet "${SCAFFOLD}" -- "${path}"
done

git config user.name "Miru LTS Integration Bot"
git config user.email "miru-lts-integration@users.noreply.github.com"
python3 scripts/miru/lts305_resolve_core_fatal.py | tee "${DIAG}/resolver.txt"
test -s lts305-core-fatal.patch
mv lts305-core-fatal.patch "${DIAG}/source.patch"
git diff --check
if git grep -nE '^(<<<<<<< .+|>>>>>>> .+|\|\|\|\|\|\|\| .+)$' -- "${OWNED_PATHS[@]}" \
    > "${DIAG}/conflict-markers.txt"; then
  cat "${DIAG}/conflict-markers.txt"
  exit 1
else
  : > "${DIAG}/conflict-markers.txt"
fi

git add -- "${OWNED_PATHS[@]}"
git diff --cached --name-only | LC_ALL=C sort > "${DIAG}/source-commit-paths.txt"
printf '%s\n' "${OWNED_PATHS[@]}" | LC_ALL=C sort > "${DIAG}/expected-source-paths.txt"
diff -u "${DIAG}/expected-source-paths.txt" "${DIAG}/source-commit-paths.txt"
git commit -m 'lts: resolve exit and panic conflicts for 4.14.305'
SOURCE_COMMIT="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${START_HEAD}"
git diff-tree --no-commit-id --name-only -r "${SOURCE_COMMIT}" | LC_ALL=C sort \
  > "${DIAG}/committed-source-paths.txt"
diff -u "${DIAG}/expected-source-paths.txt" "${DIAG}/committed-source-paths.txt"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file

ANDROID_ROOT="${RUNNER_TEMP}/android-root"
KERNEL_WORKTREE="${ANDROID_ROOT}/kernel/msm-4.14"
VENDOR_SOURCE="${RUNNER_TEMP}/oneplus-sm8150-vendor-source"
OUT_DIR="${ANDROID_ROOT}/out/h40-core-fatal-targeted"
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
make -C "${KERNEL_WORKTREE}" -j4 V=0 "${make_args[@]}" "${TARGET_OBJECTS[@]}" \
  2>&1 | tee "${DIAG}/targeted-compile.log"
for object in "${TARGET_OBJECTS[@]}"; do
  test -s "${OUT_DIR}/${object}"
done
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
  echo "vendor_commit=${VENDOR_SHA}"
  echo "targeted_objects=${TARGET_OBJECTS[*]}"
  echo "compiler=$(${CLANG} --version | head -n1)"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-core-fatal-revert"
rm -rf "${REVERT_WORKTREE}"
git worktree add --detach "${REVERT_WORKTREE}" "${SOURCE_COMMIT}"
git -C "${REVERT_WORKTREE}" config user.name "Miru LTS Integration Bot"
git -C "${REVERT_WORKTREE}" config user.email "miru-lts-integration@users.noreply.github.com"
git -C "${REVERT_WORKTREE}" revert --no-edit "${SOURCE_COMMIT}" \
  > "${DIAG}/revert.stdout" 2> "${DIAG}/revert.stderr"
git -C "${REVERT_WORKTREE}" diff --quiet "${SCAFFOLD}" -- "${OWNED_PATHS[@]}"
for path in "${OWNED_PATHS[@]}"; do
  test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${path}")" = \
       "$(git rev-parse "${SCAFFOLD}:${path}")"
done
{
  echo "result=PASS"
  echo "owning_commit=${SOURCE_COMMIT}"
  echo "revert_commit=$(git -C "${REVERT_WORKTREE}" rev-parse HEAD)"
  echo "restored_scaffold=${SCAFFOLD}"
  echo "restored_path_count=${#OWNED_PATHS[@]}"
} | tee "${DIAG}/reversal-summary.txt"

export SOURCE_COMMIT SCAFFOLD TARGET_COMMIT LEDGER
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ['LEDGER'])
text = path.read_text()
for old, new in {
    '- Semantically resolved conflicts: **7**': '- Semantically resolved conflicts: **9**',
    '- Remaining semantic conflicts: **26**': '- Remaining semantic conflicts: **24**',
}.items():
    if old not in text:
        raise SystemExit(f'missing ledger status: {old}')
    text = text.replace(old, new, 1)

old_hash = '220fa976b3bbef9230ea690244b2900795516923398389bff5b8a0cf2fa06038'
new_hash = '9e81960bc6b5eff4b6ac9fa108f5ae96a3d22e862cfaa62bbc097746d440f2c6'
if old_hash not in text:
    raise SystemExit('missing pre-canonical ARM64 patch hash')
text = text.replace(old_hash, new_hash, 1)

source = os.environ['SOURCE_COMMIT']
for number in (27, 28):
    pattern = re.compile(
        rf'^(\| {number} \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$',
        re.M,
    )
    match = pattern.search(text)
    if not match:
        raise SystemExit(f'missing unresolved manifest row {number}')
    replacement = (
        match.group(1) + 'resolved' +
        f' | `{source}` | targeted compile PASS | clean reversal PASS |'
    )
    text = text[:match.start()] + replacement + text[match.end():]

arm64_evidence = '''
- Validation artifact: run `30237605611`, artifact `8642205498`, digest `sha256:afae78d8aaed42e59eb08d92362b7f8740f609e9ce4903f85ce3e639c09b26f2`, size `20433` bytes.
- Canonical patch serialization: `git diff --binary --full-index`; artifact patch SHA-256 `9e81960bc6b5eff4b6ac9fa108f5ae96a3d22e862cfaa62bbc097746d440f2c6`.
'''
anchor = '- Validation workflow run: `30237605611`.\n'
if anchor not in text:
    raise SystemExit('missing ARM64 validation anchor')
if 'artifact `8642205498`' not in text:
    text = text.replace(anchor, anchor + arm64_evidence, 1)

record = f'''
### Task-exit and panic/warn hardening

- Owning source commit: `{source}`
- Owned paths: `kernel/exit.c`, `kernel/panic.c`.
- Relevant Android Common commits: `5eded74b4928860a7d75928c4842b103e02c0853`, `53aca559a2a58025012ea2d9ff69259a0ae582b2`, `784bf591aebdf26e3b08c03a48d6b91dd052e83b`, `2ba1ec154608abb51c4b588542f903ca51db6fe7`, `4ba2f65e6f48e08d8888efb2c14be1f315ee25e6`, `3bd9e479d3bd1a11a5b4f640627413ef6c0db30a`, `a83bcc5fc4e93b76d225981d83d22dbfe353dbd8`, `f86706f4580f141e5ad7812559cbd03b4618f9f1`, and `11bece14153cd05b9e823d6452f2483003150d0a`.
- Downstream intent retained: virtual-reserve-memory task-exit integration; Qualcomm minidump and panic tracepoints; panic-time device-cache flush; download-mode gating; and OPlus aging-test dump-reason persistence.
- Android behavior imported: `make_task_dead()`, bounded oops and warning counters, disable-able `oops_limit`, `warn_limit`, sysctl/sysfs exposure, `READ_ONCE()` limit reads, consolidated `check_panic_on_warn()`, and panic-path reset of `panic_on_warn`.
- Semantic decision: strict union of independent platform diagnostics with the upstream repeated-oops/repeated-warning hardening. The generic counters and limits do not replace or bypass Miru crash collection.
- Audited source patch SHA-256: `daaae4d64d68d18986a067785e83ab3391ffdb714b8fc8a9710c385b5eb8a034` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `kernel/exit.o` and `kernel/panic.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Clean reversal: **PASS**; reverting `{source}` restored both owned paths exactly to scaffold `{os.environ['SCAFFOLD']}`.
- Validation workflow run: `{os.environ.get('GITHUB_RUN_ID', 'unknown')}`.
'''
if '### Task-exit and panic/warn hardening' in text:
    raise SystemExit('core fatal-path record already exists')
text += record
path.write_text(text)
PY

git add -- "${LEDGER}"
git diff --cached --name-only > "${DIAG}/documentation-commit-paths.txt"
test "$(cat "${DIAG}/documentation-commit-paths.txt")" = "${LEDGER}"
git commit -m 'docs: record exit and panic resolution validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=9"
  echo "semantic_conflicts_remaining=24"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
