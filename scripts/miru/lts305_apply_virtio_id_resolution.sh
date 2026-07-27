#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=d12a051223927d4cfe845af6a4283ada8d30f2c1
STMMAC_SOURCE=0c2edde500e6c8f9c88e593c94731cdb6fe49cc5
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
DIAG=lts305-virtio-id-resolution

TARGET_FIX=d2c7910f5f1bb26e5af00ee3cc182d0c35b2b2a5
UPSTREAM_FIX=f5a37f36fd0fad8451b1a6dddd5cd1b5fac4704e
OWNED_PATH=include/uapi/linux/virtio_ids.h
CONSUMER_PATH=drivers/net/wireless/mac80211_hwsim.c
TARGET_OBJECT=drivers/net/wireless/mac80211_hwsim.o
EXPECTED_SCAFFOLD_BLOB=635a83616794605581949e77624f216a3212e295
EXPECTED_TARGET_BLOB=2daccbb95f158ed757f1fc27924bec5c498ac3f6
EXPECTED_CONSUMER_BLOB=39642c510d7740d54e4f6fd7287a631c6734d3e6

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
git merge-base --is-ancestor "${STMMAC_SOURCE}" "${START_HEAD}"
test "$(git rev-parse "${SCAFFOLD}^1")" = "${SCAFFOLD_PARENT1}"
test "$(git rev-parse "${SCAFFOLD}^2")" = "${TARGET_COMMIT}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305

git merge-base --is-ancestor "${TARGET_FIX}" "${TARGET_COMMIT}"
git show -s --format=%B "${TARGET_FIX}" | grep -Fq "${UPSTREAM_FIX}"
git show --format= "${TARGET_FIX}" -- "${OWNED_PATH}" "${CONSUMER_PATH}" \
  > "${DIAG}/target-fix.patch"
grep -Fq 'VIRTIO_ID_MAC80211_HWSIM' "${DIAG}/target-fix.patch"
grep -Fq 'MAC80211_HWSIM virtio device id table' "${DIAG}/target-fix.patch"
{
  echo "target_fix=${TARGET_FIX}"
  echo "upstream_fix=${UPSTREAM_FIX}"
  echo "owned_path=${OWNED_PATH}"
  echo "consumer_path=${CONSUMER_PATH}"
} | tee "${DIAG}/target-history-summary.txt"

if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"; then
  grep -Fq -- '- Semantically resolved conflicts: **19**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **14**' "${LEDGER}"
  grep -Fq '### Virtio mac80211-hwsim device ID' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **18**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **15**' "${LEDGER}"
git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git rev-parse "${SCAFFOLD}:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "HEAD:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "${TARGET_COMMIT}:${OWNED_PATH}")" = "${EXPECTED_TARGET_BLOB}"
test "$(git rev-parse "${SCAFFOLD}:${CONSUMER_PATH}")" = "${EXPECTED_CONSUMER_BLOB}"
test "$(git rev-parse "HEAD:${CONSUMER_PATH}")" = "${EXPECTED_CONSUMER_BLOB}"
grep -Fq '{ VIRTIO_ID_MAC80211_HWSIM, VIRTIO_DEV_ANY_ID }' "${CONSUMER_PATH}"

git config user.name "Miru LTS Integration Bot"
git config user.email "miru-lts-integration@users.noreply.github.com"
python3 scripts/miru/lts305_resolve_virtio_id.py | tee "${DIAG}/resolver.txt"
test -s lts305-virtio-id-resolution.patch
mv lts305-virtio-id-resolution.patch "${DIAG}/source.patch"
PATCH_SHA="$(sha256sum "${DIAG}/source.patch" | awk '{print $1}')"
git diff --check
if git grep -nE '^(<<<<<<< .+|>>>>>>> .+|\|\|\|\|\|\|\| .+)$' -- "${OWNED_PATH}" \
    > "${DIAG}/conflict-markers.txt"; then
  cat "${DIAG}/conflict-markers.txt"
  exit 1
else
  : > "${DIAG}/conflict-markers.txt"
fi

test "$(grep -c '^#define VIRTIO_ID_MAC80211_HWSIM 29 ' "${OWNED_PATH}")" = 1
for spec in \
  'VIRTIO_ID_CLOCK 30' \
  'VIRTIO_ID_REGULATOR 31' \
  'VIRTIO_ID_I2C 32' \
  'VIRTIO_ID_SPMI 33' \
  'VIRTIO_ID_FASTRPC 34'; do
  name="${spec% *}"
  value="${spec##* }"
  test "$(awk -v n="${name}" '$1 == "#define" && $2 == n {print $3}' "${OWNED_PATH}")" = "${value}"
done

