#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_COMMON_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=d7e01e67e002a2784f95f90ab095323f0ae25e66
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
OWNED_PATH=lib/Makefile
# Top-level Kbuild exposes the lib directory as a build goal; its archive is
# produced beneath that goal but is not itself a top-level make target.
TARGET_GOAL=lib
TARGET_BUILTIN=lib/built-in.o
CRYPTO_BUILTIN=lib/crypto/built-in.o
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
EXPECTED_BASE_BLOB=e16cd469e5f379e9d18d8aa489d9082bbf24c762
EXPECTED_SCAFFOLD_BLOB=f5125f285da3e82072c127cfe250abaadf5676e9
EXPECTED_TARGET_BLOB=4e3ae6a42dc38c57dc72a4d01d6ea797a14433ab
EXPECTED_CRYPTO_MAKEFILE_BLOB=d0bca68618f034c3b897a7604f11e4da41975395
DIAG=lts305-lib-makefile-resolution

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
TARGET_CRYPTO_FIX=
while IFS=$'\t' read -r sha subject; do
  if git show --format= "${sha}" -- "${OWNED_PATH}" | grep -Fxq '+obj-y += crypto/'; then
    TARGET_CRYPTO_FIX="${sha}"
    break
  fi
done < "${DIAG}/target-history.tsv"
test -n "${TARGET_CRYPTO_FIX}"
git merge-base --is-ancestor "${TARGET_CRYPTO_FIX}" "${TARGET_COMMIT}"
git show -s --format=fuller "${TARGET_CRYPTO_FIX}" > "${DIAG}/target-crypto-upstream.txt"
git show "${TARGET_COMMIT}:${OWNED_PATH}" > "${DIAG}/target-Makefile"

if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"; then
  grep -Fq -- '- Semantically resolved conflicts: **21**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **12**' "${LEDGER}"
  grep -Fq '### Library Makefile crypto and Miru instrumentation union' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **20**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **13**' "${LEDGER}"
git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git rev-parse "${PREVIOUS_COMMON_TARGET}:${OWNED_PATH}")" = "${EXPECTED_BASE_BLOB}"
test "$(git rev-parse "${SCAFFOLD}:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "HEAD:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "${TARGET_COMMIT}:${OWNED_PATH}")" = "${EXPECTED_TARGET_BLOB}"
test "$(git rev-parse "${SCAFFOLD}:lib/crypto/Makefile")" = "${EXPECTED_CRYPTO_MAKEFILE_BLOB}"
test "$(git rev-parse "HEAD:lib/crypto/Makefile")" = "${EXPECTED_CRYPTO_MAKEFILE_BLOB}"
test "$(git rev-parse "${TARGET_COMMIT}:lib/crypto/Makefile")" = "${EXPECTED_CRYPTO_MAKEFILE_BLOB}"
for marker in \
  'KASAN_SANITIZE_find_bit.o := n' \
  '# ifdef OPLUS_FEATURE_MEMLEAK_DETECT' \
  'obj-$(CONFIG_VMALLOC_DEBUG) += memleak_debug_stackdepot.o' \
  '# endif'; do
  test "$(grep -Fxc "${marker}" "${OWNED_PATH}")" = 1
done
! grep -Fq 'obj-y += crypto/' "${OWNED_PATH}"
test "$(grep -Fxc 'obj-y += crypto/' "${DIAG}/target-Makefile")" = 1

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

target_line = "obj-y += crypto/\n"
if target.count(target_line) != 1:
    raise SystemExit("target does not contain exactly one crypto subdirectory line")
if target_line in current:
    raise SystemExit("scaffold unexpectedly already contains crypto subdirectory line")
anchor = "obj-$(CONFIG_PARMAN) += parman.o\n"
if current.count(anchor) != 1:
    raise SystemExit("unexpected parman anchor")
