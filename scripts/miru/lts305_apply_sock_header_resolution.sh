#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_COMMON_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=eea8c3e1344bff85293fb8c4242cd8059ea75df4
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
OWNED=include/net/sock.h
TARGET_OBJECT=net/core/sock.o
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
EXPECTED_PREVIOUS_BLOB=029df5cdeaf1254b12b68de22b97b9e9bd5a437e
EXPECTED_SCAFFOLD_BLOB=2271e669be9e73cbd3b1e6efa80b39c1ff17d70c
EXPECTED_TARGET_BLOB=4053eea6182addea78e34d684c72153dab6a4c53
DIAG=lts305-sock-header-resolution

rm -rf "$DIAG"
mkdir -p "$DIAG"
trap 'rc=$?; { printf "exit=%s\n" "$rc"; printf "line=%s\n" "$LINENO"; printf "command=%q\n" "$BASH_COMMAND"; } > "$DIAG/failure.txt"; exit "$rc"' ERR

START_HEAD="$(git rev-parse HEAD)"
REMOTE_PRODUCTION="$(git ls-remote origin "refs/heads/$PRODUCTION_BRANCH" | awk '{print $1}')"
REMOTE_INTEGRATION="$(git ls-remote origin "refs/heads/$INTEGRATION_BRANCH" | awk '{print $1}')"
test "$REMOTE_PRODUCTION" = "$PRODUCTION_SHA"
test "$REMOTE_INTEGRATION" = "$START_HEAD"
git merge-base --is-ancestor "$PRODUCTION_SHA" "$START_HEAD"
git merge-base --is-ancestor "$TARGET_COMMIT" "$START_HEAD"
git merge-base --is-ancestor "$SCAFFOLD" "$START_HEAD"
git merge-base --is-ancestor "$PREVIOUS_VALIDATED_HEAD" "$START_HEAD"
git merge-base --is-ancestor "$PREVIOUS_COMMON_TARGET" "$TARGET_COMMIT"
test "$(git rev-parse "$SCAFFOLD^1")" = "$SCAFFOLD_PARENT1"
test "$(git rev-parse "$SCAFFOLD^2")" = "$TARGET_COMMIT"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305

git log --format='%H%x09%s' "$PREVIOUS_COMMON_TARGET..$TARGET_COMMIT" \
  -- "$OWNED" > "$DIAG/target-history.tsv"

find_target_commit() {
  local marker="$1" sha
  while IFS= read -r sha; do
    if git show --format= --unified=0 "$sha" -- "$OWNED" | grep -Fqx -- "$marker"; then
      printf '%s\n' "$sha"
      return 0
    fi
  done < <(git log --format='%H' "$PREVIOUS_COMMON_TARGET..$TARGET_COMMIT" -- "$OWNED")
  return 1
}

TARGET_RX_DST_COMMIT="$(find_target_commit $'+\tstruct dst_entry __rcu\t*sk_rx_dst;')"
TARGET_MEM_READ_COMMIT="$(find_target_commit $'+\tlong val = READ_ONCE(sk->sk_prot->sysctl_mem[index]);')"
TARGET_TX_TIMESTAMP_COMMIT="$(find_target_commit '+static inline void _sock_tx_timestamp(struct sock *sk, __u16 tsflags,')"
TARGET_FRAG_ORDER_COMMIT="$(find_target_commit $'+#define SKB_FRAG_PAGE_ORDER\tget_order(32768)')"
for sha in "$TARGET_RX_DST_COMMIT" "$TARGET_MEM_READ_COMMIT" \
  "$TARGET_TX_TIMESTAMP_COMMIT" "$TARGET_FRAG_ORDER_COMMIT" \
  "$PREVIOUS_COMMON_TARGET"; do
  git merge-base --is-ancestor "$sha" "$TARGET_COMMIT"
