#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_COMMON_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=0f0e9a1bf3368bea8490657ad32ffdbee15f0c23
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
OWNED=net/netfilter/nf_conntrack_irc.c
TARGET_OBJECT=net/netfilter/nf_conntrack_irc.o
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
EXPECTED_PREVIOUS_BLOB=5523acce9d6993dc71e467bbdf7b718ab2b25bf7
EXPECTED_SCAFFOLD_BLOB=b637e37bb85f35224f1b3ef452c30fa378d5e64f
EXPECTED_TARGET_BLOB=27e2f9785e5f4f2cc6ba1459ab0e425811b96165
DIAG=lts305-irc-resolution

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

TARGET_DCC_PARSE_COMMIT="$(find_target_commit $'+\t/* Skip any whitespace */')"
TARGET_DCC_PORT_COMMIT="$(find_target_commit $'+\t\t\t    dcc_port == 0) {')"
for sha in "$TARGET_DCC_PARSE_COMMIT" "$TARGET_DCC_PORT_COMMIT"; do
  git merge-base --is-ancestor "$sha" "$TARGET_COMMIT"
done
{
  printf 'dcc-message-framing\t%s\n' "$TARGET_DCC_PARSE_COMMIT"
  printf 'dcc-tuple-port-validation\t%s\n' "$TARGET_DCC_PORT_COMMIT"
} > "$DIAG/target-irc-provenance.tsv"
while IFS=$'\t' read -r label sha; do
  git show -s --format=fuller "$sha" > "$DIAG/target-$label-commit.txt"
  git show --format= --unified=0 "$sha" -- "$OWNED" > "$DIAG/target-$label.patch"
done < "$DIAG/target-irc-provenance.tsv"

if ! git diff --quiet "$SCAFFOLD" -- "$OWNED"; then
  grep -Fq -- '- Semantically resolved conflicts: **30**' "$LEDGER"
  grep -Fq -- '- Remaining semantic conflicts: **3**' "$LEDGER"
  grep -Fq '### IRC DCC parser safety union' "$LEDGER"
  {
    echo 'status=already-resolved'
    echo "head=$START_HEAD"
    echo "production=$PRODUCTION_SHA"
  } | tee "$DIAG/already-resolved.txt"
  find "$DIAG" -type f -print0 | sort -z | xargs -0 sha256sum > "$DIAG/SHA256SUMS"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **29**' "$LEDGER"
grep -Fq -- '- Remaining semantic conflicts: **4**' "$LEDGER"
git diff --quiet "$SCAFFOLD" -- "$OWNED"
test "$(git rev-parse "$PREVIOUS_COMMON_TARGET:$OWNED")" = "$EXPECTED_PREVIOUS_BLOB"
test "$(git rev-parse "$SCAFFOLD:$OWNED")" = "$EXPECTED_SCAFFOLD_BLOB"
test "$(git rev-parse "HEAD:$OWNED")" = "$EXPECTED_SCAFFOLD_BLOB"
test "$(git rev-parse "$TARGET_COMMIT:$OWNED")" = "$EXPECTED_TARGET_BLOB"
git show "$TARGET_COMMIT:$OWNED" > "$DIAG/target-nf_conntrack_irc.c"

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

def indent_one(text):
    return nl.join(t + line if line else line for line in text.split(nl))

def section(text, start_marker, end_marker):
    start = text.index(start_marker)
    end = text.index(end_marker, start)
    return text[start:end]

for needle, label in [
    ("/* Skip any whitespace */", "target whitespace gate"),
    ('strncasecmp("PRIVMSG ", data, 8)', "target PRIVMSG gate"),
    ('memcmp(data, " :", 2)', "target DCC message delimiter"),
    ("dcc_port == 0", "target zero-port rejection"),
    ("ct->tuplehash[!dir].tuple.dst.u3.ip", "target peer-tuple validation"),
]:
    count(target, needle, 1, label)

downstream_sections = {
    "client-info": section(original, "struct irc_client_info {", "static int parse_dcc"),
    "mangle-ip": section(original, "static bool mangle_ip", "static int handle_nickname"),
    "nickname-handler": section(original, "static int handle_nickname",
                                "static int help"),
}
for label, body in downstream_sections.items():
    Path(os.environ["DIAG"], f"downstream-{label}-scaffold.txt").write_text(body)