for marker in (
    'KASAN_SANITIZE_find_bit.o := n\n',
    '# ifdef OPLUS_FEATURE_MEMLEAK_DETECT\n',
    'obj-$(CONFIG_VMALLOC_DEBUG) += memleak_debug_stackdepot.o\n',
    '# endif\n',
):
    if current.count(marker) != 1:
        raise SystemExit(f"missing or duplicated downstream marker: {marker.strip()}")

replacement = anchor + "\n" + target_line
resolved = current.replace(anchor, replacement, 1)
if resolved.replace(replacement, anchor, 1) != current:
    raise SystemExit("resolver did not preserve the complete downstream scaffold")
if resolved.count(target_line) != 1:
    raise SystemExit("resolution has incorrect crypto subdirectory count")
if not (
    resolved.index(anchor) < resolved.index(target_line) <
    resolved.index('# ifdef OPLUS_FEATURE_MEMLEAK_DETECT\n')
):
    raise SystemExit("Makefile ordering check failed")

owned.write_text(resolved)
print("status=resolved")
print("target_crypto_line_sha256=" + hashlib.sha256(target_line.encode()).hexdigest())
print("downstream_scaffold_preserved=yes")
print("makefile_order=PASS")
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
assert text.count("obj-y += crypto/\n") == 1
assert text.count("KASAN_SANITIZE_find_bit.o := n\n") == 1
assert text.count("# ifdef OPLUS_FEATURE_MEMLEAK_DETECT\n") == 1
assert text.count("obj-$(CONFIG_VMALLOC_DEBUG) += memleak_debug_stackdepot.o\n") == 1
assert text.count("# endif\n") == 1
assert text.index("obj-$(CONFIG_PARMAN) += parman.o\n") < text.index("obj-y += crypto/\n")
assert text.index("obj-y += crypto/\n") < text.index("# ifdef OPLUS_FEATURE_MEMLEAK_DETECT\n")
print("source_behavior_gates=PASS")
PY

git add -- "${OWNED_PATH}"
test "$(git diff --cached --name-only)" = "${OWNED_PATH}"
git commit -m 'lts: resolve library Makefile conflict for 4.14.305'
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
OUT_DIR="${ANDROID_ROOT}/out/h40-lib-makefile-targeted"
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
cp "${OUT_DIR}/.config" "${DIAG}/resolved.config"
make -C "${KERNEL_WORKTREE}" -j4 V=0 "${make_args[@]}" "${TARGET_GOAL}" drivers/char/random.o \
  2>&1 | tee "${DIAG}/targeted-compile.log"
test -s "${OUT_DIR}/${TARGET_BUILTIN}"
test -s "${OUT_DIR}/lib/crypto/libblake2s.o"
test -s "${OUT_DIR}/${CRYPTO_BUILTIN}"
test -s "${OUT_DIR}/drivers/char/random.o"
ar t "${OUT_DIR}/lib/crypto/libblake2s.o" > "${DIAG}/libblake2s-members.txt"
ar t "${OUT_DIR}/${CRYPTO_BUILTIN}" > "${DIAG}/crypto-built-in-members.txt"
for members in "${DIAG}/libblake2s-members.txt" "${DIAG}/crypto-built-in-members.txt"; do
  grep -Eq '(^|/)blake2s[.]o$' "${members}"
  grep -Eq '(^|/)blake2s-generic[.]o$' "${members}"
done
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
  echo "target_goal=${TARGET_GOAL}"
  echo "target_builtin=${TARGET_BUILTIN}"
  echo "crypto_builtin=${CRYPTO_BUILTIN}"
  echo "blake2s_members=blake2s.o,blake2s-generic.o"
  echo "makefile_parse=olddefconfig PASS"
  echo "crypto_subdirectory_built=yes"
  echo "independent_consumer_object=drivers/char/random.o"
  echo "compiler=$("${CLANG}" --version | head -n1)"
  echo "downstream_instrumentation_retained=yes"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-lib-makefile-revert"