done
{
  printf 'rx-dst-rcu\t%s\n' "$TARGET_RX_DST_COMMIT"
  printf 'mem-limit-read-once\t%s\n' "$TARGET_MEM_READ_COMMIT"
  printf 'tx-timestamp-api\t%s\n' "$TARGET_TX_TIMESTAMP_COMMIT"
  printf 'skb-frag-order\t%s\n' "$TARGET_FRAG_ORDER_COMMIT"
  printf 'tskey-baseline\t%s\n' "$PREVIOUS_COMMON_TARGET"
} > "$DIAG/target-sock-provenance.tsv"
while IFS=$'\t' read -r label sha; do
  git show -s --format=fuller "$sha" > "$DIAG/target-$label-commit.txt"
  git show --format= --unified=0 "$sha" -- "$OWNED" > "$DIAG/target-$label.patch"
done < "$DIAG/target-sock-provenance.tsv"
git show "$PREVIOUS_COMMON_TARGET:$OWNED" > "$DIAG/previous-common-sock.h"
grep -Fq 'sk_tskey;' "$DIAG/previous-common-sock.h"

if ! git diff --quiet "$SCAFFOLD" -- "$OWNED"; then
  grep -Fq -- '- Semantically resolved conflicts: **29**' "$LEDGER"
  grep -Fq -- '- Remaining semantic conflicts: **4**' "$LEDGER"
  grep -Fq '### Socket core RCU and TX timestamp API union' "$LEDGER"
  {
    echo 'status=already-resolved'
    echo "head=$START_HEAD"
    echo "production=$PRODUCTION_SHA"
  } | tee "$DIAG/already-resolved.txt"
  find "$DIAG" -type f -print0 | sort -z | xargs -0 sha256sum > "$DIAG/SHA256SUMS"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **28**' "$LEDGER"
grep -Fq -- '- Remaining semantic conflicts: **5**' "$LEDGER"
git diff --quiet "$SCAFFOLD" -- "$OWNED"
test "$(git rev-parse "$PREVIOUS_COMMON_TARGET:$OWNED")" = "$EXPECTED_PREVIOUS_BLOB"
test "$(git rev-parse "$SCAFFOLD:$OWNED")" = "$EXPECTED_SCAFFOLD_BLOB"
test "$(git rev-parse "HEAD:$OWNED")" = "$EXPECTED_SCAFFOLD_BLOB"
test "$(git rev-parse "$TARGET_COMMIT:$OWNED")" = "$EXPECTED_TARGET_BLOB"
git show "$TARGET_COMMIT:$OWNED" > "$DIAG/target-sock.h"

git config user.name 'Miru LTS Integration Bot'
git config user.email 'miru-lts-integration@users.noreply.github.com'
export OWNED TARGET_COMMIT DIAG
python3 - <<'PY' | tee "$DIAG/resolver.txt"
from pathlib import Path
import hashlib
import os
import subprocess

t = "\t"
nl = "\n"
path = Path(os.environ["OWNED"])
original = path.read_text()
target = subprocess.check_output(
    ["git", "show", f"{os.environ['TARGET_COMMIT']}:{os.environ['OWNED']}"],
    text=True,
)

def count(text, needle, expected, label):
    found = text.count(needle)
    if found != expected:
        raise SystemExit(f"{label}: expected {expected}, found {found}")

def replace_once(text, old, new, label, history):
    count(text, old, 1, f"{label} old pattern")
    history.append((old, new, label))
    return text.replace(old, new, 1)

def timestamp_block(text, start):
    begin = text.index(start)
    end = text.index("/**\n * sk_eat_skb", begin)
    return text[begin:end]

def confirm_neigh_block(text):
    begin = text.index("static inline void sock_confirm_neigh")
    end = text.index("\n\nbool sk_mc_loop", begin)
    return text[begin:end]

