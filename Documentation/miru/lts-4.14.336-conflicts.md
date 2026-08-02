# Miru H.40 Android Common Linux 4.14.336 integration ledger

## Status

- Integration status: **COMPLETE — authentic candidate merge created**
- Candidate branch: `miru-h40-lts336-release`
- Candidate parent before authentic merge: `94d2f7f9ac571047c961addbc73aa703b5762293`
- Production branch: `miru-h40` at `a97fcbe96ab6d8392a0a0acf91da46ccb37fdaee` (**must remain unchanged during candidate work**)
- Previous production merge: `489177590738e082a37e17fc9ef9290e4f168058` (`4.14.305-miru-h40-lts305-ci1+`)
- Pristine OnePlus H.40: `180d787684d5965be5145bcfbf666ed427b4ea18`
- Previous Android Common baseline: `4415bf5e08942aee6487946a3e0a50956ef68f1e` (4.14.305)
- Android Common target: `014241ad77dda0eafbdf671d5b8e86917d8ec97e` (4.14.336)
- Android Common branch: `deprecated/android-4.14-stable`
- Target parent order: `bc841b804f61c5918bd950ccb15e63c36f5bd0b5`, then `c31e35278ea8f04f1dceadd77dca4dd7d47932a3`
- Authentic merge parent order: candidate parent first, exact Android Common target second
- Authentic conflicts: **14**
- Semantic resolutions: **14 of 14 complete**
- Kernel/module/ABI validation: **pending**
- Physical OnePlus 7 Pro validation: **pending**
- Production promotion: **not authorized**

## Provenance capture

Read-only workflow run `30746964504` reproduced the authentic merge without committing or pushing. It verified all permanent refs, exact Android Common branch head, target version, target parent order, and 4.14.305 ancestry.

The run captured 69 files containing the merge output, clean-overlap lists, all conflict worktrees, and every base/Miru/Android Common index stage.

- Artifact ID: `8833225158`
- Artifact name: `miru-h40-lts336-conflict-audit-a8eae8c8a7b3ee337f3a15016fee6bc2afea24b3`
- Artifact SHA-256: `ce63a76dd0513316c23777832217c0b356c35faf25a886052bb0bdae5136e7f7`
- Candidate write gate: **PASS — none**
- Production write gate: **PASS — none**

The deterministic resolver refuses to run unless all 14 paths and all 42 stage mode/blob pairs match this ledger exactly. It also verifies every final mode/blob before staging.

## Conflict resolutions