rm -rf "${REVERT_WORKTREE}"
git worktree add --detach "${REVERT_WORKTREE}" "${SOURCE_COMMIT}"
git -C "${REVERT_WORKTREE}" config user.name "Miru LTS Integration Bot"
git -C "${REVERT_WORKTREE}" config user.email "miru-lts-integration@users.noreply.github.com"
git -C "${REVERT_WORKTREE}" revert --no-edit "${SOURCE_COMMIT}" \
  > "${DIAG}/revert.stdout" 2> "${DIAG}/revert.stderr"
git -C "${REVERT_WORKTREE}" diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${OWNED_PATH}")" = \
     "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:lib/crypto/Makefile")" = \
     "${EXPECTED_CRYPTO_MAKEFILE_BLOB}"
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

export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA TARGET_CRYPTO_FIX TARGET_COMMIT EXPECTED_SCAFFOLD_BLOB EXPECTED_TARGET_BLOB EXPECTED_CRYPTO_MAKEFILE_BLOB
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["LEDGER"])
text = path.read_text()
for old, new in {
    "- Semantically resolved conflicts: **20**": "- Semantically resolved conflicts: **21**",
    "- Remaining semantic conflicts: **13**": "- Remaining semantic conflicts: **12**",
}.items():
    if old not in text:
        raise SystemExit(f"missing ledger status: {old}")
    text = text.replace(old, new, 1)

source = os.environ["SOURCE_COMMIT"]
pattern = re.compile(
    r"^(\| 29 \| `lib/Makefile` \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$",
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit("missing unresolved library Makefile manifest row 29")
replacement = (
    match.group(1) + "resolved" +
    f" | `{source}` | lib archive PASS | clean reversal PASS |"
)
text = text[:match.start()] + replacement + text[match.end():]

record = f"""
### Library Makefile crypto and Miru instrumentation union

- Owning source commit: `{source}`.
- Owned path: `lib/Makefile`.
- Relevant Android Common commit: `{os.environ['TARGET_CRYPTO_FIX']}`, target-reachable from `{os.environ['TARGET_COMMIT']}`.
- Android behavior imported: add the cleanly merged `lib/crypto/` directory to the parent library build so its BLAKE2s implementation is linked into the kernel.
- Downstream intent retained: `KASAN_SANITIZE_find_bit.o := n` and the OPlus VMALLOC-debug stack-depot object under its original preprocessor guard.
- Semantic decision: take an explicit three-way union. Insert only `obj-y += crypto/` after the common `PARMAN` entry; preserve all Miru instrumentation lines byte-for-byte and retain the cleanly merged `lib/crypto/Makefile` blob.
- Scaffold blob: `{os.environ['EXPECTED_SCAFFOLD_BLOB']}`. Target blob: `{os.environ['EXPECTED_TARGET_BLOB']}`. Clean crypto Makefile blob: `{os.environ['EXPECTED_CRYPTO_MAKEFILE_BLOB']}`.
- Audited source patch SHA-256: `{os.environ['PATCH_SHA']}` using `git diff --binary --full-index`.
- Build-graph validation: **PASS** via the pinned H.40 stock configuration and `lib/built-in.o`; the crypto child archive and `libblake2s.o` were produced.
- Consumer compilation: **PASS** for `drivers/char/random.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Downstream instrumentation and crypto-directory identity gates: **PASS**.
- Clean reversal: **PASS**; reverting `{source}` restored `lib/Makefile` exactly to scaffold `{os.environ['SCAFFOLD']}`, preserved the clean crypto Makefile blob and restored the complete pre-resolution integration tree.
- Validation workflow run: `{os.environ.get('GITHUB_RUN_ID', 'unknown')}`.
"""
if "### Library Makefile crypto and Miru instrumentation union" in text:
    raise SystemExit("library Makefile resolution record already exists")
text += record
path.write_text(text)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record library Makefile validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=21"
  echo "semantic_conflicts_remaining=12"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