old_rx = t + "struct dst_entry" + t + "*sk_rx_dst;" + nl
new_rx = t + "struct dst_entry __rcu" + t + "*sk_rx_dst;" + nl
old_mem = t + "long val = sk->sk_prot->sysctl_mem[index];" + nl
new_mem = t + "long val = READ_ONCE(sk->sk_prot->sysctl_mem[index]);" + nl
old_tx = timestamp_block(original, "/**\n * sock_tx_timestamp")
new_tx = timestamp_block(target, "/**\n * _sock_tx_timestamp")
frag_start = target.index("/* On 32bit arches, an skb frag is limited to 2^15 */")
frag_end = target.index("\n#endif\t/* _SOCK_H */", frag_start)
frag = target[frag_start:frag_end].rstrip("\n")
frag_anchor = "extern __u32 sysctl_rmem_default;" + nl
frag_new = frag_anchor + nl + frag + nl

for needle, label in [
    (new_rx, "target RCU receive-route annotation"),
    (new_mem, "target memory-limit READ_ONCE"),
    ("static inline void _sock_tx_timestamp", "target timestamp helper"),
    ("static inline void skb_setup_tx_timestamp", "target skb timestamp helper"),
    (frag, "target skb fragment order"),
]:
    count(target, needle, 1, label)
for needle, label in [
    (old_rx, "scaffold receive-route field"),
    (old_mem, "scaffold memory-limit load"),
    (old_tx, "scaffold timestamp helper"),
    (frag_anchor, "scaffold fragment insertion anchor"),
    (t + "u32" + t + t + t + "sk_tskey;", "scaffold timestamp key"),
]:
    count(original, needle, 1, label)

downstream = [
    ("u32 skc_oplus_pid;", 1, "Oplus modem socket field"),
    ("#define sk_oplus_pid", 1, "Oplus modem socket alias"),
    ("static inline void sk_pacing_shift_update(struct sock *sk, int val)", 1,
     "downstream pacing helper"),
    ("#define SOCKEV_SOCKET", 1, "SOCKEV notifier block"),
    ("int sockev_register_notify(struct notifier_block *nb);", 1,
     "SOCKEV registration API"),
    ("//Remove for [1357567],some AP doesn't send arp when it needs to send data to DUT",
     1, "downstream neighbour-confirm behavior"),
]
for needle, expected, label in downstream:
    count(original, needle, expected, label)
confirm_before = confirm_neigh_block(original)
Path(os.environ["DIAG"], "sock-confirm-neigh-scaffold.txt").write_text(confirm_before)

history = []
text = original
text = replace_once(text, old_rx, new_rx, "receive-route RCU annotation", history)
text = replace_once(text, old_mem, new_mem, "memory-limit READ_ONCE", history)
text = replace_once(text, old_tx, new_tx, "TX timestamp API", history)
text = replace_once(text, frag_anchor, frag_new, "skb fragment page-order macro", history)

def reverse(text, changes):
    for old, new, label in reversed(changes):
        count(text, new, 1, f"{label} reverse pattern")
        text = text.replace(new, old, 1)
    return text

if reverse(text, history) != original:
    raise SystemExit("socket-header resolver does not exactly reverse to scaffold")
for needle, expected, label in downstream:
    count(text, needle, expected, f"resolved {label}")
confirm_after = confirm_neigh_block(text)
if confirm_after != confirm_before:
    raise SystemExit("resolver changed downstream sock_confirm_neigh behavior")
Path(os.environ["DIAG"], "sock-confirm-neigh-resolved.txt").write_text(confirm_after)

for needle, label in [
    (new_rx, "receive-route RCU annotation"),
    (new_mem, "memory-limit READ_ONCE"),
    (new_tx, "TX timestamp API"),
    (frag, "skb fragment page-order macro"),
]:
    count(text, needle, 1, f"resolved {label}")
if "static inline void sock_tx_timestamp(const struct sock *sk," in text:
    raise SystemExit("legacy const TX timestamp helper remains")
if "static inline void sock_tx_timestamp(struct sock *sk," not in text:
    raise SystemExit("compatibility TX timestamp wrapper is absent")

path.write_text(text)
print("status=resolved")
print("android_socket_safety_sequences=4")
print("downstream_oplus_pacing_sockev_and_neighbour_paths_retained=yes")
print("target_timestamp_block_sha256=" +
      hashlib.sha256(new_tx.encode()).hexdigest())