for needle, expected, label in [
    ("/* If packet is coming from IRC server", 1, "downstream server parser"),
    ('" MOTD "', 1, "downstream MOTD parser"),
    ('"NICK :"', 1, "downstream server NICK parser"),
    ('"NICK "', 1, "downstream client NICK parser"),
    ('"QUIT :"', 1, "downstream client QUIT parser"),
    ("static bool mangle_ip", 1, "downstream NAT mangle helper"),
    ("static int handle_nickname", 1, "downstream nickname helper"),
    ("struct irc_client_info {", 1, "downstream client-list type"),
]:
    count(original, needle, expected, label)

skip = target.index(t + "/* Skip any whitespace */")
target_prefix_start = target.rfind(t + "data = ib_ptr;", 0, skip)
target_prefix_end = target.index(t + t + "iph = ip_hdr(skb);", skip)
if target_prefix_start < 0 or target_prefix_end < 0:
    raise SystemExit("cannot isolate target DCC parser framing")
new_prefix = indent_one(target[target_prefix_start:target_prefix_end])
prefix_anchor = t * 2 + "data_limit = ib_ptr + skb->len - dataoff;" + nl + nl
count(new_prefix, prefix_anchor, 1, "target parser data-limit anchor")
new_prefix = new_prefix.replace(
    prefix_anchor,
    prefix_anchor + t * 2 + "for_print = NULL;" + nl + nl,
    1,
)
privmsg_advance = t * 3 + "data += 8;" + nl
count(new_prefix, privmsg_advance, 1, "target parser PRIVMSG advance")
new_prefix = new_prefix.replace(
    privmsg_advance,
    privmsg_advance + t * 3 + "for_print = data;" + nl,
    1,
)

history = []
text = original
old_prefix_start = text.index(t * 2 + '/* strlen("\\1DCC SENT')
old_prefix_end = text.index(t * 3 + "iph = ip_hdr(skb);", old_prefix_start)
old_prefix = text[old_prefix_start:old_prefix_end]
text = replace_once(text, old_prefix, new_prefix,
                    "target DCC message framing", history)

target_comment_start = target.index(t * 3 + "/* we have at least",
                                    target.index("for (i = 0;"))
target_comment_end = target.index(t * 3 + "if (parse_dcc",
                                  target_comment_start)
new_comment = indent_one(target[target_comment_start:target_comment_end])
old_comment_start = text.index(t * 4 + "/* we have at least",
                               text.index("for (i = 0;"))
old_comment_end = text.index(t * 4 + "if (parse_dcc", old_comment_start)
old_comment = text[old_comment_start:old_comment_end]
text = replace_once(text, old_comment, new_comment,
                    "target DCC length accounting", history)

old_tuple_check = (
    t * 4 + "if (tuple->src.u3.ip != dcc_ip &&" + nl +
    t * 4 + "    tuple->dst.u3.ip != dcc_ip) {" + nl
)
new_tuple_check = (
    t * 4 + "if ((tuple->src.u3.ip != dcc_ip &&" + nl +
    t * 4 + "     ct->tuplehash[!dir].tuple.dst.u3.ip != dcc_ip) ||" + nl +
    t * 4 + "    dcc_port == 0) {" + nl
)
text = replace_once(text, old_tuple_check, new_tuple_check,
                    "target DCC tuple and port validation", history)

nat_hook = text.index(t * 4 + "nf_nat_irc = rcu_dereference(nf_nat_irc_hook);")
mangle_start = text.index(t * 4 + "tuple = &ct->tuplehash[dir].tuple;",
                          nat_hook)
mangle_end = text.index(t * 4 + "if (mangle &&", mangle_start)
old_mangle_handoff = text[mangle_start:mangle_end]
new_mangle_handoff = (
    t * 4 + "if (for_print)" + nl +
    t * 5 + "mangle = mangle_ip(ct, dir, for_print);" + nl
)
text = replace_once(text, old_mangle_handoff, new_mangle_handoff,
                    "downstream nickname mangle handoff", history)