git add -- "${OWNED_PATH}"
test "$(git diff --cached --name-only)" = "${OWNED_PATH}"
git commit -m 'lts: resolve virtio mac80211-hwsim ID conflict for 4.14.305'
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
OUT_DIR="${ANDROID_ROOT}/out/h40-virtio-id-targeted"
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
  2>&1 | tee "${DIAG}/olddefconfig-stock.log"
grep -Fq 'CONFIG_MODVERSIONS=y' "${OUT_DIR}/.config"
cp "${OUT_DIR}/.config" "${DIAG}/stock.config"
grep -E '^(CONFIG_VIRTIO|# CONFIG_VIRTIO|CONFIG_VIRT_DRIVERS|# CONFIG_VIRT_DRIVERS)' \
  "${OUT_DIR}/.config" > "${DIAG}/stock-virtio-config.txt" || true

HEADER_SOURCE="${KERNEL_WORKTREE}/${OWNED_PATH}"
CONSUMER_SOURCE="${KERNEL_WORKTREE}/${CONSUMER_PATH}"
test "$(git -C "${KERNEL_WORKTREE}" rev-parse "HEAD:${CONSUMER_PATH}")" = "${EXPECTED_CONSUMER_BLOB}"
grep -Fq '#define VIRTIO_ID_MAC80211_HWSIM 29' "${HEADER_SOURCE}"
grep -Fq '{ VIRTIO_ID_MAC80211_HWSIM, VIRTIO_DEV_ANY_ID }' "${CONSUMER_SOURCE}"
cat > "${DIAG}/virtio-id-probe.c" <<'PROBE'
#include <linux/virtio_ids.h>
#if VIRTIO_ID_MAC80211_HWSIM != 29
#error VIRTIO_ID_MAC80211_HWSIM_mismatch
#endif
#if VIRTIO_ID_CLOCK != 30
#error VIRTIO_ID_CLOCK_mismatch
#endif
#if VIRTIO_ID_REGULATOR != 31
#error VIRTIO_ID_REGULATOR_mismatch
#endif
#if VIRTIO_ID_I2C != 32
#error VIRTIO_ID_I2C_mismatch
#endif
#if VIRTIO_ID_SPMI != 33
#error VIRTIO_ID_SPMI_mismatch
#endif
#if VIRTIO_ID_FASTRPC != 34
#error VIRTIO_ID_FASTRPC_mismatch
#endif
int virtio_id_probe(void) { return 0; }
PROBE
"${CLANG}" -nostdinc -ffreestanding -Wall -Werror \
  -I "${KERNEL_WORKTREE}/include/uapi" \
  -c "${DIAG}/virtio-id-probe.c" -o "${DIAG}/virtio-id-probe.o" \
  2>&1 | tee "${DIAG}/virtio-id-probe.log"
test -s "${DIAG}/virtio-id-probe.o"

"${KERNEL_WORKTREE}/scripts/config" --file "${OUT_DIR}/.config" --enable VIRTIO
make -C "${KERNEL_WORKTREE}" "${make_args[@]}" olddefconfig \
  2>&1 | tee "${DIAG}/olddefconfig-virtio-overlay.log"
grep -Fq 'CONFIG_VIRTIO=y' "${OUT_DIR}/.config"
cp "${OUT_DIR}/.config" "${DIAG}/virtio-overlay.config"
make -C "${KERNEL_WORKTREE}" -j4 V=0 "${make_args[@]}" "${TARGET_OBJECT}" \
  2>&1 | tee "${DIAG}/targeted-compile.log"
test -s "${OUT_DIR}/${TARGET_OBJECT}"
nm -a "${OUT_DIR}/${TARGET_OBJECT}" > "${DIAG}/targeted-object-nm.txt"
grep -Eq 'virtio_hwsim|hwsim_register_virtio_driver|id_table' \
  "${DIAG}/targeted-object-nm.txt"
if grep -nE '(^|[[:space:]])(warning|error):' \
    "${DIAG}/virtio-id-probe.log" "${DIAG}/targeted-compile.log" \
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
  echo "uapi_probe=PASS"
  echo "consumer_object=${TARGET_OBJECT}"
  echo "consumer_compile_overlay=CONFIG_VIRTIO=y"
  echo "overlay_committed=no"
  echo "compiler=$(${CLANG} --version | head -n1)"
  echo "downstream_ids_30_through_34_retained=yes"
  echo "clean_consumer_retained=yes"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-virtio-id-revert"