PY

git diff --binary --full-index > "$DIAG/source.patch"
test -s "$DIAG/source.patch"
PATCH_SHA="$(sha256sum "$DIAG/source.patch" | awk '{print $1}')"
git diff --check
if git grep -nE '^(<<<<<<< .+|>>>>>>> .+|\|\|\|\|\|\|\| .+)$' -- "$OWNED" \
  > "$DIAG/conflict-markers.txt"; then
  cat "$DIAG/conflict-markers.txt"
  exit 1
else
  : > "$DIAG/conflict-markers.txt"
fi
python3 - "$OWNED" "$DIAG/sock-confirm-neigh-scaffold.txt" \
  "$DIAG/sock-confirm-neigh-resolved.txt" <<'PY' | tee "$DIAG/source-behavior.txt"
from pathlib import Path
import sys

t = "\t"
text = Path(sys.argv[1]).read_text()
before = Path(sys.argv[2]).read_text()
after = Path(sys.argv[3]).read_text()
assert before == after
assert text.count(t + "struct dst_entry __rcu" + t + "*sk_rx_dst;") == 1
assert text.count(t + "long val = READ_ONCE(sk->sk_prot->sysctl_mem[index]);") == 1
assert text.count("static inline void _sock_tx_timestamp") == 1
assert text.count("static inline void skb_setup_tx_timestamp") == 1
assert text.count("#define SKB_FRAG_PAGE_ORDER" + t + "get_order(32768)") == 1
assert text.count("static inline void sk_pacing_shift_update(struct sock *sk, int val)") == 1
assert text.count("#define SOCKEV_SOCKET") == 1
assert text.count("//Remove for [1357567],some AP doesn't send arp when it needs to send data to DUT") == 1
print("source_behavior_gates=PASS")
PY

git add -- "$OWNED"
test "$(git diff --cached --name-only)" = "$OWNED"
git commit -m 'lts: resolve socket timestamping API for 4.14.305'
SOURCE_COMMIT="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "$START_HEAD"
test "$(git diff-tree --no-commit-id --name-only -r "$SOURCE_COMMIT")" = "$OWNED"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file

ANDROID_ROOT="$RUNNER_TEMP/android-root"
KERNEL_WORKTREE="$ANDROID_ROOT/kernel/msm-4.14"
VENDOR_SOURCE="$RUNNER_TEMP/oneplus-sm8150-vendor-source"
OUT_DIR="$ANDROID_ROOT/out/h40-sock-header-targeted"
TOOLCHAIN_ROOT="$RUNNER_TEMP/miru-toolchains"
rm -rf "$ANDROID_ROOT" "$VENDOR_SOURCE" "$TOOLCHAIN_ROOT"
mkdir -p "$ANDROID_ROOT/kernel" "$ANDROID_ROOT/out" "$TOOLCHAIN_ROOT"
git worktree prune
git worktree add --detach "$KERNEL_WORKTREE" "$SOURCE_COMMIT"

git init -q "$VENDOR_SOURCE"
git -C "$VENDOR_SOURCE" remote add origin \
  https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git
git -C "$VENDOR_SOURCE" fetch -q --depth=1 --filter=blob:none origin "$VENDOR_SHA"
git -C "$VENDOR_SOURCE" checkout -q --detach FETCH_HEAD
test "$(git -C "$VENDOR_SOURCE" rev-parse HEAD)" = "$VENDOR_SHA"
mkdir -p "$ANDROID_ROOT/vendor"
rsync -a "$VENDOR_SOURCE/vendor/" "$ANDROID_ROOT/vendor/"
test -f "$KERNEL_WORKTREE/block/oplus_foreground_io_opt/Kconfig"

