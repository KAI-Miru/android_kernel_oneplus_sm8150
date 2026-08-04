#!/usr/bin/env python3
"""Resolve Miru H.40 conflicts for OpenELA 4.14.344..4.14.348."""
from pathlib import Path
import subprocess

CONFLICTS = [
    "fs/aio.c",
    "mm/memory-failure.c",
    "mm/page_alloc.c",
    "net/core/filter.c",
]


def output(*args: str) -> str:
    return subprocess.check_output(args, text=True)


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def replace(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one reviewed anchor, found {count}")
    p.write_text(text.replace(old, new, 1))


def extract_function(text: str, signature: str) -> str:
    start = text.index(signature)
    brace = text.index("{", start)
    depth = 0
    for pos in range(brace, len(text)):
        char = text[pos]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                end = pos + 1
                if end < len(text) and text[end] == "\n":
                    end += 1
                return text[start:end]
    raise SystemExit(f"unclosed function: {signature}")


unmerged = output("git", "diff", "--name-only", "--diff-filter=U").splitlines()
if sorted(unmerged) != CONFLICTS:
    raise SystemExit(f"unexpected stage-348 conflicts: {unmerged!r}")

# Preserve the exact OpenELA implementations of the four narrowly affected BPF
# helpers before checking out Miru's Android/Qualcomm file as the base.
filter_theirs = output("git", "show", ":3:net/core/filter.c")
run("git", "checkout", "--ours", "--", *CONFLICTS)

# Stage 1 already implemented the later AIO safety ordering: reject non-AIO
# kiocbs before container_of(), while retaining Miru's active-list assertion.
aio = Path("fs/aio.c").read_text()
guard = aio.index("if (!(iocb->ki_flags & IOCB_AIO_RW))")
conversion = aio.index("container_of(iocb, struct aio_kiocb, common)")
if guard >= conversion or "WARN_ON_ONCE(!list_empty(&req->ki_list))" not in aio:
    raise SystemExit("fs/aio.c: reviewed AIO ordering/assertion missing")

# OpenELA fixes huge-page handling by unmapping the head rather than the
# poisoned tail page. Adapt that change to Qualcomm's downstream three-argument
# try_to_unmap() API instead of importing the generic two-argument form.
replace(
    "mm/memory-failure.c",
    "\tunmap_success = try_to_unmap(p, ttu, NULL);\n",
    "\tunmap_success = try_to_unmap(hpage, ttu, NULL);\n",
)
memory_failure = Path("mm/memory-failure.c").read_text()
if "try_to_unmap(hpage, ttu, NULL)" not in memory_failure:
    raise SystemExit("mm/memory-failure.c: huge-page-head unmap fix missing")
if "try_to_unmap(p, ttu, NULL)" in memory_failure:
    raise SystemExit("mm/memory-failure.c: tail-page unmap remains")

# Respect callers whose GFP mask disallows compaction while retaining OPlus
# healthinfo, LMK retry and vendor telemetry in the downstream slow path.
replace(
    "mm/page_alloc.c",
    "\tbool can_direct_reclaim = gfp_mask & __GFP_DIRECT_RECLAIM;\n",
    "\tbool can_direct_reclaim = gfp_mask & __GFP_DIRECT_RECLAIM;\n"
    "\tbool can_compact = gfp_compaction_allowed(gfp_mask);\n",
)
replace(
    "mm/page_alloc.c",
    "\tif (can_direct_reclaim &&\n",
    "\tif (can_direct_reclaim && can_compact &&\n",
)
replace(
    "mm/page_alloc.c",
    """\t/*
\t * Do not retry costly high order allocations unless they are
\t * __GFP_RETRY_MAYFAIL
\t */
\tif (costly_order && !(gfp_mask & __GFP_RETRY_MAYFAIL))
""",
    """\t/*
\t * Do not retry costly high order allocations unless they are
\t * __GFP_RETRY_MAYFAIL and we can compact.
\t */
\tif (costly_order && (!can_compact ||
\t\t\t     !(gfp_mask & __GFP_RETRY_MAYFAIL)))
""",
)
replace(
    "mm/page_alloc.c",
    "\tif ((did_some_progress > 0 || lmk_kill_possible()) &&\n",
    "\tif ((did_some_progress > 0 || lmk_kill_possible()) && can_compact &&\n",
)

# Apply only OpenELA's four GSO-sensitive BPF helper bodies. Do not import
# LineageOS's substantially newer Android BPF stack surrounding them.
filter_path = Path("net/core/filter.c")
filter_miru = filter_path.read_text()
for name in (
    "bpf_skb_proto_4_to_6",
    "bpf_skb_proto_6_to_4",
    "bpf_skb_net_grow",
    "bpf_skb_net_shrink",
):
    signature = f"static int {name}"
    ours = extract_function(filter_miru, signature)
    theirs = extract_function(filter_theirs, signature)
    if filter_miru.count(ours) != 1:
        raise SystemExit(f"net/core/filter.c: ambiguous function {name}")
    filter_miru = filter_miru.replace(ours, theirs, 1)
filter_path.write_text(filter_miru)

ledger_path = Path("Documentation/miru/lts-4.14.357-conflicts.md")
ledger = ledger_path.read_text().rstrip()
if "## Stage 3 — 4.14.344 to 4.14.348" in ledger:
    raise SystemExit("stage-348 ledger already present")
ledger += r'''

## Stage 3 — 4.14.344 to 4.14.348

OpenELA parent: `ef4cb0aa8addc73e6257039a17061cb1766b7477`

Initial textual conflicts: **4**. Remaining conflicts: **0**.

| Path | OpenELA intent / provenance | Miru divergence | LineageOS reference | Final Miru resolution | Class | Compile impact | Runtime risk / validation |
|---|---|---|---|---|---|---|---|
| `fs/aio.c` | `9b033ffdc449` checks `IOCB_AIO_RW` before converting a generic `kiocb` to `aio_kiocb`. | Stage 1 already applied the safety ordering and retained Miru's active-request assertion. | Identical to the current Miru implementation. | Keep Miru; assert guard-before-conversion and active-list sanity. | not applicable | AIO core | Medium: Android asynchronous I/O; compile and AIO semantic gates. |
| `mm/memory-failure.c` | `fd783c9a2045` unmaps the huge-page head rather than a poisoned tail page. | Miru still unmaps `p` through Qualcomm's downstream three-argument `try_to_unmap(..., NULL)` API. | Uses the huge-page head in the generic implementation. | Change the target to `hpage` while preserving the downstream third argument and surrounding Android MM behavior. | adapted | HW-poison MM | Low on phone runtime, high correctness; source gate and configuration-aware validation. |
| `mm/page_alloc.c` | OpenELA prevents direct/retry compaction when the GFP mask disallows compaction. | Qualcomm/OPlus adds healthinfo timing and LMK-aware retry behavior throughout this slow path. | Contains the generic compaction gate amid a differently evolved allocator. | Add `can_compact` to the three OpenELA decision points while preserving OPlus telemetry and LMK retries. | adapted | Core allocator | High: allocation latency, reclaim and LMK. Compile allocator and validate memory pressure later. |
| `net/core/filter.c` | `19b468b254ac` rejects SCTP `GSO_BY_FRAGS` and uses checked GSO-size helpers in BPF protocol translation/net-header adjustment. | Miru uses an older Android BPF implementation; LineageOS has thousands of lines of later unrelated BPF changes. | Semantic fix present, but complete-file adoption would import unrelated Android-generation changes. | Replace only the four affected helper bodies with the exact OpenELA implementations. | adapted | BPF/network core | High: VPN/firewall/tether paths. Compile, assert SCTP rejection and checked GSO helpers. |

### Stage 3 semantic gates

- exact four-path conflict inventory and exact OpenELA second parent;
- AIO rejects non-AIO kiocbs before `container_of()`;
- memory failure unmaps `hpage` through the downstream API;
- allocator compaction attempts and retries honor `gfp_compaction_allowed()` while OPlus LMK/healthinfo code remains;
- all four BPF helpers reject SCTP GSO and use `skb_{decrease,increase}_gso_size()`;
- Qualcomm-safe DWC3 direct pending-event dispatch and the GPL audio export remain intact;
- no unmerged entries, conflict headers, `.orig` or `.rej` files remain.
'''
ledger_path.write_text(ledger.rstrip() + "\n")

page_alloc = Path("mm/page_alloc.c").read_text()
for needle in (
    "bool can_compact = gfp_compaction_allowed(gfp_mask);",
    "can_direct_reclaim && can_compact",
    "costly_order && (!can_compact ||",
    "lmk_kill_possible()) && can_compact",
    "OPLUS_FEATURE_HEALTHINFO",
    "should_compact_lmk_retry",
):
    if needle not in page_alloc:
        raise SystemExit(f"mm/page_alloc.c: semantic gate missing: {needle}")

filter_final = filter_path.read_text()
if filter_final.count("skb_is_gso_sctp(skb)") < 4:
    raise SystemExit("net/core/filter.c: SCTP GSO guards incomplete")
if filter_final.count("skb_decrease_gso_size(shinfo, len_diff)") < 2:
    raise SystemExit("net/core/filter.c: GSO decrease helpers incomplete")
if filter_final.count("skb_increase_gso_size(shinfo, len_diff)") < 2:
    raise SystemExit("net/core/filter.c: GSO increase helpers incomplete")
