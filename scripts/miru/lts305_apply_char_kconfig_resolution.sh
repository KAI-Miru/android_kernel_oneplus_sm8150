#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_COMMON_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=28253158c851bb5cd0c50c2e1307d4c665ad9586
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
OWNED_PATH=drivers/char/Kconfig
TARGET_OBJECT=drivers/char/random.o
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
EXPECTED_BASE_BLOB=88316f86cc952d7792f7b99f06d43b2168194909
EXPECTED_SCAFFOLD_BLOB=b92228b9851d68c3d75cf5a8525d86a928978c65
EXPECTED_TARGET_BLOB=e329d1cc019ae7e3736d77e83690af17e6db7270
DIAG=lts305-char-kconfig-resolution

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
CPU_FIX="$(awk -F '\t' 'tolower($2) ~ /^random:.*trust.*cpu/ { print $1; exit }' "${DIAG}/target-history.tsv")"
BOOTLOADER_FIX="$(awk -F '\t' 'tolower($2) ~ /^random:.*trust.*bootloader/ { print $1; exit }' "${DIAG}/target-history.tsv")"
test -n "${CPU_FIX}"
test -n "${BOOTLOADER_FIX}"
git merge-base --is-ancestor "${CPU_FIX}" "${TARGET_COMMIT}"
git merge-base --is-ancestor "${BOOTLOADER_FIX}" "${TARGET_COMMIT}"
git show -s --format=fuller "${CPU_FIX}" > "${DIAG}/cpu-trust-upstream.txt"
git show -s --format=fuller "${BOOTLOADER_FIX}" > "${DIAG}/bootloader-trust-upstream.txt"
git show "${TARGET_COMMIT}:${OWNED_PATH}" > "${DIAG}/target-Kconfig"

if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"; then
  grep -Fq -- '- Semantically resolved conflicts: **20**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **13**' "${LEDGER}"
  grep -Fq '### Character-device Kconfig RNG trust union' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **19**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **14**' "${LEDGER}"
git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git rev-parse "${PREVIOUS_COMMON_TARGET}:${OWNED_PATH}")" = "${EXPECTED_BASE_BLOB}"
test "$(git rev-parse "${SCAFFOLD}:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "HEAD:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "${TARGET_COMMIT}:${OWNED_PATH}")" = "${EXPECTED_TARGET_BLOB}"
for marker in \
  'config MSM_SMD_PKT' \
  'source "drivers/char/diag/Kconfig"' \
  'config MSM_FASTCVPD' \
  'config MSM_ADSPRPC' \
  'config VIRTIO_FASTRPC' \
  'config MSM_RDBG' \
  'config OKL4_PIPE' \
  'config VSERVICES_SERIAL_SERVER' \
  'config VSERVICES_SERIAL_CLIENT' \
  'config VSERVICES_VTTY_COUNT'; do
  test "$(grep -Fxc "${marker}" "${OWNED_PATH}")" = 1
done
! grep -Fq 'config RANDOM_TRUST_CPU' "${OWNED_PATH}"
! grep -Fq 'config RANDOM_TRUST_BOOTLOADER' "${OWNED_PATH}"
grep -Fq 'config RANDOM_TRUST_CPU' "${DIAG}/target-Kconfig"
grep -Fq 'config RANDOM_TRUST_BOOTLOADER' "${DIAG}/target-Kconfig"
grep -Fq $'\tdefault y' "${DIAG}/target-Kconfig"
grep -Fq $'\tdepends on ARCH_RANDOM' "${DIAG}/target-Kconfig"

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

for token in ("config RANDOM_TRUST_CPU\n", "config RANDOM_TRUST_BOOTLOADER\n"):
    if target.count(token) != 1:
        raise SystemExit(f"target does not contain exactly one {token.strip()}")
    if token in current:
        raise SystemExit(f"scaffold unexpectedly already contains {token.strip()}")

start = target.index("config RANDOM_TRUST_CPU\n")
end = target.index("endmenu\n", start)
target_block = target[start:end]
if not target_block.endswith("\n\n"):
    raise SystemExit("target RNG block lost its menu separation")