rm -rf "${REVERT_WORKTREE}"
git worktree add --detach "${REVERT_WORKTREE}" "${SOURCE_COMMIT}"
git -C "${REVERT_WORKTREE}" config user.name "Miru LTS Integration Bot"
git -C "${REVERT_WORKTREE}" config user.email "miru-lts-integration@users.noreply.github.com"
git -C "${REVERT_WORKTREE}" revert --no-edit "${SOURCE_COMMIT}" \
  > "${DIAG}/revert.stdout" 2> "${DIAG}/revert.stderr"
git -C "${REVERT_WORKTREE}" diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${OWNED_PATH}")" = \
     "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${CONSUMER_PATH}")" = \
     "${EXPECTED_CONSUMER_BLOB}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse 'HEAD^{tree}')" = \
     "$(git rev-parse "${START_HEAD}^{tree}")"
{
  echo "result=PASS"
  echo "owning_commit=${SOURCE_COMMIT}"
  echo "revert_commit=$(git -C "${REVERT_WORKTREE}" rev-parse HEAD)"
  echo "restored_scaffold=${SCAFFOLD}"
  echo "restored_path=${OWNED_PATH}"
  echo "restored_start_tree=$(git rev-parse "${START_HEAD}^{tree}")"
  echo "consumer_blob=${EXPECTED_CONSUMER_BLOB}"
} | tee "${DIAG}/reversal-summary.txt"

export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA TARGET_FIX UPSTREAM_FIX
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ['LEDGER'])
text = path.read_text()
for old, new in {
    '- Semantically resolved conflicts: **18**': '- Semantically resolved conflicts: **19**',
    '- Remaining semantic conflicts: **15**': '- Remaining semantic conflicts: **14**',
}.items():
    if old not in text:
        raise SystemExit(f'missing ledger status: {old}')
    text = text.replace(old, new, 1)

source = os.environ['SOURCE_COMMIT']
pattern = re.compile(
    r'^(\| 26 \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$',
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit('missing unresolved virtio manifest row 26')
replacement = (
    match.group(1) + 'resolved' +
    f' | `{source}` | consumer compile PASS | clean reversal PASS |'
)
text = text[:match.start()] + replacement + text[match.end():]

stmmac_anchor = '- Validation workflow run: `30247407576`.\n'
stmmac_evidence = (
    '- Validation artifact: run `30247407576`, artifact `8645678367`, '
    'digest `sha256:cdf4d4e7e9afe758f1185b39167ba554dd70788fbd7d539c4b212cadd11e389f`, '
    'size `10823` bytes.\n'
)
if stmmac_anchor not in text:
    raise SystemExit('missing STMMAC validation anchor')
if 'artifact `8645678367`' not in text:
    text = text.replace(stmmac_anchor, stmmac_anchor + stmmac_evidence, 1)

record = f'''
### Virtio mac80211-hwsim device ID

- Owning source commit: `{source}`.
- Owned path: `include/uapi/linux/virtio_ids.h`.
- Cleanly merged consumer: `drivers/net/wireless/mac80211_hwsim.c` already contains the virtio device table using `VIRTIO_ID_MAC80211_HWSIM`; scaffold blob `39642c510d7740d54e4f6fd7287a631c6734d3e6` was preserved unchanged.
- Relevant Android Common commit: `{os.environ['TARGET_FIX']}` (upstream `{os.environ['UPSTREAM_FIX']}`).
- Android behavior imported: define virtio device ID 29 for mac80211-hwsim so the cleanly merged virtio driver has its matching UAPI identifier.
- Downstream behavior retained: Miru's IDs 30 through 34 for clock, regulator, I2C, SPMI, and FastRPC remain present with their original values.
- Semantic decision: form the union of the Android target's ID 29 and Miru's later downstream IDs instead of replacing the downstream header with the shorter target version.
- Audited source patch SHA-256: `{os.environ['PATCH_SHA']}` using `git diff --binary --full-index`.
- Header validation: **PASS** for a freestanding compile-time UAPI ID probe against the stock tree.
- Consumer compilation: **PASS** for `drivers/net/wireless/mac80211_hwsim.o` using the pinned H.40 toolchain and a compile-only `CONFIG_VIRTIO=y` overlay derived from the stock configuration. The overlay was not committed. Diagnostics were clean.
- Virtio ID source-behavior and clean-consumer gates: **PASS**.
- Clean reversal: **PASS**; reverting `{source}` restored the owned header exactly to scaffold `{os.environ['SCAFFOLD']}`, restored the complete pre-resolution integration tree, and preserved the cleanly merged consumer blob.
- Validation workflow run: `{os.environ.get('GITHUB_RUN_ID', 'unknown')}`.
'''
if '### Virtio mac80211-hwsim device ID' in text:
    raise SystemExit('virtio ID resolution record already exists')
text += record
path.write_text(text)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record virtio ID validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=19"
  echo "semantic_conflicts_remaining=14"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