fetch_root() {
  local url="$1" commit="$2" dest="$3"
  git init -q "$dest"
  git -C "$dest" remote add origin "$url"
  git -C "$dest" fetch -q --depth=1 --filter=blob:none origin "$commit"
  git -C "$dest" checkout -q --detach FETCH_HEAD
  test "$(git -C "$dest" rev-parse HEAD)" = "$commit"
}
fetch_sparse() {
  local url="$1" commit="$2" dest="$3" sparse_path="$4"
  git init -q "$dest"
  git -C "$dest" remote add origin "$url"
  git -C "$dest" sparse-checkout init --cone
  git -C "$dest" sparse-checkout set "$sparse_path"
  git -C "$dest" fetch -q --depth=1 --filter=blob:none origin "$commit"
  git -C "$dest" checkout -q --detach FETCH_HEAD
  test "$(git -C "$dest" rev-parse HEAD)" = "$commit"
}
fetch_sparse \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
  252aba16f513a857bc923172f67b0e55e23de35f \
  "$TOOLCHAIN_ROOT/clang-repo" clang-r377782c
fetch_root \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 \
  606f80986096476912e04e5c2913685a8f2c3b65 "$TOOLCHAIN_ROOT/gcc64"
fetch_root \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 \
  b0c6a654327ca8796bed1e61dffcf523d04dceaa "$TOOLCHAIN_ROOT/gcc32"
fetch_sparse \
  https://android.googlesource.com/platform/prebuilts/build-tools \
  7322db1e1e4715fe217a27f721613e6be8438676 \
  "$TOOLCHAIN_ROOT/build-tools" linux-x86

CLANG_DIR="$TOOLCHAIN_ROOT/clang-repo/clang-r377782c"
GCC64_DIR="$TOOLCHAIN_ROOT/gcc64"
GCC32_DIR="$TOOLCHAIN_ROOT/gcc32"
AOSP_BUILD_TOOLS="$TOOLCHAIN_ROOT/build-tools/linux-x86"
printf '%s  %s\n' \
  6618ecab73b79a70b79263d2f477f669e564d81ca802112d2e5f93c74c6b22ca \
  "$CLANG_DIR/bin/clang" | sha256sum -c -
printf '%s  %s\n' \
  2a663de4ce3d702fe3f2a0de48cac366be676f850c2f5732d9cc2e4acb9335e2 \
  "$GCC64_DIR/bin/aarch64-linux-android-ld" | sha256sum -c -
printf '%s  %s\n' \
  2f78058a8549bc5c099dbea16d9f3dc571e072b1ade906c3539e419787b502dd \
  "$GCC32_DIR/bin/arm-linux-androideabi-as" | sha256sum -c -
printf '%s  %s\n' \
  5630a485d7c597d137fa462626213007e8865cf549677e1f727d131695ec830c \
  "$AOSP_BUILD_TOOLS/bin/py2-cmd" | sha256sum -c -

mkdir -p "$OUT_DIR"
cp "$KERNEL_WORKTREE/h40-repro/config/GM1911_11_H.40.config" "$OUT_DIR/.config"
sed -i 's/\r$//' "$OUT_DIR/.config"
CLANG="$CLANG_DIR/bin/clang"
CROSS64="$GCC64_DIR/bin/aarch64-linux-android-"
CROSS32="$GCC32_DIR/bin/arm-linux-androideabi-"
PYTHON2="$AOSP_BUILD_TOOLS/bin/py2-cmd"
export PATH="$AOSP_BUILD_TOOLS/bin:$CLANG_DIR/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"
export ARCH=arm64 SUBARCH=arm64
kernel_make() {
  make -C "$KERNEL_WORKTREE" "$@" \
    "O=$OUT_DIR" 'ARCH=arm64' 'TARGET_PRODUCT=msmnile' \
    'BRAND_SHOW_FLAG=oneplus' 'TARGET_BUILD_VARIANT=user' \
    "CROSS_COMPILE=$CROSS64" "CROSS_COMPILE_ARM32=$CROSS32" \
    "REAL_CC=$CLANG" 'CLANG_TRIPLE=aarch64-linux-gnu-' "PYTHON=$PYTHON2" \
    'HOSTCC=gcc' 'HOSTCXX=g++' 'LOCALVERSION=+'
}
kernel_make olddefconfig 2>&1 | tee "$DIAG/olddefconfig.log"
grep -Fq 'CONFIG_MODVERSIONS=y' "$OUT_DIR/.config"
grep -Fq 'CONFIG_NET=y' "$OUT_DIR/.config"
grep -Fq 'CONFIG_INET=y' "$OUT_DIR/.config"
cp "$OUT_DIR/.config" "$DIAG/resolved.config"
kernel_make -j4 V=0 "$TARGET_OBJECT" 2>&1 | tee "$DIAG/targeted-compile.log"
test -s "$OUT_DIR/$TARGET_OBJECT"
if grep -nE '(^|[[:space:]])(warning|error):' \
  "$DIAG/olddefconfig.log" "$DIAG/targeted-compile.log" \
  > "$DIAG/targeted-diagnostics.txt"; then
  cat "$DIAG/targeted-diagnostics.txt"
  exit 1
