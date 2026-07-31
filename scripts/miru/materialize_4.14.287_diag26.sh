#!/usr/bin/env bash
set -Eeuo pipefail
set -x

: "${PRODUCTION_SHA:?}"
: "${SCAFFOLD_283_SHA:?}"
: "${SOURCE_291_SHA:?}"
: "${STABLE_287_SHA:?}"
: "${STABLE_291_SHA:?}"
: "${FDT_292_SHA:?}"
: "${TARGET_BRANCH:?}"

EVIDENCE="${GITHUB_WORKSPACE}/source-287-evidence"
mkdir -p "${EVIDENCE}"
trigger_sha="$(git rev-parse HEAD)"

# Immutable branch and target gates.
test "$(git ls-remote origin refs/heads/miru-h40 | awk '{print $1}')" = "${PRODUCTION_SHA}"
test -z "$(git ls-remote origin "refs/heads/${TARGET_BRANCH}")"

git fetch --no-tags origin \
  "${PRODUCTION_SHA}" "${SCAFFOLD_283_SHA}" "${SOURCE_291_SHA}"
if ! git remote get-url android-common >/dev/null 2>&1; then
  git remote add android-common https://github.com/aosp-mirror/kernel_common.git
fi
git fetch --no-tags android-common \
  "${STABLE_287_SHA}" "${STABLE_291_SHA}" "${FDT_292_SHA}"

# Proven ancestry and endpoint identity.
test "$(git rev-parse "${SCAFFOLD_283_SHA}^1")" = "${PRODUCTION_SHA}"
test "$(git rev-parse "${SOURCE_291_SHA}^1")" = "${SCAFFOLD_283_SHA}"
test "$(git rev-parse "${SOURCE_291_SHA}^2")" = "${STABLE_291_SHA}"
git merge-base --is-ancestor "${STABLE_287_SHA}" "${STABLE_291_SHA}"
! git merge-base --is-ancestor "${FDT_292_SHA}" "${STABLE_287_SHA}"
test "$(git show -s --format=%s "${STABLE_287_SHA}")" = 'Linux 4.14.287'
test "$(git show "${STABLE_287_SHA}:Makefile" | sed -n 's/^SUBLEVEL = //p' | head -n1)" = 287
test "$(git show -s --format=%s "${STABLE_291_SHA}")" = 'Linux 4.14.291'

ref_wt="${RUNNER_TEMP}/miru-291-downgraded-to-287"
merge_wt="${RUNNER_TEMP}/miru-287-source"
rm -rf "${ref_wt}" "${merge_wt}"

# Mechanically downgrade the audited 4.14.291 source tree to 4.14.287.
git worktree add --detach "${ref_wt}" "${SOURCE_291_SHA}"
git -C "${ref_wt}" config user.name github-actions[bot]
git -C "${ref_wt}" config user.email 41898282+github-actions[bot]@users.noreply.github.com

git diff --binary --full-index "${STABLE_291_SHA}" "${STABLE_287_SHA}" -- \
  > "${EVIDENCE}/stable-291-to-287.patch"
sha256sum "${EVIDENCE}/stable-291-to-287.patch" \
  > "${EVIDENCE}/stable-291-to-287.patch.sha256"
git diff --name-only "${STABLE_287_SHA}" "${STABLE_291_SHA}" | sort -u \
  > "${EVIDENCE}/post-287-stable-paths.txt"

set +e
git -C "${ref_wt}" apply --3way --index \
  "${EVIDENCE}/stable-291-to-287.patch" \
  > "${EVIDENCE}/source-downgrade-apply.log" 2>&1
downgrade_rc=$?
set -e
git -C "${ref_wt}" diff --name-only --diff-filter=U | sort -u \
  > "${EVIDENCE}/source-downgrade-conflicts.txt"
cat > "${EVIDENCE}/expected-source-downgrade-conflicts.txt" <<'EOF'
drivers/usb/host/xhci.c
drivers/usb/host/xhci.h
net/ipv4/tcp_output.c
EOF
test "${downgrade_rc}" = 1
diff -u "${EVIDENCE}/expected-source-downgrade-conflicts.txt" \
  "${EVIDENCE}/source-downgrade-conflicts.txt"

# Retain Miru/Qualcomm vendor code in the three overlap files, then remove only
# the Linux 4.14.288-4.14.291 semantic changes.
git -C "${ref_wt}" checkout --ours -- \
  drivers/usb/host/xhci.c drivers/usb/host/xhci.h net/ipv4/tcp_output.c

python3 - "${ref_wt}/drivers/usb/host/xhci.c" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()

