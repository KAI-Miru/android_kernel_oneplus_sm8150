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

## Stage 4 — 4.14.348 to 4.14.352

OpenELA parent: `6da009d8de389742d55219ebed50378f53937a5b`

Initial textual conflicts: **3**. Remaining conflicts: **0**.

The exact guarded dry merge at integration source `37b1def329eee1dd1dfffc54ec16045b866cc304`
produced the three paths below. An earlier predicted inventory naming `Makefile`,
`drivers/media/pci/cx18/cx18-streams.c`, and `drivers/usb/dwc3/core.c` was rejected:
the latter two have identical OpenELA blob identities at the exact 4.14.348 and
4.14.352 parents, while `Makefile` merges automatically. DWC3 and CX18 remain
explicit regression compile targets even though they are not stage-352 conflicts.

| Path | OpenELA intent | Miru divergence | LineageOS reference | Final Miru resolution | Class | Compile impact | Runtime risk / validation |
|---|---|---|---|---|---|---|---|
| `arch/arm/include/asm/uaccess.h` | Remove access-size-specific ARM get-user clobber lists and always declare `ip`, `lr` and condition codes clobbered. | Android's ARM helper calls use `__asmbl()` and `__asmbl_clobber()` for Clang/instruction-selection compatibility. | Preserves the Android assembler macros while applying one generic clobber list. | Adopt the Lineage-compatible form: remove `__GUP_CLOBBER_*`, retain `__asmbl()` calls and declare `__asmbl_clobber("ip"), "lr", "cc"` in both macros. | adapted | Controlled ARM32 uaccess consumer probe | Medium: validate the compatibility header with the pinned Clang/GCC32 pair without changing the ARM64 device defconfig. |
| `fs/f2fs/segment.c` | Log invalid NAT/SIT journal counts before rejecting corrupt summary blocks. | The newer Android F2FS implementation already has the same check through `f2fs_err()`. | Identical to Miru. | Preserve the Android implementation and assert the values are logged before `-EINVAL`. | not applicable | F2FS segment manager | Medium: mount/recovery diagnostics; object compile and corruption-path semantic check. |
| `fs/f2fs/super.c` | Include the actual error code when segment/node-manager initialization fails. | The newer Android F2FS implementation already logs both errors through `f2fs_err()`. | Identical to Miru. | Preserve the Android implementation and assert both `%d` error arguments remain. | not applicable | F2FS mount path | High: userdata mount; object compile and later mount/write physical validation. |

### Stage 4 semantic gates

- exact three-path conflict inventory and exact OpenELA second parent;
- both ARM get-user macros use one conservative Android-compatible clobber set;
- Android F2FS journal validation and initialization error reporting remain present;
- Qualcomm-safe DWC3 direct dispatch repair, QRTR state and GPL audio export remain intact;
- DWC3 core/gadget and CX18 are regression-compiled despite not conflicting;
- no unmerged entries, conflict headers, `.orig` or `.rej` files remain.

## Stage 5 — 4.14.352 to 4.14.356

OpenELA parent: `a76b6a6556353484f6f29572989cd37b6cff90cc`

Initial textual conflicts: **9**. Metadata conflicts: **0**. Remaining conflicts: **0**.

The exact read-only merge audit at integration source
`8d50d842d343c0af619e5774cab891c505e983bd` established the inventory below.
The resolver preserves the newer Qualcomm/Android structures and ports each
independent OpenELA fix into the matching downstream call flow.

| Path | OpenELA intent | Miru divergence | Final Miru resolution | Class | Runtime risk / validation |
|---|---|---|---|---|---|
| `arch/arm64/include/asm/cputype.h` | Add Arm Neoverse N3 part and MIDR definitions. | Miru adds Qualcomm Kryo part/MIDR definitions at the same anchors. | Keep both definition sets, grouped by implementer. | combined | Low; compile an ARM64 CPU-info consumer and retain all Kryo identifiers. |
| `drivers/mmc/core/mmc_test.c` | Return `-ENOMEM` when the optional highmem test allocation fails and use a shared cleanup label. | Miru only made the final free conditional. | Adopt the OpenELA allocation check and cleanup label; a successful allocation is always freed exactly once. | upstream | Low; compile the MMC test object. |
| `drivers/net/usb/usbnet.c` | Stop using one module-global random MAC and let each invalid device address be randomized independently. | Miru initializes downstream IPC logging in the same module-init block. | Remove only `eth_random_addr(node_id)` while retaining the IPC-log initialization; keep the automatically merged per-device MAC handling. | combined | Medium; compile usbnet and verify global `node_id` use is absent. |
| `drivers/usb/dwc3/core.c` | Add a Hisilicon-only split-boundary-disable quirk to the generic role-switch path. | Qualcomm's core replaced that generic role-switch worker with downstream sleep/role handling. | Preserve Qualcomm's role implementation. Keep the automatically merged property, register definitions and resume-complete hook; the quirk remains dormant without `snps,dis-split-quirk`. | adapted | High; compile DWC3 core/gadget and retain the proven direct pending-event dispatch repair. |
| `fs/f2fs/inode.c` | Avoid dirtying an inode on a read-only F2FS mount. | Newer Android already skips newly allocated inodes first. | Keep the Android new-inode gate, then add the OpenELA read-only gate before dirty tracking. | combined | High; userdata filesystem path, object compile and later physical mount/write validation. |
| `fs/f2fs/namei.c` | Set `FI_NEW_INODE` before encryption setup. | Newer Android already does so and uses the newer `f2fs_may_encrypt(dir, inode)` API. | Preserve the newer Android implementation. | not applicable | High; F2FS create path, object compile and later physical validation. |
| `include/linux/clk.h` | Add `clk_get_optional()`. | Qualcomm exposes OF clock-provider helpers even without `CONFIG_COMMON_CLK`. | Add the optional-clock helper and retain Qualcomm's `CONFIG_OF` provider guard. | combined | Medium; compile clock consumers and preserve downstream provider visibility. |
| `net/qrtr/qrtr.c` | Use `pskb_copy()` so every broadcast endpoint gets an independent mutable header. | Miru uses an rwsem, downstream endpoint list, automatic-NID filtering and extra enqueue arguments. | Preserve the downstream traversal and replace only `skb_clone()` with `pskb_copy()`. | adapted | High; modem/IPC path, compile QRTR and physically validate radio/audio services later. |
| `security/selinux/selinuxfs.c` | Reject partial, empty and oversized policy writes before loading. | Android wraps SELinux filesystem state and uses `fsi->mutex` instead of the legacy global mutex. | Apply all three validation gates before taking `fsi->mutex`. | adapted | High; boot-critical policy load, compile SELinuxFS and later physical boot validation. |

### Stage 5 semantic gates

- exact nine-path conflict inventory and exact OpenELA second parent;
- Neoverse N3 and Qualcomm Kryo identifiers coexist;
- MMC highmem allocation failure, per-device usbnet MAC handling and IPC logging coexist;
- Qualcomm DWC3 role handling and direct gadget-event dispatch remain intact;
- F2FS read-only/new-inode ordering is explicit;
- `clk_get_optional()` is present without narrowing Qualcomm's OF provider API;
- QRTR broadcasts use independent headers while retaining downstream endpoint filtering;
- SELinux policy write bounds are checked under the wrapped Android state model;
- no unmerged entries, conflict headers, `.orig`, `.rej` or `.pyc` files remain.