else
  : > "$DIAG/targeted-diagnostics.txt"
fi
{
  echo 'result=PASS'
  echo "source_commit=$SOURCE_COMMIT"
  echo "target_object=$TARGET_OBJECT"
  echo 'socket_core_enabled=yes'
  echo 'android_socket_safety_sequences=4'
  echo 'downstream_oplus_pacing_sockev_and_neighbour_paths_retained=yes'
  echo "compiler=$("$CLANG" --version | head -n1)"
} | tee "$DIAG/targeted-compile-summary.txt"

REVERT_WORKTREE="$RUNNER_TEMP/lts305-sock-header-revert"
rm -rf "$REVERT_WORKTREE"
git worktree add --detach "$REVERT_WORKTREE" "$SOURCE_COMMIT"
git -C "$REVERT_WORKTREE" config user.name 'Miru LTS Integration Bot'
git -C "$REVERT_WORKTREE" config user.email 'miru-lts-integration@users.noreply.github.com'
git -C "$REVERT_WORKTREE" revert --no-edit "$SOURCE_COMMIT" \
  > "$DIAG/revert.stdout" 2> "$DIAG/revert.stderr"
git -C "$REVERT_WORKTREE" diff --quiet "$SCAFFOLD" -- "$OWNED"
test "$(git -C "$REVERT_WORKTREE" rev-parse "HEAD:$OWNED")" = "$EXPECTED_SCAFFOLD_BLOB"
test "$(git -C "$REVERT_WORKTREE" rev-parse 'HEAD^{tree}')" = \
  "$(git rev-parse "$START_HEAD^{tree}")"
{
  echo 'result=PASS'
  echo "owning_commit=$SOURCE_COMMIT"
  echo "revert_commit=$(git -C "$REVERT_WORKTREE" rev-parse HEAD)"
  echo "restored_scaffold=$SCAFFOLD"
  echo "restored_paths=$OWNED"
  echo "restored_start_tree=$(git rev-parse "$START_HEAD^{tree}")"
} | tee "$DIAG/reversal-summary.txt"

TARGET_SOCK_COMMITS_CSV="$(awk -F $'\t' '{print $2}' "$DIAG/target-sock-provenance.tsv" |
  awk '!seen[$0]++' | paste -sd, -)"
TARGET_SOCK_PROVENANCE="$(tr '\n' ';' < "$DIAG/target-sock-provenance.tsv" | sed 's/;*$//')"
export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA TARGET_SOCK_COMMITS_CSV TARGET_SOCK_PROVENANCE TARGET_COMMIT \
  EXPECTED_SCAFFOLD_BLOB EXPECTED_TARGET_BLOB
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["LEDGER"])
text = path.read_text()
for old, new in {
    "- Semantically resolved conflicts: **28**": "- Semantically resolved conflicts: **29**",
    "- Remaining semantic conflicts: **5**": "- Remaining semantic conflicts: **4**",
}.items():
    if old not in text:
        raise SystemExit(f"missing ledger status: {old}")
    text = text.replace(old, new, 1)