def one(old, new):
    global s
    if s.count(old) != 1:
        raise SystemExit(f'unexpected xhci.c replacement count {s.count(old)} for {old!r}')
    s = s.replace(old, new, 1)

one('int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, u64 timeout_us)',
    'int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, int usec)')
one('\t\t\t\t\t1, timeout_us);', '\t\t\t\t\t1, usec);')
one('int xhci_reset(struct xhci_hcd *xhci, u64 timeout_us)',
    'int xhci_reset(struct xhci_hcd *xhci)')
one('\tret = xhci_handshake_check_state(xhci, &xhci->op_regs->command,\n\t\t\tCMD_RESET, 0, timeout_us);',
    '\tret = xhci_handshake_check_state(xhci, &xhci->op_regs->command,\n\t\t\tCMD_RESET, 0, 10 * 1000 * 1000);')
one('\tret = xhci_handshake(&xhci->op_regs->status,\n\t\t\tSTS_CNR, 0, timeout_us);',
    '\tret = xhci_handshake(&xhci->op_regs->status,\n\t\t\tSTS_CNR, 0, 10 * 1000 * 1000);')
if s.count('\txhci_reset(xhci, XHCI_RESET_SHORT_USEC);') != 2:
    raise SystemExit('unexpected short-reset call count')
s = s.replace('\txhci_reset(xhci, XHCI_RESET_SHORT_USEC);', '\txhci_reset(xhci);')
if s.count('retval = xhci_reset(xhci, XHCI_RESET_LONG_USEC);') != 2:
    raise SystemExit('unexpected long-reset call count')
s = s.replace('retval = xhci_reset(xhci, XHCI_RESET_LONG_USEC);',
              'retval = xhci_reset(xhci);')
one('\t\tretval = xhci_reset(xhci);\n\t\tspin_unlock_irq(&xhci->lock);\n\t\tif (retval)\n\t\t\treturn retval;',
    '\t\txhci_reset(xhci);\n\t\tspin_unlock_irq(&xhci->lock);')
p.write_text(s)
PY

python3 - "${ref_wt}/drivers/usb/host/xhci.h" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()

def one(old, new):
    global s
    if s.count(old) != 1:
        raise SystemExit(f'unexpected xhci.h replacement count {s.count(old)} for {old!r}')
    s = s.replace(old, new, 1)

one('#define XHCI_RESET_LONG_USEC\t\t(10 * 1000 * 1000)\n#define XHCI_RESET_SHORT_USEC\t\t(250 * 1000)\n\n', '')
one('int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, u64 timeout_us);',
    'int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, int usec);')
one('int xhci_reset(struct xhci_hcd *xhci, u64 timeout_us);',
    'int xhci_reset(struct xhci_hcd *xhci);')
p.write_text(s)
PY

python3 - "${ref_wt}/net/ipv4/tcp_output.c" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()

def one(old, new):
    global s
    if s.count(old) != 1:
        raise SystemExit(f'unexpected tcp_output.c replacement count {s.count(old)} for {old!r}')
    s = s.replace(old, new, 1)

one('interval = READ_ONCE(net->ipv4.sysctl_tcp_probe_interval);',
    'interval = net->ipv4.sysctl_tcp_probe_interval;')
one('interval < READ_ONCE(net->ipv4.sysctl_tcp_probe_threshold)',
    'interval < net->ipv4.sysctl_tcp_probe_threshold')
one('\tint avail_wnd;\n', '')
one('\tavail_wnd = tcp_wnd_end(tp) - TCP_SKB_CB(skb)->seq;\n\n', '')
one('our retransmit of one segment serves as a zero window probe.',
    'our retransmit serves as a zero window probe.')
one('\tif (avail_wnd <= 0) {\n\t\tif (TCP_SKB_CB(skb)->seq != tp->snd_una)\n\t\t\treturn -EAGAIN;\n\t\tavail_wnd = cur_mss;\n\t}\n',
    '\tif (!before(TCP_SKB_CB(skb)->seq, tcp_wnd_end(tp)) &&\n\t    TCP_SKB_CB(skb)->seq != tp->snd_una)\n\t\treturn -EAGAIN;\n')
one('\tlen = cur_mss * segs;\n\tif (len > avail_wnd) {\n\t\tlen = rounddown(avail_wnd, cur_mss);\n\t\tif (!len)\n\t\t\tlen = avail_wnd;\n\t}\n',
    '\tlen = cur_mss * segs;\n')
one('\t\tavail_wnd = min_t(int, avail_wnd, cur_mss);\n\t\tif (skb->len < avail_wnd)\n\t\t\ttcp_retrans_try_collapse(sk, skb, avail_wnd);',
    '\t\tif (skb->len < cur_mss)\n\t\t\ttcp_retrans_try_collapse(sk, skb, cur_mss);')