def reverse(text, changes):
    for old, new, label in reversed(changes):
        count(text, new, 1, f"{label} reverse pattern")
        text = text.replace(new, old, 1)
    return text

if reverse(text, history) != original:
    raise SystemExit("IRC resolver does not exactly reverse to scaffold")
for label, body in downstream_sections.items():
    after = section(text,
                    {
                        "client-info": "struct irc_client_info {",
                        "mangle-ip": "static bool mangle_ip",
                        "nickname-handler": "static int handle_nickname",
                    }[label],
                    {
                        "client-info": "static int parse_dcc",
                        "mangle-ip": "static int handle_nickname",
                        "nickname-handler": "static int help",
                    }[label])
    if after != body:
        raise SystemExit(f"resolver changed downstream {label}")
    Path(os.environ["DIAG"], f"downstream-{label}-resolved.txt").write_text(after)

for needle, label in [
    ("/* Skip any whitespace */", "whitespace gate"),
    ('strncasecmp("PRIVMSG ", data, 8)', "PRIVMSG gate"),
    ('memcmp(data, " :", 2)', "DCC message delimiter"),
    ("dcc_port == 0", "zero-port rejection"),
    ("ct->tuplehash[!dir].tuple.dst.u3.ip", "peer-tuple validation"),
    ("for_print = data;", "downstream nickname handoff"),
]:
    count(text, needle, 1, f"resolved {label}")
if "(19 + MINMATCHLEN)" in text:
    raise SystemExit("legacy DCC framing bound remains")

path.write_text(text)
print("status=resolved")
print("android_irc_safety_sequences=3")
print("downstream_client_tracking_and_nat_mangle_retained=yes")
print("target_dcc_framing_sha256=" +
      hashlib.sha256(new_prefix.encode()).hexdigest())
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
python3 - "$OWNED" "$DIAG" <<'PY' | tee "$DIAG/source-behavior.txt"
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
diag = Path(sys.argv[2])
for label in ("client-info", "mangle-ip", "nickname-handler"):
    assert (diag / f"downstream-{label}-scaffold.txt").read_text() == \
           (diag / f"downstream-{label}-resolved.txt").read_text()
for needle in (
    "/* Skip any whitespace */",
    'strncasecmp("PRIVMSG ", data, 8)',
    'memcmp(data, " :", 2)',
    'memcmp(data, "\\1DCC ", 5)',
    "dcc_port == 0",
    "ct->tuplehash[!dir].tuple.dst.u3.ip",
    "static bool mangle_ip",
    "static int handle_nickname",
    '" MOTD "',
    '"NICK :"',
    '"QUIT :"',
):
    assert needle in text, needle
assert "(19 + MINMATCHLEN)" not in text
print("source_behavior_gates=PASS")
PY

git add -- "$OWNED"
test "$(git diff --cached --name-only)" = "$OWNED"
git commit -m 'lts: harden IRC DCC parsing for 4.14.305'
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
OUT_DIR="$ANDROID_ROOT/out/h40-irc-targeted"
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
grep -Eq '^CONFIG_NF_CONNTRACK_IRC=[ym]$' "$OUT_DIR/.config"
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
  echo 'irc_conntrack_enabled=yes'
  echo 'android_irc_safety_sequences=3'
  echo 'downstream_client_tracking_and_nat_mangle_retained=yes'
  echo "compiler=$("$CLANG" --version | head -n1)"
} | tee "$DIAG/targeted-compile-summary.txt"

REVERT_WORKTREE="$RUNNER_TEMP/lts305-irc-revert"
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

TARGET_IRC_COMMITS_CSV="$(awk -F $'\t' '{print $2}' "$DIAG/target-irc-provenance.tsv" |
  awk '!seen[$0]++' | paste -sd, -)"
TARGET_IRC_PROVENANCE="$(tr '\n' ';' < "$DIAG/target-irc-provenance.tsv" | sed 's/;*$//')"
export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA TARGET_IRC_COMMITS_CSV TARGET_IRC_PROVENANCE TARGET_COMMIT \
  EXPECTED_SCAFFOLD_BLOB EXPECTED_TARGET_BLOB
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["LEDGER"])
text = path.read_text()
for old, new in {
    "- Semantically resolved conflicts: **29**": "- Semantically resolved conflicts: **30**",
    "- Remaining semantic conflicts: **4**": "- Remaining semantic conflicts: **3**",
}.items():
    if old not in text:
        raise SystemExit(f"missing ledger status: {old}")
    text = text.replace(old, new, 1)

