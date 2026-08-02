#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_COMMON_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=a21134bce21ddc022119a2ed1ac4d65349971233
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
OWNED_PATH=include/net/netfilter/nf_queue.h
TARGET_OBJECT=net/netfilter/nf_queue.o
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
EXPECTED_BASE_BLOB=814058d0f167289948b49290047060b0932dad73
EXPECTED_SCAFFOLD_BLOB=6a8fe020a400075cdce731057b1ea85bfd88cc56
EXPECTED_TARGET_BLOB=f38cc6092c5a5ac4e609a6c40892e280d5fd4bf6
EXPECTED_SCAFFOLD_IMPL_BLOB=da89ded3c9ffd49318f7d1be9a8ef11e3539749a
EXPECTED_TARGET_IMPL_BLOB=46984cdee6581729c42442fb3908936d93312762
DIAG=lts305-nf-queue-header-resolution

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
TARGET_UAF_FIX=
while IFS=$'\t' read -r sha subject; do
  if git show --format= "${sha}" -- "${OWNED_PATH}" | \
      grep -Fxq '+bool nf_queue_entry_get_refs(struct nf_queue_entry *entry);'; then
    TARGET_UAF_FIX="${sha}"
    break
  fi
done < "${DIAG}/target-history.tsv"
test -n "${TARGET_UAF_FIX}"
git merge-base --is-ancestor "${TARGET_UAF_FIX}" "${TARGET_COMMIT}"
git show -s --format=fuller "${TARGET_UAF_FIX}" > "${DIAG}/target-uaf-upstream.txt"
git show "${TARGET_COMMIT}:${OWNED_PATH}" > "${DIAG}/target-nf_queue.h"
git show "${TARGET_COMMIT}:net/netfilter/nf_queue.c" > "${DIAG}/target-nf_queue.c"

if ! git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"; then
  grep -Fq -- '- Semantically resolved conflicts: **22**' "${LEDGER}"
  grep -Fq -- '- Remaining semantic conflicts: **11**' "${LEDGER}"
  grep -Fq '### Netfilter queue reference API UAF fix' "${LEDGER}"
  {
    echo "status=already-resolved"
    echo "head=${START_HEAD}"
    echo "production=${PRODUCTION_SHA}"
  } | tee "${DIAG}/already-resolved.txt"
  find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **21**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **12**' "${LEDGER}"
git diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git rev-parse "${PREVIOUS_COMMON_TARGET}:${OWNED_PATH}")" = "${EXPECTED_BASE_BLOB}"
test "$(git rev-parse "${SCAFFOLD}:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "HEAD:${OWNED_PATH}")" = "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git rev-parse "${TARGET_COMMIT}:${OWNED_PATH}")" = "${EXPECTED_TARGET_BLOB}"
for ref in "${SCAFFOLD}" HEAD; do
  test "$(git rev-parse "${ref}:net/netfilter/nf_queue.c")" = "${EXPECTED_SCAFFOLD_IMPL_BLOB}"
done
test "$(git rev-parse "${TARGET_COMMIT}:net/netfilter/nf_queue.c")" = "${EXPECTED_TARGET_IMPL_BLOB}"
grep -Fq 'bool nf_queue_entry_get_refs(struct nf_queue_entry *entry)' "${DIAG}/target-nf_queue.c"
grep -Fq 'refcount_inc_not_zero(&state->sk->sk_refcnt)' "${DIAG}/target-nf_queue.c"
test "$(grep -Fxc 'void nf_queue_entry_get_refs(struct nf_queue_entry *entry);' "${OWNED_PATH}")" = 1
! grep -Fq 'bool nf_queue_entry_get_refs(struct nf_queue_entry *entry);' "${OWNED_PATH}"
test "$(grep -Fxc 'bool nf_queue_entry_get_refs(struct nf_queue_entry *entry);' "${DIAG}/target-nf_queue.h")" = 1
! grep -Fq 'void nf_queue_entry_get_refs(struct nf_queue_entry *entry);' "${DIAG}/target-nf_queue.h"

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
old = "void nf_queue_entry_get_refs(struct nf_queue_entry *entry);\n"
new = "bool nf_queue_entry_get_refs(struct nf_queue_entry *entry);\n"
if target.count(new) != 1 or old in target:
    raise SystemExit("target queue-reference API declaration is not exact")
if current.count(old) != 1 or new in current:
    raise SystemExit("scaffold queue-reference API declaration is not exact")
resolved = current.replace(old, new, 1)
if resolved.replace(new, old, 1) != current:
    raise SystemExit("resolver did not preserve the complete downstream header scaffold")
if resolved.count(new) != 1 or old in resolved:
    raise SystemExit("resolution has incorrect queue-reference API declaration")
owned.write_text(resolved)
print("status=resolved")
print("target_declaration_sha256=" + hashlib.sha256(new.encode()).hexdigest())
print("downstream_header_scaffold_preserved=yes")
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
assert text.count("bool nf_queue_entry_get_refs(struct nf_queue_entry *entry);\n") == 1
assert "void nf_queue_entry_get_refs(struct nf_queue_entry *entry);\n" not in text
print("source_behavior_gates=PASS")
PY
git add -- "${OWNED_PATH}"
test "$(git diff --cached --name-only)" = "${OWNED_PATH}"
git commit -m 'lts: resolve nf_queue header conflict for 4.14.305'
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
OUT_DIR="${ANDROID_ROOT}/out/h40-nf-queue-header-targeted"
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
grep -Fq 'CONFIG_NETFILTER_NETLINK_QUEUE=y' "${OUT_DIR}/.config"
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
  echo "source_commit=${SOURCE_COMMIT}"
  echo "target_object=${TARGET_OBJECT}"
  echo "netfilter_queue_enabled=yes"
  echo "queue_reference_api=bool-return PASS"
  echo "compiler=$("${CLANG}" --version | head -n1)"
  echo "scaffold_implementation_blob=${EXPECTED_SCAFFOLD_IMPL_BLOB}"
  echo "target_implementation_blob=${EXPECTED_TARGET_IMPL_BLOB}"
} | tee "${DIAG}/targeted-compile-summary.txt"