| # | Path | Android Common intent | Semantic resolution | Final blob |
|---:|---|---|---|---|
| 1 | `drivers/devfreq/devfreq.c` | `7462483446cb` — release notifier resources | Preserve downstream `event_lock` destruction and add Android Common `srcu_cleanup_notifier_head()` teardown. | `ffa38b2a847440ef62661d1a8b72e43ff61dc875` |
| 2 | `drivers/gpu/drm/drm_mipi_dsi.c` | `bbff585cb5a5` — correct 16-bit DCS brightness byte order | Preserve OnePlus `mipi_dsi_dcs_write_c1()` and add both Android Common 16-bit brightness set/get helpers. | `2b0af50e5e0999478a584c62b41b32c22909294f` |
| 3 | `drivers/mmc/core/block.c` | `be24f8aae42e` — propagate non-block request errors | Preserve the downstream RPMB-aware opcode selection and initialize `drv_op_result = -EIO` in both ioctl paths. Normalize accidental executable mode to `100644`. | `db2fdbbe7478ba7d389383e6e7d930d18e44bffe` |
| 4 | `drivers/mtd/ubi/wl.c` | `b40d2fbf47af` — avoid infinite loop after wear-leveling failure | Apply Android Common's missing-entry guard before the downstream `e->sqnum = UBI_UNKNOWN` assignment; retain downstream sequencing and all clean target locking/UAF fixes. | `404cb6e1099cb3f9a7b36a9a9ff715419b7104cc` |
| 5 | `drivers/thermal/thermal_core.c` | `b55f0a9f865b` — prevent sysfs-name overflow | Keep downstream upper/lower cooling-limit attributes and convert upper, lower, and weight name formatting to bounded `snprintf()`. | `6df9a1c24217ae7463be653b7525c82b1e7464ae` |
| 6 | `drivers/usb/dwc3/core.c` | `7dfe8f6ecf6c`, `585003299bb4` — DMA segmentation and runtime-PM balance | Add `dma_set_max_seg_size(dev, UINT_MAX)`. Do not transplant the conflicting upstream probe/remove runtime-PM and core/ULPI teardown calls because the downstream Qualcomm probe path never acquires/initializes those matching resources; preserve downstream `pm_runtime_allow()` lifecycle. | `f2602eb6901f4ff2e7fbbad6bef2b9c560f7aadd` |
| 7 | `drivers/usb/dwc3/gadget.c` | `a217bcfd2196` — process pending events safely after runtime resume | Combine downstream null/reset/instrumentation with the target runtime-PM suspended-event reference. Resolve an additional clean-merge incompatibility: Miru's Qualcomm `dwc3_interrupt()` takes `struct dwc3 *` and queues work, while target code assumes an event-buffer callback. Process the pending buffer synchronously through `dwc3_check_event_buf()` and `dwc3_thread_interrupt()`, then balance `pm_runtime_put()`. | `f897b4fbda584d473f8a96cdd4440e2b4425c782` |
| 8 | `drivers/usb/gadget/function/f_fs.c` | `3bd7816c9aad` — emit UNBIND before unbinding | Move `FUNCTIONFS_UNBIND` event insertion before the possible `functionfs_unbind()` call and retain downstream logging without duplicating the event. | `57f07af22817b0bbf8b252bc4eb017177455f6e6` |
| 9 | `include/net/pkt_sched.h` | qdisc policy/MTU hardening in the 4.14.305→336 delta | Keep downstream `tc_qdisc_flow_control()`, add target `rtm_tca_policy`, and retain target `READ_ONCE(dev->mtu)`. Normalize accidental executable mode to `100644`. | `317dcf495a8f198950a7ee6fb262bbff489e2097` |
| 10 | `init/main.c` | `b90a399294b5` — invoke `arch_cpu_finalize_init()` earlier | Retain Oplus Phoenix boot-stage reporting. Use the target's earlier `arch_cpu_finalize_init()` path and remove the now-duplicated direct `check_bugs()` call from `kernel_init_freeable()`. | `bc4e5bb5430c7da5a71195c1daa34fbc429d1c4d` |
| 11 | `kernel/events/core.c` | perf inheritance hardening in the 4.14.305→336 delta | Increment the inherited leader generation before downstream shared-event leader rewriting; preserve Miru shared-event behavior and target inherited-group mismatch safeguards. | `9ad14fba1fc171f45f58456d92b84c01da92cf14` |
| 12 | `kernel/sched/fair.c` | `53ab79e0ba72`, `6d26b74599ef` — sanitize long-sleeper/migrated vruntime | Apply Android Common long-sleeper vruntime sanitization, then retain the Oplus UX placement hook. Normalize accidental executable mode to `100644`. | `eb4e41c0f0df42567f73cea1c7e3c8f5c5a5898d` |
| 13 | `lib/ubsan.h` | `2da066a76c2f` — remove obsolete returns-nonnull checks | Keep Miru's compiler-compatible `nonnull_arg_data` layout and reject the target's older duplicate layout. Target removal of obsolete `nonnull_return_data` remains present. Final content intentionally equals the Miru stage-2 blob. | `f3e96ddf9bcad11e3a03e3297275a5f1d7545d02` |
| 14 | `scripts/checkpatch.pl` | `f7b745e6246e` — Android Mainline checkpatch snapshot | Integrate the target snapshot while retaining Miru's stable-address rule, Qualcomm author rule, and long-macro workaround; add Gerrit Change-Id and DT schema checks; correct the downstream “concatenation” spelling. Perl syntax is required to pass. | `fe521eb72ad53ed4a0c72639ed089ec920822b40` |

## Exact conflict stage manifest

