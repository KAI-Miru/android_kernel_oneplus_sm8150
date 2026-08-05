#!/usr/bin/env python3
"""Resolve Miru H.40 conflicts for OpenELA 4.14.340..4.14.344.

Every transformation is strict and fails when the reviewed downstream context
is absent or duplicated. The merge workflow verifies the exact conflict set
before invoking this script.
"""
from pathlib import Path
import subprocess

CONFLICTS = [
    "drivers/android/binder.c",
    "fs/select.c",
    "include/net/netns/ipv4.h",
    "net/ipv4/sysctl_net_ipv4.c",
    "net/ipv4/tcp_ipv4.c",
    "net/netfilter/xt_owner.c",
    "sound/usb/stream.c",
]


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one reviewed anchor, found {count}")
    write(path, text.replace(old, new, 1))


unmerged = subprocess.check_output(
    ["git", "diff", "--name-only", "--diff-filter=U"], text=True
).splitlines()
if sorted(unmerged) != CONFLICTS:
    raise SystemExit(f"unexpected stage-344 conflicts: {unmerged!r}")

# Start from the current Miru/OnePlus implementation for every conflict and
# then apply only the reviewed OpenELA semantic delta.
run("git", "checkout", "--ours", "--", *CONFLICTS)

# Binder already contains Android's complete process_todo redesign. OpenELA's
# new semantic delta is the explicit wakeup for an epoll thread queueing work
# to itself. Keep all Qualcomm/OPlus Binder extensions and reject unrelated
# Lineage changes around waiting-thread bookkeeping.
replace(
    "drivers/android/binder.c",
    """\tbinder_enqueue_work_ilocked(work, &thread->todo);
\tthread->process_todo = true;
""",
    """\tbinder_enqueue_work_ilocked(work, &thread->todo);

\t/*
\t * An epoll-based thread queueing work to itself needs an explicit
\t * signal; otherwise it may wait indefinitely without consuming it.
\t */
\tif (thread->looper & BINDER_LOOPER_STATE_POLL &&
\t    thread->pid == current->pid && !thread->process_todo)
\t\twake_up_interruptible_sync(&thread->wait);

\tthread->process_todo = true;
""",
)

# fs/select.c already carries noinline_for_stack in the Android tree. Preserve
# its downstream declaration formatting; the OpenELA stack-allocation intent
# is already satisfied.
select_text = read("fs/select.c")
if "static int noinline_for_stack\ndo_select(" not in select_text:
    raise SystemExit("fs/select.c: downstream noinline_for_stack semantic gate missing")

# Namespace tcp_early_retrans while retaining Miru's default-init-rwnd and
# OPlus random-timestamp fields.
replace(
    "include/net/netns/ipv4.h",
    """\tint sysctl_tcp_timestamps;
\tint sysctl_tcp_default_init_rwnd;
""",
    """\tint sysctl_tcp_timestamps;
\tint sysctl_tcp_early_retrans;
\tint sysctl_tcp_default_init_rwnd;
""",
)

global_early = """\t{
\t\t.procname\t= "tcp_early_retrans",
\t\t.data\t\t= &sysctl_tcp_early_retrans,
\t\t.maxlen\t\t= sizeof(int),
\t\t.mode\t\t= 0644,
\t\t.proc_handler\t= proc_dointvec_minmax,
\t\t.extra1\t\t= &zero,
\t\t.extra2\t\t= &four,
\t},
"""
replace("net/ipv4/sysctl_net_ipv4.c", global_early, "")
replace(
    "net/ipv4/sysctl_net_ipv4.c",
    """\t{
\t\t.procname       = "tcp_default_init_rwnd",
""",
    """\t{
\t\t.procname\t= "tcp_early_retrans",
\t\t.data\t\t= &init_net.ipv4.sysctl_tcp_early_retrans,
\t\t.maxlen\t\t= sizeof(int),
\t\t.mode\t\t= 0644,
\t\t.proc_handler\t= proc_dointvec_minmax,
\t\t.extra1\t\t= &zero,
\t\t.extra2\t\t= &four,
\t},
\n\t{
\t\t.procname       = "tcp_default_init_rwnd",
""",
)
replace(
    "net/ipv4/tcp_ipv4.c",
    """\tnet->ipv4.sysctl_tcp_timestamps = 1;
\tnet->ipv4.sysctl_tcp_default_init_rwnd = TCP_INIT_CWND * 2;
""",
    """\tnet->ipv4.sysctl_tcp_timestamps = 1;
\tnet->ipv4.sysctl_tcp_early_retrans = 3;
\tnet->ipv4.sysctl_tcp_default_init_rwnd = TCP_INIT_CWND * 2;
""",
)

