#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=a042724a88b8125f5c1e5ee8c3181ddcf3ba8e0d
MAILBOX_SOURCE=8b9ea460afb7692145090c2d307f6695bed12b3c
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
DIAG=lts305-mmc-resolution

HOST_FIX=3fac2cb56ba5205547e296b193e52871f9dc3845
HOST_UPSTREAM=d6c9219ca1139b74541b2a98cee47a3426d754a9
MMC_TIMEOUT_FIX=0aa3b6395fa30613368b0a34aa208c7ea9ad78f5
MMC_TIMEOUT_UPSTREAM=24ed3bd01d6a844fd5e8a75f48d0a3d10ed71bf9
MMC_GENERIC_FIX=327b6689898baa9734ca607939598d78b3cc234b
MMC_GENERIC_UPSTREAM=533a6cfe08f96a7b5c65e06d20916d552c11b256
SDHCI_FIELD_FIX=99c3d73a7f1225222efe573a0e0b39c8280f4679
SDHCI_FIELD_UPSTREAM=fa0910107a9fea170b817f31da2a65463e00e80e
SDHCI_VOLT_FIX=f60b9ea221edd04b591916ccabf1733e0d060860
SDHCI_VOLT_UPSTREAM=c981cdfb9925f64a364f13c2b4f98f877308a408

OWNED_PATHS=(
  drivers/mmc/core/host.c
  drivers/mmc/core/mmc_ops.c
  drivers/mmc/host/sdhci.c
)
TARGET_OBJECTS=(
  drivers/mmc/core/host.o
  drivers/mmc/core/mmc_ops.o
  drivers/mmc/host/sdhci.o
)
SDHCI_HEADER=drivers/mmc/host/sdhci.h
EXPECTED_HEADER_BLOB=b3f0fb715b05dd1147fd3f97018c938fc90139f0

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
git merge-base --is-ancestor "${MAILBOX_SOURCE}" "${START_HEAD}"
test "$(git rev-parse "${SCAFFOLD}^1")" = "${SCAFFOLD_PARENT1}"
test "$(git rev-parse "${SCAFFOLD}^2")" = "${TARGET_COMMIT}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305

for fix in \
  "${HOST_FIX}" "${MMC_TIMEOUT_FIX}" "${MMC_GENERIC_FIX}" \
  "${SDHCI_FIELD_FIX}" "${SDHCI_VOLT_FIX}"; do
  git merge-base --is-ancestor "${fix}" "${TARGET_COMMIT}"
done
git show -s --format=%B "${HOST_FIX}" | grep -Fq "${HOST_UPSTREAM}"
git show -s --format=%B "${MMC_TIMEOUT_FIX}" | grep -Fq "${MMC_TIMEOUT_UPSTREAM}"
git show -s --format=%B "${MMC_GENERIC_FIX}" | grep -Fq "${MMC_GENERIC_UPSTREAM}"
git show -s --format=%B "${SDHCI_FIELD_FIX}" | grep -Fq "${SDHCI_FIELD_UPSTREAM}"
git show -s --format=%B "${SDHCI_VOLT_FIX}" | grep -Fq "${SDHCI_VOLT_UPSTREAM}"

git show --format= "${HOST_FIX}" -- drivers/mmc/core/host.c \
  > "${DIAG}/target-host.patch"
git show --format= "${MMC_TIMEOUT_FIX}" -- drivers/mmc/core/mmc_ops.c \
  > "${DIAG}/target-mmc-timeouts.patch"
git show --format= "${MMC_GENERIC_FIX}" -- drivers/mmc/core/mmc_ops.c \
  > "${DIAG}/target-mmc-generic.patch"
git show --format= "${SDHCI_FIELD_FIX}" -- drivers/mmc/host/sdhci.c "${SDHCI_HEADER}" \
  > "${DIAG}/target-sdhci-fields.patch"
git show --format= "${SDHCI_VOLT_FIX}" -- drivers/mmc/host/sdhci.c "${SDHCI_HEADER}" \
  > "${DIAG}/target-sdhci-voltage.patch"