| Path | Base blob | Miru stage-2 blob | Android Common stage-3 blob | Final mode |
|---|---|---|---|---|
| `drivers/devfreq/devfreq.c` | `b05e6a15221c9dfc6ab65a84bf26761aeaa72b73` | `e66ea89537923a3b8232a568e150d173b33f4cc6` | `e6674448a0bc3ae69f223af9f40d7d9cb7e751ec` | `100644` |
| `drivers/gpu/drm/drm_mipi_dsi.c` | `bd5e8661f826a596c99f191298bb948da9a503d7` | `e58eebf6d459a0220c4f4b64fd7a8564976679e6` | `6995bee5ad0fb30582f2b89ca27c9d0e4524cb1f` | `100644` |
| `drivers/mmc/core/block.c` | `f2871464db5b85d2e01e387e40703ef15ca616d0` | `21c4179c26706167ca0298b46e2e9149c4dc76cd` | `3fc4bba0f785967d9a03bc95666cf35f6ed3b7e1` | `100644` |
| `drivers/mtd/ubi/wl.c` | `545a92eb8f56977dcd5f480e8ddbf0db6d1a4b05` | `52c108378831c0d3cd44392d335aaf82a8b18f5f` | `4411ce5d1c8fcc940e37bc6f8caa8a1bf26f0e6d` | `100644` |
| `drivers/thermal/thermal_core.c` | `8374b8078b7df60b79077049390ee605fa91d581` | `fa8dbf393e73618dd51c917eb684e3214f86ba75` | `e24d46f7157157664dff54547a498562deb3cbdc` | `100644` |
| `drivers/usb/dwc3/core.c` | `5a4bd093c311fd5a8abbbb45d85af3ef46a34ddd` | `533a1b635e051d27b8691834da3ce6f1d3506179` | `2e0ef23d2122ac4da37282dc09b304649787f81a` | `100644` |
| `drivers/usb/dwc3/gadget.c` | `5d142d7f6272fdbe11854a02291513863ddfc990` | `015201f84063803c8009885c7aae9ca7923ea48e` | `0b65328adff17d8679abe2b8625ae36568c0b4c7` | `100644` |
| `drivers/usb/gadget/function/f_fs.c` | `946cf039edddb7d5cf4b144c61703218a24d6c41` | `75f0b7e042bce29ce74418808f1ec2d44ae673e4` | `b66b70812554d3151221f67b6a164624ee49ecb9` | `100644` |
| `include/net/pkt_sched.h` | `b3869f97d37d777224c4e925b2f89d853b3211a4` | `9a90f99fa554d95dec0a23f8ca2a87a9870a588d` | `7b6024f2d4eaa0d151f75394b73fbeca7eac05a9` | `100644` |
| `init/main.c` | `d50ea3c3473e7c84fee9eb94859686e99a234208` | `46a986812509dab8d0a1769364b8557687fb7ddd` | `4a0518fbfd21d0e68b62aeca74d9f4cc8e94c36a` | `100644` |
| `kernel/events/core.c` | `19993a31d3106386c0888c78ff797ed5fe8b61df` | `71b136b7750e65a5763f54977164eefb4ae11908` | `4a1e54b83ca351de73460f81f8d2fda66372c39b` | `100644` |
| `kernel/sched/fair.c` | `2ffa6ee813ada10f4bd6f99bd4103a6037dc04cb` | `2b91d65923269f242aa1406de35edda76afc5d7f` | `67eede9ddd4c739edd5b45ce4507de598d2069fc` | `100644` |
| `lib/ubsan.h` | `7e30b26497e0cd0e2d7c055222349eac5d228a84` | `f3e96ddf9bcad11e3a03e3297275a5f1d7545d02` | `f4d8d0bd4016f42d7c9c50b66d0250367e8dd555` | `100644` |
| `scripts/checkpatch.pl` | `4107f4094e0cabad95064e762936b998e085c093` | `b340a951e355208f86f99a3f2e827492d487c2da` | `25fdb7fda1128aa99d2d32ee3a125fc4c00292cf` | `100755` |

## Resolution integrity gates

The merge workflow must fail before any push unless all of these are true:

1. Production, pristine H.40, rollback tag, and candidate refs match their expected SHAs.
2. The named Android Common branch advertises the exact 4.14.336 target.
3. Target version, target parents, and 4.14.305 ancestry match exactly.
4. The authentic merge produces exactly the 14 paths above and no others.
5. Every base/Miru/target stage mode and blob matches this ledger.
6. Every resolved file mode and final blob matches the deterministic resolver manifest.
7. No unmerged index entry or conflict marker remains.
8. `git diff --cached --check` and `perl -c scripts/checkpatch.pl` pass.
9. KCAL files and the pinned H.40 config remain byte-identical to the candidate parent.
10. Required OnePlus/Oplus/Qualcomm runtime paths remain present.
11. The DWC3 clean-merge callback/runtime interaction is explicitly gated.
12. The resulting merge commit has candidate parent first and exact Android Common target second.
13. Production is re-read immediately before the guarded candidate-only push and is still exact.

## Remaining gates

The authentic merge is only the source-integration boundary. It is not a test-ready kernel until candidate CI proves the final identity, exact five DTBs, 13 in-tree modules, pinned 32 external modules, vermagic, MODVERSIONS/CRC compatibility, unresolved-symbol count, package checksums, and provenance/compatibility artifacts.

No production merge may occur until those gates pass, the artifact is physically tested on the OnePlus 7 Pro, and the maintainer explicitly authorizes promotion.

## Deterministic replay closure

The earlier one-off `devfreq.c` final-blob discrepancy was treated as unexplained and blocked integration. Read-only run `30748527303` then reproduced the authentic merge six times: twice at the formerly failing parent, twice at the subsequent passing parent, and twice at the replay workflow parent. All six runs used Git 2.54.0 with rerere and renormalization disabled and produced identical 14-path stage manifests, final mode/blob manifests, resolver reports, and staged patches.

- Replay commit: `c10f24a63e3175db2ddf59231175a0fab4e3c8b6`
- Replay artifact ID: `8833712206`
- Replay artifact SHA-256: `60747de0d01c0b0e1dadafbed72d2787ce7e8dac653d6b3687b4cfc43475d9b9`
- Conflict-stage manifest SHA-256: `2969b2e787bfd3e98fc5fe6768eef686aa39030b3783fe3da8436d7bfc5d2143`
- Final mode/blob manifest SHA-256: `2494ea2e93551dbc89f3c98be8577ce3d3b7acf66b27db217df908f1c6383ca8`
- Resolver report SHA-256: `c84b3d9b14c13d37a57759f8da096b760c60652585fd48fc8042c162b954c01f`
- Resolved staged patch SHA-256: `8ab87ab2ea79c342d61590e842aba8a8b5de452dbd60fbb5dc78681d6627d810`
- Replay result: **PASS — six of six byte-identical**
- Replay repository-write gate: **PASS — none**
