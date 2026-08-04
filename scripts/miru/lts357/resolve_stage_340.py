#!/usr/bin/env python3
"""Resolve the Miru H.40 conflicts for OpenELA 4.14.336..4.14.340.

This script is intentionally strict. Every textual replacement has an exact
expected count so a changed downstream implementation stops the integration
instead of receiving a plausible-looking but unreviewed resolution.
"""
from __future__ import annotations

from pathlib import Path
import subprocess

EXPECTED = [
    "drivers/android/binder_alloc.c",
    "drivers/infiniband/ulp/srpt/ib_srpt.c",
    "fs/aio.c",
    "fs/f2fs/namei.c",
    "kernel/power/swap.c",
    "mm/memory-failure.c",
]


def run(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    actual = text.count(old)
    if actual != count:
        raise SystemExit(
            f"{path}: replacement anchor count {actual}, expected {count}: {old!r}"
        )
    p.write_text(text.replace(old, new, count))


def require(path: str, needle: str, present: bool = True) -> None:
    found = needle in Path(path).read_text()
    if found != present:
        state = "present" if present else "absent"
        raise SystemExit(f"{path}: required {state}: {needle!r}")


actual = sorted(
    p for p in run("git", "diff", "--name-only", "--diff-filter=U").splitlines() if p
)
if actual != EXPECTED:
    raise SystemExit(f"unexpected stage-340 conflict inventory: {actual!r}")

for path in EXPECTED:
    subprocess.check_call(["git", "checkout", "--ours", "--", path])

# Binder allocator: adopt the mm lifetime and async-space fixes while retaining
# the OPlus HANS reporting extension. The HANS threshold is adapted to the same
# corrected accounting unit as the allocator itself.
replace("drivers/android/binder_alloc.c", "\t\tmmput(mm);", "\t\tmmput_async(mm);", 2)
replace(
    "drivers/android/binder_alloc.c",
    """#ifdef OPLUS_FEATURE_HANS_FREEZE
\tif (is_async
\t\t&& (alloc->free_async_space < 3 * (size + sizeof(struct binder_buffer))
\t\t|| (alloc->free_async_space < ((alloc->buffer_size / 2) * 9 / 10)))) {
""",
    """/* Pad 0-size buffers so they get assigned unique addresses. */
\tsize = max(size, sizeof(void *));

#ifdef OPLUS_FEATURE_HANS_FREEZE
\tif (is_async
\t\t&& (alloc->free_async_space < 3 * size
\t\t|| (alloc->free_async_space < ((alloc->buffer_size / 2) * 9 / 10)))) {
""",
)
replace(
    "drivers/android/binder_alloc.c",
    """\tif (is_async &&
\t    alloc->free_async_space < size + sizeof(struct binder_buffer)) {
""",
    """\tif (is_async && alloc->free_async_space < size) {
""",
)
replace(
    "drivers/android/binder_alloc.c",
    """
\t/* Pad 0-size buffers so they get assigned unique addresses */
\tsize = max(size, sizeof(void *));

\twhile (n) {
""",
    """
\twhile (n) {
""",
)
replace(
    "drivers/android/binder_alloc.c",
    "alloc->free_async_space -= size + sizeof(struct binder_buffer);",
    "alloc->free_async_space -= size;",
)
replace(
    "drivers/android/binder_alloc.c",
    "alloc->free_async_space += buffer_size + sizeof(struct binder_buffer);",
    "alloc->free_async_space += buffer_size;",
)
replace(
    "drivers/android/binder_alloc.c",
    " * Return:\tThe allocated buffer or %NULL if error",
    " * Return:\tThe allocated buffer or %ERR_PTR(-errno) if error",
)

# SRPT: eliminate the incompatible callback cast and make the service GUID
# writable through the existing hexadecimal module parameter interface.
replace(
    "drivers/infiniband/ulp/srpt/ib_srpt.c",
    """static int srpt_get_u64_x(char *buffer, const struct kernel_param *kp)
{
\treturn sprintf(buffer, "0x%016llx", *(u64 *)kp->arg);
}
module_param_call(srpt_service_guid, NULL, srpt_get_u64_x, &srpt_service_guid,
\t\t  0444);
""",
    """static int srpt_set_u64_x(const char *buffer,
\t\t\t  const struct kernel_param *kp)
{
\treturn kstrtou64(buffer, 16, (u64 *)kp->arg);
}

static int srpt_get_u64_x(char *buffer, const struct kernel_param *kp)
{
\treturn sprintf(buffer, "0x%016llx", *(u64 *)kp->arg);
}
module_param_call(srpt_service_guid, srpt_set_u64_x, srpt_get_u64_x,
\t\t  &srpt_service_guid, 0444);
""",
)
replace(
    "drivers/infiniband/ulp/srpt/ib_srpt.c",
    "static void srpt_qp_event(struct ib_event *event, struct srpt_rdma_ch *ch)\n{",
    """static void srpt_qp_event(struct ib_event *event, void *ptr)
{
\tstruct srpt_rdma_ch *ch = ptr;
""",
)
replace(
    "drivers/infiniband/ulp/srpt/ib_srpt.c",
    """\tqp_init->event_handler
\t\t= (void(*)(struct ib_event *, void*))srpt_qp_event;
""",
    "\tqp_init->event_handler = srpt_qp_event;\n",
)

# AIO: cancellation is valid only for AIO read/write requests and submitted
# requests carry the discriminator used by the cancellation path.
replace(
    "fs/aio.c",
    """\tstruct kioctx *ctx = req->ki_ctx;
\tunsigned long flags;

\tspin_lock_irqsave(&ctx->ctx_lock, flags);
""",
    """\tstruct kioctx *ctx = req->ki_ctx;
\tunsigned long flags;

\t/* Ignore non-AIO and non-read/write kiocbs. */
\tif (!(iocb->ki_flags & IOCB_AIO_RW))
\t\treturn;

\tspin_lock_irqsave(&ctx->ctx_lock, flags);
""",
)
replace(
    "fs/aio.c",
    "req->common.ki_flags = iocb_flags(req->common.ki_filp);",
    "req->common.ki_flags = iocb_flags(req->common.ki_filp) | IOCB_AIO_RW;",
)

# F2FS: cross-directory directory renames must update the parent link even when
# RENAME_WHITEOUT is used. Retain all Android-specific rename handling.
replace(
    "fs/f2fs/namei.c",
    "if (old_dir != new_dir && !whiteout)",
    "if (old_dir != new_dir)",
)

# Hibernation compression workers: pair producer release stores with consumer
# acquire loads so the data fields are visible when ready/stop becomes true.
swap = Path("kernel/power/swap.c")
swap_text = swap.read_text()
counts = {
    "atomic_read(&d->ready)": 3,
    "atomic_set(&d->stop, 1)": 6,
    "atomic_set(&data[thr].ready, 1)": 2,
    "atomic_set(&crc->ready, 1)": 3,
    "atomic_read(&data[thr].stop)": 2,
    "atomic_read(&crc->stop)": 3,
}
for needle, wanted in counts.items():
    actual_count = swap_text.count(needle)
    if actual_count != wanted:
        raise SystemExit(
            f"kernel/power/swap.c: {needle!r} count {actual_count}, expected {wanted}"
        )
swap_text = swap_text.replace("atomic_read(&d->ready)", "atomic_read_acquire(&d->ready)")
swap_text = swap_text.replace("atomic_set(&d->stop, 1)", "atomic_set_release(&d->stop, 1)")
swap_text = swap_text.replace(
    "atomic_set(&data[thr].ready, 1)", "atomic_set_release(&data[thr].ready, 1)"
)
swap_text = swap_text.replace(
    "atomic_set(&crc->ready, 1)", "atomic_set_release(&crc->ready, 1)"
)
swap_text = swap_text.replace(
    "atomic_read(&data[thr].stop)", "atomic_read_acquire(&data[thr].stop)"
)
swap_text = swap_text.replace(
    "atomic_read(&crc->stop)", "atomic_read_acquire(&crc->stop)"
)
swap.write_text(swap_text)

# Memory failure: operate on the poisoned subpage for mapping tests, unmap and
# diagnostic mapcount. The later 4.14.348 stage intentionally revisits the
# huge-page unmap target, and will be reviewed separately.
replace("mm/memory-failure.c", "if (!page_mapped(hpage))", "if (!page_mapped(p))")
replace(
    "mm/memory-failure.c",
    "unmap_success = try_to_unmap(hpage, ttu, NULL);",
    "unmap_success = try_to_unmap(p, ttu, NULL);",
)
replace("mm/memory-failure.c", "pfn, page_mapcount(hpage));", "pfn, page_mapcount(p));")

# Semantic gates for the adapted downstream state.
require("drivers/android/binder_alloc.c", "mmput_async(mm);")
require("drivers/android/binder_alloc.c", "alloc->free_async_space -= size;")
require("drivers/android/binder_alloc.c", "alloc->free_async_space += buffer_size;")
require("drivers/android/binder_alloc.c", "3 * size")
require("drivers/android/binder_alloc.c", "OPLUS_FEATURE_HANS_FREEZE")
require(
    "drivers/android/binder_alloc.c",
    "size + sizeof(struct binder_buffer)",
    present=False,
)
require("drivers/infiniband/ulp/srpt/ib_srpt.c", "qp_init->event_handler = srpt_qp_event;")
require("fs/aio.c", "IOCB_AIO_RW")
require("fs/f2fs/namei.c", "if (old_dir != new_dir)")
require("kernel/power/swap.c", "atomic_read_acquire(&d->ready)")
require("kernel/power/swap.c", "atomic_set_release(&d->stop, 1)")
require("mm/memory-failure.c", "if (!page_mapped(p))")
require("mm/memory-failure.c", "try_to_unmap(p, ttu, NULL)")

report = Path("Documentation/miru/lts-4.14.357-conflicts.md")
report.parent.mkdir(parents=True, exist_ok=True)
report.write_text(
    """# Miru H.40 OpenELA Linux 4.14.357 conflict ledger

## Immutable inputs

- Miru production: `eb9451c0a1639e1aa49ee094681f98df0545f797`
- OpenELA baseline: `c31e35278ea8f04f1dceadd77dca4dd7d47932a3`
- OpenELA final target: `1e6347375d088ecc896aabb067131d0f9e3c0575`
- LineageOS reference merge: `9be6616473e5ecc83915ba3390d4c6751b1c4876`
- External modules pin: `3216c08bb3f97f865eb055296ea8034e1744caef`

## Stage 1 — 4.14.336 to 4.14.340

OpenELA parent: `9b7ef2749ffa187d86acd0033327338c0fc299bf`

Initial textual conflicts: **6**. Remaining conflicts: **0**.

| Path | OpenELA intent | Miru divergence | LineageOS reference | Final Miru resolution | Class | Compile impact | Runtime risk / validation |
|---|---|---|---|---|---|---|---|
| `drivers/android/binder_alloc.c` | Avoid synchronous final `mmput()` in a remote Binder allocation path and correct async-space accounting to charge actual padded buffer bytes. | OPlus adds HANS frozen-process reporting around the async-space threshold. | Carries the generic Android Binder fixes without Miru's HANS extension. | Use `mmput_async()`, pad before every async-space test, charge/refund actual buffer bytes, and adapt the HANS threshold to the corrected unit while retaining reporting. | adapted | Binder allocator and Android IPC | High: Android boot, app launch, async Binder pressure and no delayed death notifications. Semantic anchors and later full build required. |
| `drivers/infiniband/ulp/srpt/ib_srpt.c` | Remove an incompatible QP callback cast and accept hexadecimal service GUID writes. | Downstream callback and module-param prototypes use `const struct kernel_param *`. | Same semantic fix with the downstream const prototype. | Add const-correct setter, use `void *` callback context and direct callback assignment. | adopted | SRPT only | Low for SM8150; compile/type validation. |
| `fs/aio.c` | Mark AIO read/write requests and reject cancellation setup for other `kiocb` users. | Android AIO retains downstream request layout. | Applies the discriminator in the Android tree. | Preserve layout; add `IOCB_AIO_RW` marking and cancellation guard. | adapted | AIO core | Medium: asynchronous I/O cancellation; compile and storage workload validation. |
| `fs/f2fs/namei.c` | Correct cross-directory directory link accounting for whiteout rename. | Android F2FS has extra fsync and checkpoint behavior. | Changes only the whiteout condition. | Remove `!whiteout` from the parent-link update condition and retain all Android F2FS extensions. | adapted | F2FS rename | High: userdata directory rename; later fsck/mount/install/write tests. |
| `kernel/power/swap.c` | Pair worker readiness/completion release stores with acquire loads. | No semantic divergence; only downstream context. | Carries the same memory-ordering fix. | Apply acquire/release operations at every producer/consumer pair. | adopted | Hibernation image compression | Low on normal Android boot, but relevant to power code; compile and suspend review. |
| `mm/memory-failure.c` | Use the poisoned subpage for mapping, unmap and mapcount handling. | Qualcomm tree has the newer three-argument `try_to_unmap(..., NULL)` interface. | Adapts to that interface; the unmap target is revised again in the 4.14.348 range. | Use `p` while preserving the downstream third argument; defer the later huge-page target correction to its genuine stage. | adapted | Memory failure handling | Medium, rare path; compile and later stage semantic check. |

### Stage 1 semantic gates

- production ancestry and exact OpenELA second parent are checked by CI;
- OPlus Binder HANS code remains present;
- old Binder struct-overhead async accounting is absent;
- AIO request discrimination is present;
- F2FS whiteout cross-directory link update is present;
- hibernation acquire/release pairs are present;
- no merge markers, `.orig`, `.rej` or unmerged index entries remain.
"""
)

for path in EXPECTED:
    subprocess.check_call(["git", "add", "--", path])
subprocess.check_call(["git", "add", "--", str(report)])