grep -Fq 'mmc_validate_host_caps' "${DIAG}/target-host.patch"
grep -Fq 'MMC_BKOPS_TIMEOUT_MS' "${DIAG}/target-mmc-timeouts.patch"
grep -Fq 'generic_cmd6_time' "${DIAG}/target-mmc-generic.patch"
grep -Fq 'FIELD_GET' "${DIAG}/target-sdhci-fields.patch"
grep -Fq 'reinit_uhs' "${DIAG}/target-sdhci-voltage.patch"
{
  echo "host_fix=${HOST_FIX} upstream=${HOST_UPSTREAM}"
  echo "mmc_timeout_fix=${MMC_TIMEOUT_FIX} upstream=${MMC_TIMEOUT_UPSTREAM}"
  echo "mmc_generic_fix=${MMC_GENERIC_FIX} upstream=${MMC_GENERIC_UPSTREAM}"
  echo "sdhci_field_fix=${SDHCI_FIELD_FIX} upstream=${SDHCI_FIELD_UPSTREAM}"
  echo "sdhci_voltage_fix=${SDHCI_VOLT_FIX} upstream=${SDHCI_VOLT_UPSTREAM}"
} | tee "${DIAG}/target-history-summary.txt"

if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATHS[@]}"; then
  grep -Fq -- '- Semantically resolved conflicts: **17**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **16**' "${LEDGER}"
  grep -Fq '### MMC host validation, eMMC timeouts, and SDHCI voltage switching' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **14**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **19**' "${LEDGER}"
for path in "${OWNED_PATHS[@]}"; do
  git diff --quiet "${SCAFFOLD}" -- "${path}"
done
test "$(git rev-parse "${SCAFFOLD}:${SDHCI_HEADER}")" = "${EXPECTED_HEADER_BLOB}"
test "$(git rev-parse "HEAD:${SDHCI_HEADER}")" = "${EXPECTED_HEADER_BLOB}"

git config user.name "Miru LTS Integration Bot"
git config user.email "miru-lts-integration@users.noreply.github.com"
python3 scripts/miru/lts305_resolve_mmc.py | tee "${DIAG}/resolver.txt"
test -s lts305-mmc-resolution.patch
mv lts305-mmc-resolution.patch "${DIAG}/source.patch"
PATCH_SHA="$(sha256sum "${DIAG}/source.patch" | awk '{print $1}')"
git diff --check
if git grep -nE '^(<<<<<<< .+|>>>>>>> .+|\|\|\|\|\|\|\| .+)$' -- "${OWNED_PATHS[@]}" \
    > "${DIAG}/conflict-markers.txt"; then
  cat "${DIAG}/conflict-markers.txt"
  exit 1
else
  : > "${DIAG}/conflict-markers.txt"
fi

git add -- "${OWNED_PATHS[@]}"
mapfile -t STAGED_PATHS < <(git diff --cached --name-only)
test "${STAGED_PATHS[*]}" = "${OWNED_PATHS[*]}"
git commit -m 'lts: resolve MMC conflict cluster for 4.14.305'
SOURCE_COMMIT="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${START_HEAD}"
mapfile -t COMMIT_PATHS < <(git diff-tree --no-commit-id --name-only -r "${SOURCE_COMMIT}")
test "${COMMIT_PATHS[*]}" = "${OWNED_PATHS[*]}"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file

ANDROID_ROOT="${RUNNER_TEMP}/android-root"
KERNEL_WORKTREE="${ANDROID_ROOT}/kernel/msm-4.14"
VENDOR_SOURCE="${RUNNER_TEMP}/oneplus-sm8150-vendor-source"
OUT_DIR="${ANDROID_ROOT}/out/h40-mmc-targeted"
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

