#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import subprocess

CONNTRACK = pathlib.Path("include/net/netfilter/nf_conntrack.h")
SYSCTL = pathlib.Path("net/ipv4/sysctl_net_ipv4.c")
QRTR = pathlib.Path("net/qrtr/qrtr.c")
LEDGER = pathlib.Path("Documentation/miru/lts-4.14.190-conflicts.md")

EXPECTED_HASHES = {
    CONNTRACK: "cbf3248e156d37a641f8f64f4c8085814d6d417c",
    SYSCTL: "ccb719a98cc7f77e06ecbb74b37cc5693426c7a0",
    QRTR: "61d0db886694c552ecfca2e0cc407375d1a7043c",
    LEDGER: "fe6306277b3b9b46b34e5253c3348f2d4e99b91d",
}

EXPECTED_RESOLVED_HASHES = {
    CONNTRACK: "7ce58cd24a8089f49cdaf4a04691abc1603a8a99",
    SYSCTL: "11c4c837a98294c289e29d3b0de6979b49205516",
    QRTR: "67c9e413d9f09551b46f101cfab36fd8507555c4",
}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def replace_exact(text: str, old: str, new: str, expected_count: int = 1) -> str:
    count = text.count(old)
    if count != expected_count:
        raise SystemExit(
            f"replacement guard failed: expected {expected_count}, found {count}: {old!r}"
        )
    return text.replace(old, new, expected_count)


def verify_hashes() -> None:
    for path, expected in EXPECTED_HASHES.items():
        actual = git("hash-object", str(path)).strip()
        if actual != expected:
            raise SystemExit(f"{path}: expected blob {expected}, found {actual}")


def verify_resolved_hash(path: pathlib.Path) -> None:
    actual = git("hash-object", str(path)).strip()
    expected = EXPECTED_RESOLVED_HASHES[path]
    if actual != expected:
        raise SystemExit(f"{path}: expected resolved blob {expected}, found {actual}")


def resolve_conntrack() -> None:
    text = CONNTRACK.read_text()
    text = replace_exact(
        text,
        "\tu8 __nfct_init_offset[0];",
        "\tstruct { } __nfct_init_offset;",
    )

    required = (
        "#define OPLUS_FEATURE_WIFI_LUCKYMONEY",
        "u32 oplus_app_uid;",
        "void *sfe_entry;",
        "struct list_head sip_segment_list;",
        "unsigned long nattype_entry;",
        "struct { } __nfct_init_offset;",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"conntrack lost required H.40 behavior: {token}")
    if "__nfct_init_offset[0]" in text:
        raise SystemExit("conntrack zero-length initialization marker remains")

    CONNTRACK.write_text(text)
    verify_resolved_hash(CONNTRACK)


def resolve_sysctl() -> None:
    text = SYSCTL.read_text()

    text = replace_exact(
        text,
        """static int zero;
static int one = 1;
static int four = 4;
static int thousand = 1000;
""",
        """static int zero;
static int one = 1;
static int three = 3;
static int four = 4;
static int hundred = 100;
static int thousand = 1000;
""",
    )

    text = replace_exact(
        text,
        """/* Validate changes from /proc interface. */
static int proc_tcp_default_init_rwnd(struct ctl_table *ctl, int write,
\t\t\t\t      void __user *buffer,
\t\t\t\t      size_t *lenp, loff_t *ppos)
{
\tint old_value = *(int *)ctl->data;
\tint ret = proc_dointvec(ctl, write, buffer, lenp, ppos);
\tint new_value = *(int *)ctl->data;

\tif (write && ret == 0 && (new_value < 3 || new_value > 100))
\t\t*(int *)ctl->data = old_value;

\treturn ret;
}

""",
        "",
    )

    text = replace_exact(
        text,
        """\t{
\t\t.procname       = "tcp_default_init_rwnd",
\t\t.data           = &sysctl_tcp_default_init_rwnd,
\t\t.maxlen         = sizeof(int),
\t\t.mode           = 0644,
\t\t.proc_handler   = proc_tcp_default_init_rwnd
\t},
""",
        "",
    )

    text = replace_exact(
        text,
        """
\t#ifdef OPLUS_BUG_STABILITY
\t{
\t\t.procname\t= "tcp_random_timestamp",
""",
        """
\t{
\t\t.procname       = "tcp_default_init_rwnd",
\t\t.data           = &init_net.ipv4.sysctl_tcp_default_init_rwnd,
\t\t.maxlen         = sizeof(int),
\t\t.mode           = 0644,
\t\t.proc_handler   = proc_dointvec_minmax,
\t\t.extra1\t\t= &three,
\t\t.extra2\t\t= &hundred,
\t},

\t#ifdef OPLUS_BUG_STABILITY
\t{
\t\t.procname\t= "tcp_random_timestamp",
""",
    )

    required = (
        'static int three = 3;',
        'static int hundred = 100;',
        '.data           = &init_net.ipv4.sysctl_tcp_default_init_rwnd,',
        '.proc_handler   = proc_dointvec_minmax,',
        '.extra1\t\t= &three,',
        '.extra2\t\t= &hundred,',
        '.procname\t= "tcp_timestamps_control",',
        '.data\t\t= &sysctl_tcp_ts_control,',
        '.procname\t= "tcp_random_timestamp",',
        '.data\t\t= &init_net.ipv4.sysctl_tcp_random_timestamp,',
        '.procname\t= "tcp_delack_seg",',
        '.procname       = "tcp_use_userconfig",',
        '.procname       = "reserved_port_bind",',
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"IPv4 sysctl lost required behavior: {token}")

    forbidden = (
        "static int proc_tcp_default_init_rwnd(",
        ".data           = &sysctl_tcp_default_init_rwnd,",
        ".proc_handler   = proc_tcp_default_init_rwnd",
    )
    for token in forbidden:
        if token in text:
            raise SystemExit(f"obsolete global init-rwnd implementation remains: {token}")

    if text.count('.procname       = "tcp_default_init_rwnd",') != 1:
        raise SystemExit("tcp_default_init_rwnd sysctl missing or duplicated")

    SYSCTL.write_text(text)
    verify_resolved_hash(SYSCTL)


