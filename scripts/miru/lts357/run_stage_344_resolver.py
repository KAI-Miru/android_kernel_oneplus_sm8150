#!/usr/bin/env python3
"""Run the stage-344 resolver with a robust reviewed xt_owner adaptation.

The original resolver performed several independent slices of owner_mt(). The
second slice was based on the first UID/GID block in the source file, which can
belong to owner_check(), and therefore discarded the lock inserted later in
owner_mt(). Replace that fragile resolver section in memory with one complete
reviewed tail rooted at owner_mt()'s existing OPlus socket-selection path.
"""
from pathlib import Path

resolver = Path(__file__).with_name("resolve_stage_344.py")
source = resolver.read_text()
start_marker = "# Preserve OPlus LOCAL_IN owner matching and socket recovery."
end_marker = "write(xt_path, xt)\n"
start = source.index(start_marker)
end = source.index(end_marker, start) + len(end_marker)
replacement = r'''# Preserve OPlus LOCAL_IN owner matching and socket recovery. Replace only
# owner_mt()'s generic credentials tail with the OpenELA locked implementation;
# this avoids matching owner_check()'s earlier UID/GID validation blocks.
xt_path = "net/netfilter/xt_owner.c"
xt = read(xt_path)
tail_start_marker = "\tfilp = sk->sk_socket->file;\n"
function_end_marker = "\n}\n\nstatic struct xt_match owner_mt_reg"
owner_start = xt.index("owner_mt(const struct sk_buff *skb")
tail_start = xt.index(tail_start_marker, owner_start)
tail_end = xt.index(function_end_marker, tail_start)
locked_tail = """\tread_lock_bh(&sk->sk_callback_lock);
\tfilp = sk->sk_socket ? sk->sk_socket->file : NULL;
\tif (filp == NULL) {
\t\tread_unlock_bh(&sk->sk_callback_lock);
\t\treturn ((info->match ^ info->invert) &
\t\t       (XT_OWNER_UID | XT_OWNER_GID)) == 0;
\t}

\tif (info->match & XT_OWNER_UID) {
\t\tkuid_t uid_min = make_kuid(net->user_ns, info->uid_min);
\t\tkuid_t uid_max = make_kuid(net->user_ns, info->uid_max);

\t\tif ((uid_gte(filp->f_cred->fsuid, uid_min) &&
\t\t     uid_lte(filp->f_cred->fsuid, uid_max)) ^
\t\t    !(info->invert & XT_OWNER_UID)) {
\t\t\tread_unlock_bh(&sk->sk_callback_lock);
\t\t\treturn false;
\t\t}
\t}

\tif (info->match & XT_OWNER_GID) {
\t\tunsigned int i, match = false;
\t\tkgid_t gid_min = make_kgid(net->user_ns, info->gid_min);
\t\tkgid_t gid_max = make_kgid(net->user_ns, info->gid_max);
\t\tstruct group_info *gi = filp->f_cred->group_info;

\t\tif (gid_gte(filp->f_cred->fsgid, gid_min) &&
\t\t    gid_lte(filp->f_cred->fsgid, gid_max))
\t\t\tmatch = true;

\t\tif (!match && (info->match & XT_OWNER_SUPPL_GROUPS) && gi) {
\t\t\tfor (i = 0; i < gi->ngroups; ++i) {
\t\t\t\tkgid_t group = gi->gid[i];

\t\t\t\tif (gid_gte(group, gid_min) &&
\t\t\t\t    gid_lte(group, gid_max)) {
\t\t\t\t\tmatch = true;
\t\t\t\t\tbreak;
\t\t\t\t}
\t\t\t}
\t\t}

\t\tif (match ^ !(info->invert & XT_OWNER_GID)) {
\t\t\tread_unlock_bh(&sk->sk_callback_lock);
\t\t\treturn false;
\t\t}
\t}

\tread_unlock_bh(&sk->sk_callback_lock);
\treturn true;"""
xt = xt[:tail_start] + locked_tail + xt[tail_end:]
write(xt_path, xt)
'''
patched = source[:start] + replacement + source[end:]
exec(compile(patched, str(resolver), "exec"), {
    "__name__": "__main__",
    "__file__": str(resolver),
})

# The embedded ledger fragment is intentionally multi-line. Normalize its EOF
# after all semantic assertions so git diff --check sees one final newline and
# no empty line after the last report entry.
ledger = Path("Documentation/miru/lts-4.14.357-conflicts.md")
ledger.write_text(ledger.read_text().rstrip() + "\n")