HOST_SOURCE="${KERNEL_WORKTREE}/${OWNED_PATHS[0]}"
MMC_OPS_SOURCE="${KERNEL_WORKTREE}/${OWNED_PATHS[1]}"
SDHCI_SOURCE="${KERNEL_WORKTREE}/${OWNED_PATHS[2]}"
SDHCI_HEADER_SOURCE="${KERNEL_WORKTREE}/${SDHCI_HEADER}"
test "$(git -C "${KERNEL_WORKTREE}" rev-parse "HEAD:${SDHCI_HEADER}")" = "${EXPECTED_HEADER_BLOB}"
grep -Fq 'static int mmc_validate_host_caps(struct mmc_host *host)' "${HOST_SOURCE}"
grep -Fq 'return -EINVAL;' "${HOST_SOURCE}"
! grep -Fq 'WARN_ON((host->caps & MMC_CAP_SDIO_IRQ)' "${HOST_SOURCE}"
grep -Fq 'clk_scaling.polling_delay_ms' "${HOST_SOURCE}"
grep -Fq '#define MMC_BKOPS_TIMEOUT_MS' "${MMC_OPS_SOURCE}"
grep -Fq '#define MMC_CACHE_FLUSH_TIMEOUT_MS' "${MMC_OPS_SOURCE}"
grep -Fq 'timeout_ms = card->ext_csd.generic_cmd6_time;' "${MMC_OPS_SOURCE}"
grep -Fq 'int retries = 5;' "${MMC_OPS_SOURCE}"
grep -Fq 'MMC_QUIRK_CACHE_DISABLE' "${MMC_OPS_SOURCE}"
grep -Fq 'err = mmc_interrupt_hpi(card);' "${MMC_OPS_SOURCE}"
grep -Fq '#include <linux/bitfield.h>' "${SDHCI_SOURCE}"
grep -Fq 'FIELD_GET(SDHCI_PRESET_SDCLK_FREQ_MASK, pre_val)' "${SDHCI_SOURCE}"
grep -Fq 'static bool sdhci_presetable_values_change' "${SDHCI_SOURCE}"
grep -Fq 'goto ios_done;' "${SDHCI_SOURCE}"
grep -Fq 'ios_done:' "${SDHCI_SOURCE}"
grep -Fq 'sdhci_cfg_irq(host, true, false);' "${SDHCI_SOURCE}"
test "$(grep -c 'host->reinit_uhs = true;' "${SDHCI_SOURCE}")" = 3
grep -Fq '#define SDHCI_PRESET_CLKGEN_SEL' "${SDHCI_HEADER_SOURCE}"
grep -Fq 'u8 drv_type;' "${SDHCI_HEADER_SOURCE}"
grep -Fq 'bool reinit_uhs;' "${SDHCI_HEADER_SOURCE}"

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
  echo "patch_sha256=${PATCH_SHA}"
  echo "vendor_commit=${VENDOR_SHA}"
  printf 'targeted_objects=%s\n' "${TARGET_OBJECTS[*]}"
  echo "compiler=$(${CLANG} --version | head -n1)"
  echo "sdio_host_validation=yes"
  echo "mmc_timeout_policy=yes"
  echo "mmc_busy_retry_retained=yes"
  echo "sdhci_voltage_switch_fast_path=yes"
  echo "downstream_sdio_irq_cleanup_retained=yes"
  echo "clean_sdhci_header_retained=yes"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-mmc-revert"
rm -rf "${REVERT_WORKTREE}"
git worktree add --detach "${REVERT_WORKTREE}" "${SOURCE_COMMIT}"
git -C "${REVERT_WORKTREE}" config user.name "Miru LTS Integration Bot"
git -C "${REVERT_WORKTREE}" config user.email "miru-lts-integration@users.noreply.github.com"
git -C "${REVERT_WORKTREE}" revert --no-edit "${SOURCE_COMMIT}" \
  > "${DIAG}/revert.stdout" 2> "${DIAG}/revert.stderr"
for path in "${OWNED_PATHS[@]}"; do
  git -C "${REVERT_WORKTREE}" diff --quiet "${SCAFFOLD}" -- "${path}"
  test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${path}")" = \
       "$(git rev-parse "${SCAFFOLD}:${path}")"
done
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${SDHCI_HEADER}")" = \
     "${EXPECTED_HEADER_BLOB}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse 'HEAD^{tree}')" = \
     "$(git rev-parse "${START_HEAD}^{tree}")"
{
  echo "result=PASS"
  echo "owning_commit=${SOURCE_COMMIT}"
  echo "revert_commit=$(git -C "${REVERT_WORKTREE}" rev-parse HEAD)"
  echo "restored_scaffold=${SCAFFOLD}"
  printf 'restored_paths=%s\n' "${OWNED_PATHS[*]}"
  echo "restored_start_tree=$(git rev-parse "${START_HEAD}^{tree}")"
  echo "header_blob=${EXPECTED_HEADER_BLOB}"
} | tee "${DIAG}/reversal-summary.txt"

export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA
export HOST_FIX HOST_UPSTREAM MMC_TIMEOUT_FIX MMC_TIMEOUT_UPSTREAM
export MMC_GENERIC_FIX MMC_GENERIC_UPSTREAM SDHCI_FIELD_FIX SDHCI_FIELD_UPSTREAM
export SDHCI_VOLT_FIX SDHCI_VOLT_UPSTREAM
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ['LEDGER'])
text = path.read_text()
for old, new in {
    '- Semantically resolved conflicts: **14**': '- Semantically resolved conflicts: **17**',
    '- Remaining semantic conflicts: **19**': '- Remaining semantic conflicts: **16**',
}.items():
    if old not in text:
        raise SystemExit(f'missing ledger status: {old}')
    text = text.replace(old, new, 1)

