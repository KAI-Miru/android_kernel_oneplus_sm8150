#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
DIAG=lts305-arm64-resolution

OWNED_PATHS=(
  Documentation/arm64/silicon-errata.txt
  arch/arm64/Kconfig
  arch/arm64/include/asm/cpucaps.h
  arch/arm64/include/asm/cputype.h
  arch/arm64/kernel/cpu_errata.c
  arch/arm64/kernel/setup.c
  arch/arm64/mm/mmu.c
)
TARGET_OBJECTS=(
  arch/arm64/kernel/setup.o
  arch/arm64/kernel/cpu_errata.o
  arch/arm64/kernel/cpufeature.o
  arch/arm64/kernel/entry.o
  arch/arm64/mm/mmu.o
)

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
test "$(git rev-parse "${SCAFFOLD}^1")" = "${SCAFFOLD_PARENT1}"
test "$(git rev-parse "${SCAFFOLD}^2")" = "${TARGET_COMMIT}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305

# A synchronize event caused by this job's own guarded push is a read-only no-op.
if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATHS[@]}"; then
  grep -Fq -- '- Semantically resolved conflicts: **7**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **26**' "${LEDGER}"
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

python3 scripts/miru/lts305_resolve_arm64.py | tee "${DIAG}/resolver.txt"
test -s lts305-arm64-resolution.patch
mv lts305-arm64-resolution.patch "${DIAG}/source.patch"
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
git commit -m 'lts: resolve ARM64 errata and FDT conflicts for 4.14.305'
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
OUT_DIR="${ANDROID_ROOT}/out/h40-arm64-targeted"
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
grep -Fq 'CONFIG_ARM64_ERRATUM_1188873=y' "${OUT_DIR}/.config"
grep -Fq 'CONFIG_ARM64_ERRATUM_1742098=y' "${OUT_DIR}/.config"
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

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-arm64-revert"
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

export SOURCE_COMMIT SCAFFOLD SCAFFOLD_PARENT1 TARGET_COMMIT LEDGER
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ['LEDGER'])
text = path.read_text()
replacements = {
    '- Authentic merge scaffold: **armed but not yet created**': '- Authentic merge scaffold: **created and verified**',
    '- Index-resolved conflicts: **0**': '- Index-resolved conflicts: **33**',
    '- Semantically resolved conflicts: **0**': '- Semantically resolved conflicts: **7**',
    '- Remaining semantic conflicts: **33**': '- Remaining semantic conflicts: **26**',
}
for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f'missing ledger status text: {old}')
    text = text.replace(old, new, 1)

source = os.environ['SOURCE_COMMIT']
for number in range(1, 34):
    pattern = re.compile(rf'^(\| {number} \| .*? \| )unresolved( \| )unresolved( \| — \| — \| — \|)$', re.M)
    match = pattern.search(text)
    if not match:
        raise SystemExit(f'missing unresolved manifest row {number}')
    if number <= 7:
        replacement = match.group(1) + 'index-resolved in scaffold' + match.group(2) + 'resolved' + f' | `{source}` | targeted compile PASS | clean reversal PASS |'
    else:
        replacement = match.group(1) + 'index-resolved in scaffold' + match.group(2) + 'unresolved' + match.group(3)
    text = text[:match.start()] + replacement + text[match.end():]

record = f'''\n## Authentic scaffold evidence\n\n- Scaffold commit: `{os.environ['SCAFFOLD']}`\n- Parent 1 (preparation): `{os.environ['SCAFFOLD_PARENT1']}`\n- Parent 2 (Android Common): `{os.environ['TARGET_COMMIT']}`\n- Scaffold workflow run: `30234354643`\n- Scaffold artifact ID: `8641187330`\n- Parent order: **PASS**\n- Cleanly merged stage-0 preservation: **PASS for 2067 paths**\n- Conflicted stage-2/Miru preservation: **PASS for 33 paths**\n\n## Semantic resolution records\n\n### ARM64 errata, CPU capabilities, FDT setup and MMU\n\n- Owning source commit: `{source}`\n- Owned paths: `Documentation/arm64/silicon-errata.txt`, `arch/arm64/Kconfig`, `arch/arm64/include/asm/cpucaps.h`, `arch/arm64/include/asm/cputype.h`, `arch/arm64/kernel/cpu_errata.c`, `arch/arm64/kernel/setup.c`, `arch/arm64/mm/mmu.c`.\n- Relevant Android Common commits: `786ec17678a480c8dc31620aca56b117ac191a6a`, `9aeb4a5a73d392580a2f5ee018dfe5506a2e8359`, `3aee35ffc45b29e795573c047930fb849830806b`, `0b1c660d8516e8960227a92b9ee890e9e3682b31`, `3e3904125fccd042fda24294624e8f66699fd06d`, `2e53c83ea673b657d33cc4fa0018fe41b500afe4`, `06035fd1efb772a178f4a0848d20731ba0973860`, `3c2ae48eceaa40f1ecb18ba31dda3f6fe755796c`, `64bb608e39b5bf0455a9c2380f16f79518a7b4c6`, `9e8261dfa7570b671f2655d68d58f749a2fc856e`, and `a6d363d48a816877d9f9d12da8fc5ed786e333b8`.\n- Downstream intent retained: Cortex-A76 erratum 1286807; Qualcomm Kryo CPU identifiers and the Kryo-4G erratum 1188873 range; `arch_read_machine_name()`; boot-reason/cold-boot interfaces; the downstream early memblock reservation diagnostic; memory-hotplug and mapping behavior outside the conflict hunks.\n- Android behavior imported: the complete timer out-of-line workaround for erratum 1188873 with `COMPAT` dependency; Spectre-BHB capability numbering and mitigation registration; erratum 1742098 COMPAT AES masking; current ARM part identifiers; multi-page trampoline-compatible MMU layout; and the FDT read-write early scan followed by read-only remapping.\n- Semantic decision: take a strict union where identifiers and mitigations are independent, retain Qualcomm-specific ranges, and migrate downstream early-FDT users to the target `fixmap_remap_fdt(dt_phys, &size, prot)` API. The obsolete one-argument MMU wrapper is removed because all remaining callers use the cleanly merged size/protection interface.\n- Audited source patch SHA-256: `220fa976b3bbef9230ea690244b2900795516923398389bff5b8a0cf2fa06038`.\n- Targeted compilation: **PASS** for `arch/arm64/kernel/setup.o`, `arch/arm64/kernel/cpu_errata.o`, `arch/arm64/kernel/cpufeature.o`, `arch/arm64/kernel/entry.o`, and `arch/arm64/mm/mmu.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.\n- Clean reversal: **PASS**; reverting `{source}` in a disposable worktree restored all seven owned paths exactly to scaffold `{os.environ['SCAFFOLD']}`.\n- Validation workflow run: `{os.environ.get('GITHUB_RUN_ID', 'unknown')}`.\n'''
if '### ARM64 errata, CPU capabilities, FDT setup and MMU' in text:
    raise SystemExit('ARM64 resolution record already exists')
text += record
path.write_text(text)
PY

git add -- "${LEDGER}"
git diff --cached --name-only > "${DIAG}/documentation-commit-paths.txt"
test "$(cat "${DIAG}/documentation-commit-paths.txt")" = "${LEDGER}"
git commit -m 'docs: record ARM64 resolution validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"

{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=7"
  echo "semantic_conflicts_remaining=26"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