# Preserve OPlus LOCAL_IN owner matching and socket recovery. Add OpenELA's
# callback-lock lifetime protection and supplementary-group semantics around
# the final full socket selected by that downstream path.
replace(
    "net/netfilter/xt_owner.c",
    """\tfilp = sk->sk_socket->file;
\tif (filp == NULL)
\t\treturn ((info->match ^ info->invert) &
\t\t\t\t(XT_OWNER_UID | XT_OWNER_GID)) == 0;
""",
    """\tread_lock_bh(&sk->sk_callback_lock);
\tfilp = sk->sk_socket ? sk->sk_socket->file : NULL;
\tif (filp == NULL) {
\t\tread_unlock_bh(&sk->sk_callback_lock);
\t\treturn ((info->match ^ info->invert) &
\t\t\t\t(XT_OWNER_UID | XT_OWNER_GID)) == 0;
\t}
""",
)

xt_path = "net/netfilter/xt_owner.c"
xt = read(xt_path)
uid_start = xt.index("\tif (info->match & XT_OWNER_UID) {")
gid_start = xt.index("\n\tif (info->match & XT_OWNER_GID) {", uid_start)
uid_final = """\tif (info->match & XT_OWNER_UID) {
\t\tkuid_t uid_min = make_kuid(net->user_ns, info->uid_min);
\t\tkuid_t uid_max = make_kuid(net->user_ns, info->uid_max);

\t\tif ((uid_gte(filp->f_cred->fsuid, uid_min) &&
\t\t     uid_lte(filp->f_cred->fsuid, uid_max)) ^
\t\t    !(info->invert & XT_OWNER_UID)) {
\t\t\tread_unlock_bh(&sk->sk_callback_lock);
\t\t\treturn false;
\t\t}
\t}
"""
xt = xt[:uid_start] + uid_final + xt[gid_start + 1 :]
gid_start = xt.index("\tif (info->match & XT_OWNER_GID) {")
return_start = xt.index("\n\n\treturn true;", gid_start)
gid_final = """\tif (info->match & XT_OWNER_GID) {
\t\tunsigned int i;
\t\tbool match = false;
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

\tread_unlock_bh(&sk->sk_callback_lock);"""
xt = xt[:gid_start] + gid_final + xt[return_start:]
write(xt_path, xt)

# Bound channel-map writes by the allocated channel count while retaining the
# downstream UAC parsing structure.
replace(
    "sound/usb/stream.c",
    """\t\tif (bits) {
\t\t\tfor (; bits && *maps; maps++, bits >>= 1)
\t\t\t\tif (bits & 1)
\t\t\t\t\tchmap->map[c++] = *maps;
\t\t} else {
""",
    """\t\tif (bits) {
\t\t\tfor (; bits && *maps; maps++, bits >>= 1) {
\t\t\t\tif (bits & 1)
\t\t\t\t\tchmap->map[c++] = *maps;
\t\t\t\tif (c == chmap->channels)
\t\t\t\t\tbreak;
\t\t\t}
\t\t} else {
""",
)