source = os.environ['SOURCE_COMMIT']
for row in (12, 13, 14):
    pattern = re.compile(
        rf'^(\| {row} \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$',
        re.M,
    )
    match = pattern.search(text)
    if not match:
        raise SystemExit(f'missing unresolved MMC manifest row {row}')
    replacement = (
        match.group(1) + 'resolved' +
        f' | `{source}` | targeted compile PASS | clean reversal PASS |'
    )
    text = text[:match.start()] + replacement + text[match.end():]

mailbox_anchor = '- Validation workflow run: `30243978850`.\n'
mailbox_evidence = (
    '- Validation artifact: run `30243978850`, artifact `8644384315`, '
    'digest `sha256:92bdd5562de50705ea27d7b4fe550a4c52d6af850e50c43da5602b36728e8829`, '
    'size `11031` bytes.\n'
)
if mailbox_anchor not in text:
    raise SystemExit('missing mailbox validation anchor')
if 'artifact `8644384315`' not in text:
    text = text.replace(mailbox_anchor, mailbox_anchor + mailbox_evidence, 1)

record = f'''
### MMC host validation, eMMC timeouts, and SDHCI voltage switching

- Owning source commit: `{source}`.
- Owned paths: `drivers/mmc/core/host.c`, `drivers/mmc/core/mmc_ops.c`, and `drivers/mmc/host/sdhci.c`.
- Cleanly merged dependency: `drivers/mmc/host/sdhci.h` already contains the target preset masks plus `drv_type` and `reinit_uhs`; scaffold blob `b3f0fb715b05dd1147fd3f97018c938fc90139f0` was preserved unchanged.
- Relevant Android Common commits: `{os.environ['HOST_FIX']}` (upstream `{os.environ['HOST_UPSTREAM']}`), `{os.environ['MMC_TIMEOUT_FIX']}` (upstream `{os.environ['MMC_TIMEOUT_UPSTREAM']}`), `{os.environ['MMC_GENERIC_FIX']}` (upstream `{os.environ['MMC_GENERIC_UPSTREAM']}`), `{os.environ['SDHCI_FIELD_FIX']}` (upstream `{os.environ['SDHCI_FIELD_UPSTREAM']}`), and `{os.environ['SDHCI_VOLT_FIX']}` (upstream `{os.environ['SDHCI_VOLT_UPSTREAM']}`).
- Android behavior imported: reject an SDIO-IRQ-capable host lacking `enable_sdio_irq`; use 120-second BKOPS and 30-second cache-flush limits; default unspecified CMD6 timeouts to `generic_cmd6_time`; convert SDHCI preset extraction to `FIELD_GET`; and avoid redundant UHS/preset clock changes during voltage switching.
- Downstream behavior retained: MMC clock-scaling and sysfs setup; the five-retry busy-poll diagnostic path; cache-disable handling and HPI recovery after cache-flush timeout; SDHCI controller-clock/power sequencing; spinlock coverage; and SDIO IRQ disable/restore bookkeeping.
- Semantic decision: adapt the upstream SDHCI early-return case to jump through Miru's downstream `ios_done` cleanup tail, ensuring the temporarily disabled SDIO IRQ is restored before returning.
- Audited source patch SHA-256: `{os.environ['PATCH_SHA']}` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/mmc/core/host.o`, `drivers/mmc/core/mmc_ops.o`, and `drivers/mmc/host/sdhci.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- MMC source-behavior and clean-header gates: **PASS**.
- Clean reversal: **PASS**; reverting `{source}` restored all three owned paths exactly to scaffold `{os.environ['SCAFFOLD']}`, restored the complete pre-resolution integration tree, and preserved the cleanly merged SDHCI header blob.
- Validation workflow run: `{os.environ.get('GITHUB_RUN_ID', 'unknown')}`.
'''
if '### MMC host validation, eMMC timeouts, and SDHCI voltage switching' in text:
    raise SystemExit('MMC resolution record already exists')
text += record
path.write_text(text)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record MMC resolution validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=17"
  echo "semantic_conflicts_remaining=16"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