one('\tint delta, amt;\n\n\tdelta = size - sk->sk_forward_alloc;\n\tif (delta <= 0)\n\t\treturn;\n\tamt = sk_mem_pages(delta);',
    '\tint amt;\n\n\tif (size <= sk->sk_forward_alloc)\n\t\treturn;\n\tamt = sk_mem_pages(size);')
p.write_text(s)
PY

git -C "${ref_wt}" add -- \
  drivers/usb/host/xhci.c drivers/usb/host/xhci.h net/ipv4/tcp_output.c

test -z "$(git -C "${ref_wt}" diff --name-only --diff-filter=U)"
test -z "$(git -C "${ref_wt}" ls-files -u)"
git -C "${ref_wt}" diff --check --cached
test "$(sed -n 's/^SUBLEVEL = //p' "${ref_wt}/Makefile" | head -n1)" = 287
! grep -Fq 'XHCI_RESET_LONG_USEC' "${ref_wt}/drivers/usb/host/xhci.h"
! grep -Fq 'XHCI_RESET_SHORT_USEC' "${ref_wt}/drivers/usb/host/xhci.h"
grep -Fq 'xhci_handshake_check_state(xhci, &xhci->op_regs->command' \
  "${ref_wt}/drivers/usb/host/xhci.c"
! grep -Fq 'READ_ONCE(net->ipv4.sysctl_tcp_probe_' \
  "${ref_wt}/net/ipv4/tcp_output.c"
! grep -Fq 'avail_wnd' "${ref_wt}/net/ipv4/tcp_output.c"
grep -Fq 'OPLUS_FEATURE_MODEM_DATA_NWPOWER' "${ref_wt}/net/ipv4/tcp_output.c"

# Perform the real merge from the phone-confirmed 4.14.283 source scaffold.
git worktree add --detach "${merge_wt}" "${SCAFFOLD_283_SHA}"
git -C "${merge_wt}" config user.name github-actions[bot]
git -C "${merge_wt}" config user.email 41898282+github-actions[bot]@users.noreply.github.com
set +e
git -C "${merge_wt}" merge --no-commit --no-ff "${STABLE_287_SHA}" \
  > "${EVIDENCE}/miru-283-to-287-merge.log" 2>&1
merge_rc=$?
set -e
test "${merge_rc}" = 0 -o "${merge_rc}" = 1
git -C "${merge_wt}" diff --name-only --diff-filter=U | sort -u \
  > "${EVIDENCE}/miru-287-conflicts.txt"

while IFS= read -r rel; do
  [ -n "${rel}" ] || continue
  if [ -e "${ref_wt}/${rel}" ] || [ -L "${ref_wt}/${rel}" ]; then
    mkdir -p "$(dirname "${merge_wt}/${rel}")"
    rm -rf "${merge_wt:?}/${rel}"
    cp -a "${ref_wt}/${rel}" "${merge_wt}/${rel}"
    git -C "${merge_wt}" add -- "${rel}"
  else
    git -C "${merge_wt}" rm -f --ignore-unmatch -- "${rel}"
  fi
done < "${EVIDENCE}/miru-287-conflicts.txt"

test -z "$(git -C "${merge_wt}" diff --name-only --diff-filter=U)"
test -z "$(git -C "${merge_wt}" ls-files -u)"
git -C "${merge_wt}" diff --check

# The real merge tree must equal the mechanically downgraded audited source tree.
git -C "${ref_wt}" write-tree > "${EVIDENCE}/downgraded-reference-tree.txt"
git -C "${merge_wt}" write-tree > "${EVIDENCE}/actual-merge-tree.txt"
if ! cmp -s "${EVIDENCE}/downgraded-reference-tree.txt" "${EVIDENCE}/actual-merge-tree.txt"; then
  git diff --name-status \
    "$(cat "${EVIDENCE}/downgraded-reference-tree.txt")" \
    "$(cat "${EVIDENCE}/actual-merge-tree.txt")" \
    > "${EVIDENCE}/tree-mismatch.txt"
  {
    echo result=FAIL
    echo stage=tree-equivalence
    echo "mismatch_count=$(wc -l < "${EVIDENCE}/tree-mismatch.txt")"
  } | tee "${EVIDENCE}/SUMMARY.txt"
  cat "${EVIDENCE}/tree-mismatch.txt" >&2
  exit 1
fi