ledger_path = Path("Documentation/miru/lts-4.14.357-conflicts.md")
ledger = ledger_path.read_text()
stage = r'''

## Stage 2 — 4.14.340 to 4.14.344

OpenELA parent: `7a22fc46cc7a72d72b6dfdcbbc46e18c9f2caab0`

Initial textual conflicts: **7**. Remaining conflicts: **0**.

| Path | OpenELA intent / provenance | Miru divergence | LineageOS reference | Final Miru resolution | Class | Compile impact | Runtime risk / validation |
|---|---|---|---|---|---|---|---|
| `drivers/android/binder.c` | `abd2c4dd7791` adds Android `process_todo`; `aaf0101b79c4` signals epoll threads queueing self-work. | Miru already carries the complete Android `process_todo` redesign plus Qualcomm/OPlus Binder code; only the self-wakeup was absent. | Has the wakeup, plus later waiting-thread assertions unrelated to this OpenELA range. | Preserve Miru Binder and add the guarded `wake_up_interruptible_sync()` before setting `process_todo`. | adapted | Android Binder IPC | High: boot and app IPC. Validate self-work wakeup, Android ABI, OPlus hooks and Binder stress. |
| `fs/select.c` | `70137872f87a` marks `do_select()` `noinline_for_stack` to avoid excessive Clang stack allocation. | The Android tree already has the attribute using split declaration formatting. | Reformats the declaration and also contains unrelated later time64/freezer work. | Keep Miru text; assert the attribute remains. | not applicable | poll/select core | Low: semantic fix already present; Clang object/full build gate. |
| `include/net/netns/ipv4.h` | `759b99e2744b` makes `sysctl_tcp_early_retrans` network-namespace scoped. | Miru adds `sysctl_tcp_default_init_rwnd` and OPlus random-timestamp state nearby. | Includes the field but also unrelated later per-net TCP state. | Add only `sysctl_tcp_early_retrans`, retaining all Miru/OPlus fields. | adapted | IPv4 namespace ABI | Medium: netns layout and TCP sysctl behavior. |
| `net/ipv4/sysctl_net_ipv4.c` | `759b99e2744b` moves `tcp_early_retrans` from the global table to the per-net table. | Miru has additional TCP controls and OPlus timestamp controls. | Carries the per-net entry plus unrelated later sysctl changes. | Remove the global entry and add the `init_net.ipv4`-based per-net entry without disturbing downstream controls. | adapted | IPv4 sysctl registration | Medium: boot-time sysctl registration and per-net writes. |
| `net/ipv4/tcp_ipv4.c` | `759b99e2744b` initializes each namespace's early-retrans value to 3. | Miru initializes default receive window and OPlus random timestamps in the same block. | Includes the initializer among later TCP changes. | Add only the early-retrans initializer and retain downstream initialization. | adapted | TCP namespace init | Medium: TCP behavior and namespace creation. |
| `net/netfilter/xt_owner.c` | `c5bb4c9e5197` protects `sk_socket`/file access; `aaeb68749011` adds supplementary-group matching. | OPlus extends owner matching to LOCAL_IN and recovers sockets through qtaguid-specific logic. | Uses the generic LOCAL_OUT/POST_ROUTING implementation and drops the OPlus path. | Keep OPlus socket recovery and LOCAL_IN hooks, then add callback-lock lifetime protection, balanced unlocks and supplementary groups. | adapted | Android firewall/netfilter | High: UID firewall, data policy and inbound OPlus matching. Validate rules, networking and lock balance. |
| `sound/usb/stream.c` | `684d0dfc0167` stops parsing channel bits after all allocated channels are filled. | Miru's USB-audio channel-map parser has a downstream control-flow layout. | Adds the same bound in that layout. | Add a `c == chmap->channels` stop while preserving Miru parsing. | adapted | USB audio | Low for built-in phone audio; compile and USB-audio channel-map test. |

### Stage 2 semantic gates

- exact seven-path conflict inventory and exact OpenELA second parent;
- Binder `process_todo` retained and epoll self-work wakeup added;
- `do_select()` remains `noinline_for_stack` for Clang;
- `tcp_early_retrans` field, per-net sysctl entry and default initializer agree;
- OPlus `XT_OWNER` LOCAL_IN path remains, with callback-lock and supplementary-group handling;
- USB channel-map writes stop at the allocated channel count;
- Qualcomm-safe DWC3 direct pending-event dispatch and GPL audio export remain intact;
- no unmerged entries, conflict headers, `.orig` or `.rej` files remain.
'''
if "## Stage 2 — 4.14.340 to 4.14.344" in ledger:
    raise SystemExit("stage-344 ledger already present")
ledger_path.write_text(ledger.rstrip() + stage + "\n")

# Final local semantic assertions before the workflow stages the resolution.
checks = {
    "drivers/android/binder.c": [
        "thread->pid == current->pid && !thread->process_todo",
        "wake_up_interruptible_sync(&thread->wait);",
        "thread->process_todo = true;",
    ],
    "include/net/netns/ipv4.h": ["int sysctl_tcp_early_retrans;", "sysctl_tcp_random_timestamp"],
    "net/ipv4/sysctl_net_ipv4.c": ["&init_net.ipv4.sysctl_tcp_early_retrans"],
    "net/ipv4/tcp_ipv4.c": ["net->ipv4.sysctl_tcp_early_retrans = 3;"],
    "net/netfilter/xt_owner.c": [
        "OPLUS_FEATURE_XTOWNER_INPUT",
        "read_lock_bh(&sk->sk_callback_lock);",
        "XT_OWNER_SUPPL_GROUPS",
        "NF_INET_LOCAL_IN",
    ],
    "sound/usb/stream.c": ["if (c == chmap->channels)"],
}
for path, needles in checks.items():
    text = read(path)
    for needle in needles:
        if needle not in text:
            raise SystemExit(f"{path}: semantic gate missing: {needle}")
if "\t\t.data\t\t= &sysctl_tcp_early_retrans," in read("net/ipv4/sysctl_net_ipv4.c"):
    raise SystemExit("global tcp_early_retrans sysctl entry remains")
