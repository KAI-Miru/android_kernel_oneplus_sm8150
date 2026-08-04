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