# Required Miru/vendor semantics carried across the midpoint.
test "$(sed -n 's/^SUBLEVEL = //p' "${merge_wt}/Makefile" | head -n1)" = 287
grep -Fq 'int of_fdt_get_ddrtype(void)' "${merge_wt}/drivers/of/fdt.c"
grep -Fq '"ddr_device_type", &len' "${merge_wt}/drivers/of/fdt.c"
grep -Fq 'extern int of_fdt_get_ddrtype(void);' "${merge_wt}/include/linux/of_fdt.h"
grep -Fq 'struct notifier_block' "${merge_wt}/lib/vsprintf.c"
grep -Fq 'register_random_ready_notifier' "${merge_wt}/lib/vsprintf.c"
grep -Fq 'CHACHA20_KEY_SIZE' "${merge_wt}/include/crypto/chacha.h"
grep -Fq 'void *dt_virt = fixmap_remap_fdt(dt_phys);' \
  "${merge_wt}/arch/arm64/kernel/setup.c"
! grep -Fq 'fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL)' \
  "${merge_wt}/arch/arm64/kernel/setup.c"
if git -C "${merge_wt}" grep -nE '^(<<<<<<< .+|>>>>>>> .+)$' -- . \
    ':!Documentation' > "${EVIDENCE}/source-conflict-markers.txt"; then
  cat "${EVIDENCE}/source-conflict-markers.txt" >&2
  exit 1
fi

export GIT_AUTHOR_DATE='2026-07-31T14:30:00Z'
export GIT_COMMITTER_DATE='2026-07-31T14:30:00Z'
git -C "${merge_wt}" commit \
  -m 'Merge complete Linux 4.14.287 after boot-confirmed 4.14.283 diagnostic'
source_sha="$(git -C "${merge_wt}" rev-parse HEAD)"
source_tree="$(git -C "${merge_wt}" rev-parse HEAD^{tree})"

test "$(git -C "${merge_wt}" rev-parse HEAD^1)" = "${SCAFFOLD_283_SHA}"
test "$(git -C "${merge_wt}" rev-parse HEAD^2)" = "${STABLE_287_SHA}"
git -C "${merge_wt}" merge-base --is-ancestor "${PRODUCTION_SHA}" HEAD
git -C "${merge_wt}" merge-base --is-ancestor "${STABLE_287_SHA}" HEAD
! git -C "${merge_wt}" merge-base --is-ancestor "${FDT_292_SHA}" HEAD

git -C "${merge_wt}" diff-tree --no-commit-id --name-only -r \
  "${SCAFFOLD_283_SHA}" HEAD | sort -u \
  > "${EVIDENCE}/source-delta-from-283.txt"

{
  echo result=PASS
  echo "trigger_sha=${trigger_sha}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "source_283_scaffold=${SCAFFOLD_283_SHA}"
  echo "audited_source_291=${SOURCE_291_SHA}"
  echo "stable_287=${STABLE_287_SHA}"
  echo "stable_291=${STABLE_291_SHA}"
  echo "excluded_fdt_292=${FDT_292_SHA}"
  echo "source_287_sha=${source_sha}"
  echo "source_287_tree=${source_tree}"
  echo "merge_conflict_count=$(wc -l < "${EVIDENCE}/miru-287-conflicts.txt")"
  echo "post_287_stable_path_count=$(wc -l < "${EVIDENCE}/post-287-stable-paths.txt")"
  echo "fdt_blob=$(git -C "${merge_wt}" hash-object drivers/of/fdt.c)"
  echo "vsprintf_blob=$(git -C "${merge_wt}" hash-object lib/vsprintf.c)"
  echo "chacha_header_blob=$(git -C "${merge_wt}" hash-object include/crypto/chacha.h)"
  echo "xhci_c_blob=$(git -C "${merge_wt}" hash-object drivers/usb/host/xhci.c)"
  echo "xhci_h_blob=$(git -C "${merge_wt}" hash-object drivers/usb/host/xhci.h)"
  echo "tcp_output_blob=$(git -C "${merge_wt}" hash-object net/ipv4/tcp_output.c)"
  echo raw_extcon_blob=$(git -C "${merge_wt}" hash-object drivers/extcon/extcon.c)
  echo early_random_blob=$(git -C "${merge_wt}" hash-object drivers/soc/qcom/early_random.c)
} | tee "${EVIDENCE}/SUMMARY.txt"
sha256sum "${EVIDENCE}"/* > "${EVIDENCE}/SHA256SUMS"

git -C "${merge_wt}" push origin "HEAD:refs/heads/${TARGET_BRANCH}"
test "$(git ls-remote origin "refs/heads/${TARGET_BRANCH}" | awk '{print $1}')" = "${source_sha}"