def resolve_qrtr() -> None:
    text = QRTR.read_text()
    text = replace_exact(
        text,
        "\tqrtr_local_enqueue(node, skb, type, from, to, flags);",
        "\tqrtr_local_enqueue(NULL, skb, type, from, to, flags);",
    )

    required = (
        "int modem_wakeup_src_count[MODEM_WAKEUP_SRC_NUM] = { 0 };",
        "oplus_match_qrtr_service_port",
        "oplus_match_qrtr_wakeup",
        "static void qrtr_backup_init(void)",
        "static void qrtr_backup_deinit(void)",
        "skb = qrtr_get_backup(len);",
        "sock_orphan(sk);",
        "sock->sk = NULL;",
        "qrtr_local_enqueue(NULL, skb, type, from, to, flags);",
        "qrtr_backup_init();",
        "qrtr_backup_deinit();",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"QRTR lost required H.40 behavior: {token}")
    if "qrtr_local_enqueue(node, skb, type, from, to, flags);" in text:
        raise SystemExit("QRTR broadcast still passes the loop cursor to local enqueue")

    QRTR.write_text(text)
    verify_resolved_hash(QRTR)


def validate_dependencies() -> None:
    core = pathlib.Path("net/netfilter/nf_conntrack_core.c").read_text()
    if "memset(&ct->__nfct_init_offset, 0," not in core:
        raise SystemExit("conntrack initialization callsite is missing")
    if "offsetof(struct nf_conn, __nfct_init_offset)" not in core:
        raise SystemExit("conntrack initialization offset dependency is missing")

    netns = pathlib.Path("include/net/netns/ipv4.h").read_text()
    if "int sysctl_tcp_default_init_rwnd;" not in netns:
        raise SystemExit("per-net tcp_default_init_rwnd storage is missing")
    if "int sysctl_tcp_random_timestamp;" not in netns:
        raise SystemExit("Oplus per-net random timestamp storage is missing")

    uses = git("grep", "-n", "sysctl_tcp_default_init_rwnd", "--", "include", "net")
    if "include/net/netns/ipv4.h:" not in uses:
        raise SystemExit("tcp_default_init_rwnd netns field is not discoverable")
    if "net/ipv4/sysctl_net_ipv4.c:" not in uses:
        raise SystemExit("tcp_default_init_rwnd sysctl registration is not discoverable")


def update_ledger() -> None:
    text = LEDGER.read_text()
    replacements = {
        "- Resolved conflicts: 22": "- Resolved conflicts: 25",
        "- Remaining conflicts: 6": "- Remaining conflicts: 3",
        "include/net/netfilter/nf_conntrack.h\n": "",
        "net/ipv4/sysctl_net_ipv4.c\n": "",
        "net/qrtr/qrtr.c\n": "",
    }
    for old, new in replacements.items():
        text = replace_exact(text, old, new)

    marker = "## Remaining deferred conflicts\n"
    if text.count(marker) != 1:
        raise SystemExit("remaining-conflicts marker missing or duplicated")

    section = """## Resolved in Step 8

The conntrack ABI marker, IPv4 sysctl registration and Qualcomm QRTR conflict
were resolved as one networking compatibility unit:

```text
include/net/netfilter/nf_conntrack.h
net/ipv4/sysctl_net_ipv4.c
net/qrtr/qrtr.c
```

`nf_conntrack.h` applies stable commit
`7addf56d9a45e8601b726a7efbcbe75713a15e91` (upstream
`2c407aca64977ede9b9f35158e919773cae2082f`), replacing the zero-length
`__nfct_init_offset[0]` marker with an empty structure so GCC 10 does not emit
an out-of-bounds warning. H.40's Oplus application UID, SFE pointer, SIP
segmentation state, NATTYPE field and protocol tail remain in their original
order and continue to be covered by the existing allocation-time `memset()`.

`sysctl_net_ipv4.c` applies Android commit
`08870bd1a24fc7f3ae4ff30bc7e64c09edd931d4`, moving
`tcp_default_init_rwnd` from the global IPv4 table into `ipv4_net_table` and
using `proc_dointvec_minmax` with limits 3 through 100. This makes the Android
sysctl use the existing per-network-namespace field. H.40's delayed-ACK,
user-config, reserved-port, timestamp-control and random-timestamp sysctls are
preserved.

`qrtr.c` applies stable commit `33fe397c18f4788232793f3fbf5d3156f3100b6f`
(upstream `6dbf02acef69b0742c238574583b3068afbd227c`) by passing `NULL` to the
local leg after broadcast endpoint iteration instead of reusing the loop's
last node pointer. H.40's modem wake accounting, service matching, IPC logging,
emergency skb backup pools, multi-node forwarding and socket-orphan release
ordering remain unchanged.

Resolution commit:

```text
lts: resolve conntrack IPv4 sysctl and QRTR conflicts
```

"""
    LEDGER.write_text(text.replace(marker, section + marker, 1))


def main() -> None:
    verify_hashes()
    resolve_conntrack()
    resolve_sysctl()
    resolve_qrtr()
    validate_dependencies()
    update_ledger()
    print("Step 8 guarded networking resolution completed.")


if __name__ == "__main__":
    main()