REVERT_WORKTREE="${RUNNER_TEMP}/lts305-nf-queue-header-revert"
rm -rf "${REVERT_WORKTREE}"
git worktree add --detach "${REVERT_WORKTREE}" "${SOURCE_COMMIT}"
git -C "${REVERT_WORKTREE}" config user.name "Miru LTS Integration Bot"
git -C "${REVERT_WORKTREE}" config user.email "miru-lts-integration@users.noreply.github.com"
git -C "${REVERT_WORKTREE}" revert --no-edit "${SOURCE_COMMIT}" \
  > "${DIAG}/revert.stdout" 2> "${DIAG}/revert.stderr"
git -C "${REVERT_WORKTREE}" diff --quiet "${SCAFFOLD}" -- "${OWNED_PATH}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:${OWNED_PATH}")" = \
     "${EXPECTED_SCAFFOLD_BLOB}"
test "$(git -C "${REVERT_WORKTREE}" rev-parse "HEAD:net/netfilter/nf_queue.c")" = \
     "${EXPECTED_SCAFFOLD_IMPL_BLOB}"
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

export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA TARGET_UAF_FIX TARGET_COMMIT EXPECTED_SCAFFOLD_BLOB EXPECTED_TARGET_BLOB EXPECTED_SCAFFOLD_IMPL_BLOB EXPECTED_TARGET_IMPL_BLOB
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["LEDGER"])
text = path.read_text()
for old, new in {
    "- Semantically resolved conflicts: **21**": "- Semantically resolved conflicts: **22**",
    "- Remaining semantic conflicts: **12**": "- Remaining semantic conflicts: **11**",
}.items():
    if old not in text:
        raise SystemExit(f"missing ledger status: {old}")
    text = text.replace(old, new, 1)

source = os.environ["SOURCE_COMMIT"]
pattern = re.compile(
    r"^(\| 24 \| `include/net/netfilter/nf_queue.h` \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$",
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit("missing unresolved nf_queue header manifest row 24")
replacement = (
    match.group(1) + "resolved" +
    f" | `{source}` | nf_queue.o PASS | clean reversal PASS |"
)
text = text[:match.start()] + replacement + text[match.end():]

record = f"""
### Netfilter queue reference API UAF fix

- Owning source commit: `{source}`.
- Owned path: `include/net/netfilter/nf_queue.h`.
- Relevant Android Common commit: `{os.environ['TARGET_UAF_FIX']}`, target-reachable from `{os.environ['TARGET_COMMIT']}`.
- Android behavior imported: the queue-reference helper returns `bool` so callers can abandon queueing when the socket refcount cannot be acquired.
- Downstream intent retained: preserve the exact scaffold header layout outside the single declaration change.
- Semantic decision: replace only the stale `void` prototype with Android Common's `bool` prototype. The cleanly merged `net/netfilter/nf_queue.c` already implements the failure path via `refcount_inc_not_zero`; Miru's clean scaffold implementation is preserved byte-for-byte.
- Scaffold header blob: `{os.environ['EXPECTED_SCAFFOLD_BLOB']}`. Target header blob: `{os.environ['EXPECTED_TARGET_BLOB']}`. Scaffold implementation blob: `{os.environ['EXPECTED_SCAFFOLD_IMPL_BLOB']}`. Target implementation blob: `{os.environ['EXPECTED_TARGET_IMPL_BLOB']}`.
- Audited source patch SHA-256: `{os.environ['PATCH_SHA']}` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `net/netfilter/nf_queue.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Queue API identity and clean implementation-blob gates: **PASS**.
- Clean reversal: **PASS**; reverting `{source}` restored `include/net/netfilter/nf_queue.h` exactly to scaffold `{os.environ['SCAFFOLD']}`, preserved the clean implementation blob and restored the complete pre-resolution integration tree.
- Validation workflow run: `{os.environ.get('GITHUB_RUN_ID', 'unknown')}`.
"""
if "### Netfilter queue reference API UAF fix" in text:
    raise SystemExit("nf_queue header resolution record already exists")
text += record
path.write_text(text)
PY

git add -- "${LEDGER}"
test "$(git diff --cached --name-only)" = "${LEDGER}"
git commit -m 'docs: record nf_queue header validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "${SOURCE_COMMIT}"
{
  echo "status=PASS"
  echo "start_head=${START_HEAD}"
  echo "source_commit=${SOURCE_COMMIT}"
  echo "documentation_head=${DOC_HEAD}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "scaffold=${SCAFFOLD}"
  echo "semantic_conflicts_resolved=22"
  echo "semantic_conflicts_remaining=11"
} | tee "${DIAG}/resolution-summary.txt"
git show --stat --oneline "${SOURCE_COMMIT}" > "${DIAG}/source-commit.txt"
git show --stat --oneline "${DOC_HEAD}" > "${DIAG}/documentation-commit.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${START_HEAD}"
git push origin "${DOC_HEAD}:refs/heads/${INTEGRATION_BRANCH}"