if "depends on ARCH_RANDOM" not in target_block or target_block.count("\tdefault y\n") < 2:
    raise SystemExit("target RNG configuration contract is incomplete")

anchor = "\nendmenu\n\nconfig OKL4_PIPE\n"
if current.count(anchor) != 1:
    raise SystemExit("unexpected Miru character-menu closing anchor")
for marker in (
    'config MSM_SMD_PKT\n',
    'source "drivers/char/diag/Kconfig"\n',
    'config MSM_FASTCVPD\n',
    'config MSM_ADSPRPC\n',
    'config VIRTIO_FASTRPC\n',
    'config MSM_RDBG\n',
    'config VSERVICES_SERIAL_SERVER\n',
    'config VSERVICES_SERIAL_CLIENT\n',
    'config VSERVICES_VTTY_COUNT\n',
):
    if current.count(marker) != 1:
        raise SystemExit(f"missing or duplicated downstream marker: {marker.strip()}")

replacement = "\n" + target_block + "endmenu\n\nconfig OKL4_PIPE\n"
resolved = current.replace(anchor, replacement, 1)
if resolved.replace(replacement, anchor, 1) != current:
    raise SystemExit("resolver did not preserve the complete downstream scaffold")
for token in ("config RANDOM_TRUST_CPU\n", "config RANDOM_TRUST_BOOTLOADER\n"):
    if resolved.count(token) != 1:
        raise SystemExit(f"resolution has incorrect count for {token.strip()}")
if target_block not in resolved:
    raise SystemExit("resolution did not retain the exact Android Common RNG block")

menu_close = resolved.index("\nendmenu\n\nconfig OKL4_PIPE\n")
if not (
    resolved.index("config MSM_RDBG\n") < resolved.index("config RANDOM_TRUST_CPU\n") <
    resolved.index("config RANDOM_TRUST_BOOTLOADER\n") < menu_close <
    resolved.index("config OKL4_PIPE\n") <
    resolved.index("config VSERVICES_SERIAL_SERVER\n")
):
    raise SystemExit("Kconfig menu ownership/order check failed")

owned.write_text(resolved)
print("status=resolved")
print("target_rng_block_sha256=" + hashlib.sha256(target_block.encode()).hexdigest())
print("downstream_scaffold_preserved=yes")
print("menu_ownership=PASS")
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
assert text.count("config RANDOM_TRUST_CPU\n") == 1
assert text.count("config RANDOM_TRUST_BOOTLOADER\n") == 1
assert text.count('source "drivers/char/diag/Kconfig"\n') == 1
assert text.count("config MSM_FASTCVPD\n") == 1
assert text.count("config MSM_ADSPRPC\n") == 1
assert text.count("config VIRTIO_FASTRPC\n") == 1
assert text.count("config MSM_RDBG\n") == 1
assert text.count("config OKL4_PIPE\n") == 1
assert text.count("config VSERVICES_SERIAL_SERVER\n") == 1
assert text.count("config VSERVICES_SERIAL_CLIENT\n") == 1
assert text.count("config VSERVICES_VTTY_COUNT\n") == 1
assert text.index("config MSM_RDBG\n") < text.index("config RANDOM_TRUST_CPU\n")
assert text.index("config RANDOM_TRUST_BOOTLOADER\n") < text.index("\nendmenu\n\nconfig OKL4_PIPE\n")
print("source_behavior_gates=PASS")
PY

git add -- "${OWNED_PATH}"
test "$(git diff --cached --name-only)" = "${OWNED_PATH}"
git commit -m 'lts: resolve character-device Kconfig conflict for 4.14.305'
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
OUT_DIR="${ANDROID_ROOT}/out/h40-char-kconfig-targeted"
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
grep -Fq 'CONFIG_RANDOM_TRUST_BOOTLOADER=y' "${OUT_DIR}/.config"
grep -E '^(CONFIG_RANDOM_TRUST_|# CONFIG_RANDOM_TRUST_|CONFIG_ARCH_RANDOM|# CONFIG_ARCH_RANDOM)' \
  "${OUT_DIR}/.config" > "${DIAG}/rng-trust.config" || true