source = os.environ["SOURCE_COMMIT"]
pattern = re.compile(
    r"^(\| 25 \| .*? \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$",
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit("missing unresolved socket-core manifest row 25")
replacement = match.group(1) + "resolved" + \
    f" | {chr(96)}{source}{chr(96)} | net/core/sock.o PASS | clean reversal PASS |"
text = text[:match.start()] + replacement + text[match.end():]

bt = chr(96)
record = f"""
### Socket core RCU and TX timestamp API union

- Owning source commit: {bt}{source}{bt}.
- Owned path: {bt}include/net/sock.h{bt}.
- Relevant Android Common commits: {bt}{os.environ['TARGET_SOCK_COMMITS_CSV']}{bt}, all target-reachable from {bt}{os.environ['TARGET_COMMIT']}{bt}.
- Provenance verification: {os.environ['TARGET_SOCK_PROVENANCE']}; each imported marker was checked in its own target-reachable diff, with the pre-existing {bt}sk_tskey{bt} storage recorded as the Android Common baseline.
- Android behavior imported: annotate the receive-route pointer for RCU, read protocol memory limits with {bt}READ_ONCE(){bt}, add the keyed TX-timestamp helper and skb setup wrapper, and define the 32-bit skb-fragment page order.
- Downstream intent retained: Oplus modem socket fields and aliases, the pacing-shift helper, SOCKEV notifier APIs, and the downstream neighbour-confirm behavior are byte-preserved and compiled with the union.
- Semantic decision: retain every downstream extension while importing the Android concurrency and timestamping API as an exact target-derived helper block.
- Scaffold blob: {bt}{os.environ['EXPECTED_SCAFFOLD_BLOB']}{bt}. Target blob: {bt}{os.environ['EXPECTED_TARGET_BLOB']}{bt}.
- Audited source patch SHA-256: {bt}{os.environ['PATCH_SHA']}{bt} using {bt}git diff --binary --full-index{bt}.
- Targeted compilation: **PASS** for {bt}net/core/sock.o{bt} using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android socket-safety and downstream-preservation gates: **PASS**.
- Clean reversal: **PASS**; reverting {bt}{source}{bt} restored {bt}include/net/sock.h{bt} exactly to scaffold {bt}{os.environ['SCAFFOLD']}{bt} and restored the complete pre-resolution integration tree.
- Validation workflow run: {bt}{os.environ.get('GITHUB_RUN_ID', 'unknown')}{bt}.
"""
if "### Socket core RCU and TX timestamp API union" in text:
    raise SystemExit("socket-core resolution record already exists")
path.write_text(text + record)
PY

git add -- "$LEDGER"
test "$(git diff --cached --name-only)" = "$LEDGER"
git commit -m 'docs: record socket core validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "$SOURCE_COMMIT"
{
  echo 'status=PASS'
  echo "start_head=$START_HEAD"
  echo "source_commit=$SOURCE_COMMIT"
  echo "documentation_head=$DOC_HEAD"
  echo "production_sha=$PRODUCTION_SHA"
  echo "scaffold=$SCAFFOLD"
  echo 'semantic_conflicts_resolved=29'
  echo 'semantic_conflicts_remaining=4'
} | tee "$DIAG/resolution-summary.txt"
git show --stat --oneline "$SOURCE_COMMIT" > "$DIAG/source-commit.txt"
git show --stat --oneline "$DOC_HEAD" > "$DIAG/documentation-commit.txt"
find "$DIAG" -type f -print0 | sort -z | xargs -0 sha256sum > "$DIAG/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/$PRODUCTION_BRANCH" | awk '{print $1}')" = "$PRODUCTION_SHA"
test "$(git ls-remote origin "refs/heads/$INTEGRATION_BRANCH" | awk '{print $1}')" = "$START_HEAD"
git push origin "$DOC_HEAD:refs/heads/$INTEGRATION_BRANCH"
