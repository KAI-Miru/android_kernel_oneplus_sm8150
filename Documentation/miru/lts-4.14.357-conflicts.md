# Miru H.40 OpenELA Linux 4.14.357 conflict ledger

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