cp "${OUT_DIR}/.config" "${DIAG}/resolved.config"
make -C "${KERNEL_WORKTREE}" -j4 V=0 "${make_args[@]}" "${TARGET_OBJECT}" \
  2>&1 | tee "${DIAG}/targeted-compile.log"
test -s "${OUT_DIR}/${TARGET_OBJECT}"
nm -a "${OUT_DIR}/${TARGET_OBJECT}" > "${DIAG}/targeted-object-nm.txt"
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
  echo "kconfig_parse=olddefconfig PASS"
  echo "bootloader_default=CONFIG_RANDOM_TRUST_BOOTLOADER=y"
  echo "compiler=$("${CLANG}" --version | head -n1)"
  echo "downstream_character_entries_retained=yes"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-char-kconfig-revert"
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

export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA CPU_FIX BOOTLOADER_FIX TARGET_COMMIT EXPECTED_SCAFFOLD_BLOB EXPECTED_TARGET_BLOB
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["LEDGER"])
text = path.read_text()
for old, new in {
    "- Semantically resolved conflicts: **19**": "- Semantically resolved conflicts: **20**",
    "- Remaining semantic conflicts: **14**": "- Remaining semantic conflicts: **13**",
}.items():
    if old not in text:
        raise SystemExit(f"missing ledger status: {old}")
    text = text.replace(old, new, 1)

source = os.environ["SOURCE_COMMIT"]
pattern = re.compile(
    r"^(\| 8 \| `drivers/char/Kconfig` \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$",
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit("missing unresolved character Kconfig manifest row 8")
replacement = (
    match.group(1) + "resolved" +
    f" | `{source}` | Kconfig + random.o PASS | clean reversal PASS |"
)
text = text[:match.start()] + replacement + text[match.end():]

record = f"""
### Character-device Kconfig RNG trust union

- Owning source commit: `{source}`.
- Owned path: `drivers/char/Kconfig`.
- Relevant Android Common commits: CPU RNG trust configuration `{os.environ['CPU_FIX']}` and bootloader-seed trust configuration `{os.environ['BOOTLOADER_FIX']}`, both target-reachable from `{os.environ['TARGET_COMMIT']}`.
- Android behavior imported: `RANDOM_TRUST_CPU` (conditionally on `ARCH_RANDOM`) and `RANDOM_TRUST_BOOTLOADER`, both defaulting to enabled so trusted early entropy can initialize the RNG under the target's documented policy.
- Downstream intent retained: the SMD packet entry; Qualcomm diagnostic, FASTCVPD, ADSPRPC, Virtio FastRPC and remote-debug entries; and the OKL4/Virtual Services serial configuration remains in its original menu scope after the character-device menu.
- Semantic decision: take an explicit textual union. The exact Android Common RNG block is inserted immediately before Miru's character-device `endmenu`; all downstream entries remain byte-for-byte in their scaffold order, including the `endmenu` boundary before `OKL4_PIPE`.
- Scaffold blob: `{os.environ['EXPECTED_SCAFFOLD_BLOB']}`. Target blob: `{os.environ['EXPECTED_TARGET_BLOB']}`.
- Audited source patch SHA-256: `{os.environ['PATCH_SHA']}` using `git diff --binary --full-index`.
- Kconfig validation: **PASS** via the pinned H.40 stock configuration and `olddefconfig`; `CONFIG_RANDOM_TRUST_BOOTLOADER=y` was selected by the target default.
- Targeted compilation: **PASS** for `drivers/char/random.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Downstream menu-order and target-block identity gates: **PASS**.
- Clean reversal: **PASS**; reverting `{source}` restored `drivers/char/Kconfig` exactly to scaffold `{os.environ['SCAFFOLD']}` and restored the complete pre-resolution integration tree.
- Validation workflow run: `{os.environ.get('GITHUB_RUN_ID', 'unknown')}`.
"""
if "### Character-device Kconfig RNG trust union" in text:
    raise SystemExit("character Kconfig resolution record already exists")
text += record
path.write_text(text)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record character Kconfig validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=20"
  echo "semantic_conflicts_remaining=13"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