source = os.environ["SOURCE_COMMIT"]
pattern = re.compile(
    r"^(\| 33 \| .*? \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$",
    re.M,
)
match = pattern.search(text)
if not match:
    raise SystemExit("missing unresolved IRC manifest row 33")
replacement = match.group(1) + "resolved" + \
    f" | {chr(96)}{source}{chr(96)} | nf_conntrack_irc.o PASS | clean reversal PASS |"
text = text[:match.start()] + replacement + text[match.end():]

bt = chr(96)
record = f"""
### IRC DCC parser safety union

- Owning source commit: {bt}{source}{bt}.
- Owned path: {bt}net/netfilter/nf_conntrack_irc.c{bt}.
- Relevant Android Common commits: {bt}{os.environ['TARGET_IRC_COMMITS_CSV']}{bt}, all target-reachable from {bt}{os.environ['TARGET_COMMIT']}{bt}.
- Provenance verification: {os.environ['TARGET_IRC_PROVENANCE']}; each imported parser and validation marker was checked as an exact added line in its target-reachable diff.
- Android behavior imported: restrict DCC recognition to the IRC message framing, skip leading whitespace, require the accepted {bt}PRIVMSG{bt} form when present, validate the peer tuple, and reject DCC port zero before creating an expectation.
- Downstream intent retained: Miru's IRC client list, nickname and MOTD transitions, client disconnect handling, and NAT mangle policy remain present. The parser passes the already-validated nickname position to the unchanged downstream mangle helper.
- Semantic decision: apply Android's DCC parsing safety checks before downstream expectation and NAT policy; all client-tracking helpers are byte-preserved.
- Scaffold blob: {bt}{os.environ['EXPECTED_SCAFFOLD_BLOB']}{bt}. Target blob: {bt}{os.environ['EXPECTED_TARGET_BLOB']}{bt}.
- Audited source patch SHA-256: {bt}{os.environ['PATCH_SHA']}{bt} using {bt}git diff --binary --full-index{bt}.
- Targeted compilation: **PASS** for {bt}net/netfilter/nf_conntrack_irc.o{bt} using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android IRC safety and downstream-preservation gates: **PASS**.
- Clean reversal: **PASS**; reverting {bt}{source}{bt} restored {bt}net/netfilter/nf_conntrack_irc.c{bt} exactly to scaffold {bt}{os.environ['SCAFFOLD']}{bt} and restored the complete pre-resolution integration tree.
- Validation workflow run: {bt}{os.environ.get('GITHUB_RUN_ID', 'unknown')}{bt}.
"""
if "### IRC DCC parser safety union" in text:
    raise SystemExit("IRC resolution record already exists")
path.write_text(text + record)
PY

git add -- "$LEDGER"
test "$(git diff --cached --name-only)" = "$LEDGER"
git commit -m 'docs: record IRC parser validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "$SOURCE_COMMIT"
{
  echo 'status=PASS'
  echo "start_head=$START_HEAD"
  echo "source_commit=$SOURCE_COMMIT"
  echo "documentation_head=$DOC_HEAD"
  echo "production_sha=$PRODUCTION_SHA"
  echo "scaffold=$SCAFFOLD"
  echo 'semantic_conflicts_resolved=30'
  echo 'semantic_conflicts_remaining=3'
} | tee "$DIAG/resolution-summary.txt"
git show --stat --oneline "$SOURCE_COMMIT" > "$DIAG/source-commit.txt"
git show --stat --oneline "$DOC_HEAD" > "$DIAG/documentation-commit.txt"
find "$DIAG" -type f -print0 | sort -z | xargs -0 sha256sum > "$DIAG/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/$PRODUCTION_BRANCH" | awk '{print $1}')" = "$PRODUCTION_SHA"
test "$(git ls-remote origin "refs/heads/$INTEGRATION_BRANCH" | awk '{print $1}')" = "$START_HEAD"
git push origin "$DOC_HEAD:refs/heads/$INTEGRATION_BRANCH"
