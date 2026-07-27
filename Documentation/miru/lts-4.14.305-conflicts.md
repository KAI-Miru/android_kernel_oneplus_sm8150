# Miru H.40 to Android Common 4.14.305 integration ledger

This ledger tracks the staged integration of Android Common Linux `4.14.270`
through `4.14.305` into the Miru H.40 OnePlus 7 Pro kernel. It distinguishes
Git index resolution from semantic resolution and separately tracks regressions
introduced by cleanly merged changes.

## Current status

- Production branch: `miru-h40`
- Integration branch: `miru-h40-lts305-integration`
- Immutable production baseline: `61371a1024e341f434deaf61b79a05f73827260a`
- Production baseline version: Linux `4.14.269`
- Previous Android Common target: `0eec6f6001d15bb1108835a642ec4637d75eef19`
- New Android Common target: `4415bf5e08942aee6487946a3e0a50956ef68f1e`
- Stable range: `4.14.270` through `4.14.305`
- Ledger preparation date: `2026-07-27`
- Reconnaissance: **complete**
- Target object verification: **PASS**
- Authentic merge preview: **complete**
- Authentic merge scaffold: **created and verified**
- Initial authentic conflicts: **33**
- Index-resolved conflicts: **33**
- Semantically resolved conflicts: **10**
- Remaining semantic conflicts: **23**
- Cleanly merged paths in authentic preview: **2067**
- Full kernel build: **not performed**
- External-module build: **not performed**
- Physical device testing: **not performed**
- Boot/runtime testing: **not performed**
- Flashing: **not performed**
- Production merge: **not performed**

## Mandatory baseline verification

The live `miru-h40` ref was read directly from GitHub before branch creation and
again before every guarded write. It resolved to:

```text
61371a1024e341f434deaf61b79a05f73827260a
```

The top-level `Makefile` at that exact commit reports:

```text
VERSION = 4
PATCHLEVEL = 14
SUBLEVEL = 269
```

Verified baseline ancestry and prior-milestone evidence:

- Android Common `4.14.269` target
  `0eec6f6001d15bb1108835a642ec4637d75eef19` is an ancestor of production.
- Previously validated source
  `14d41d8a57b1e08aa15ff786973b855c78f58fd7` is an ancestor of production.
- Previous documentation-only head
  `15785765ddf700681daa8ead543b5811ffa000ad` is prior milestone evidence,
  not the assumed production SHA.
- `Documentation/miru/lts-4.14.269-conflicts.md` records all 22 authentic
  conflicts semantically resolved and zero remaining semantic conflicts.
- `Documentation/miru/lts-4.14.269-validation.md` records a successful full
  kernel build, the exact 32-module external set, matching vermagic and zero ABI
  errors, including binary exported-symbol CRC validation with
  `CONFIG_MODVERSIONS`.

The integration branch was created directly from the exact live production SHA.
No previous integration branch was used as its base.

## Authoritative Android Common target

- Repository: `https://android.googlesource.com/kernel/common`
- Tag: `ASB-2023-02-05_4.14-stable`
- Annotated tag object: `fb7d1aa1e00554d9ac07b2a6267f58e585569b81`
- Peeled target commit: `4415bf5e08942aee6487946a3e0a50956ef68f1e`
- Target tree: `b13cdb6b1f31e75df2d2dddeed15b04dceeed939`
- Target version: Linux `4.14.305`
- Target first parent: `73bddffbbe38cc3c99c98cc1c2b329a5f20c9ae6`
- Target second parent: `a8ad60f2af5884921167e8cede5784c7849884b2`
- Previous Android Common target: `0eec6f6001d15bb1108835a642ec4637d75eef19`

GitHub Actions run `30233833545` fetched the exact tag directly from official
Android Common and demonstrated all of the following before the authentic merge
preview:

1. `refs/tags/ASB-2023-02-05_4.14-stable` resolved to the expected tag object.
2. The object type was `tag`.
3. Peeling resolved to the expected target commit.
4. The peeled object type was `commit`.
5. Re-hashing the canonical tag payload reproduced
   `fb7d1aa1e00554d9ac07b2a6267f58e585569b81`.
6. Re-hashing the canonical commit payload reproduced
   `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
7. The target tree was exactly
   `b13cdb6b1f31e75df2d2dddeed15b04dceeed939`.
8. The target `Makefile` reported `VERSION = 4`, `PATCHLEVEL = 14` and
   `SUBLEVEL = 305`.
9. The previous `4.14.269` target was an ancestor of the new target.
10. The new target was not an ancestor of production.

The Android tag object contains no embedded PGP signature. No GPG verification
claim is made.

### Object-verification and preview artifact

- Successful workflow run: `30233833545`
- Exact source head: `b387c2a84d031a26ff44edd66e2a867c5aaf2b9b`
- Artifact name: `miru-lts305-recon-30233833545`
- Artifact ID: `8641000034`
- Size: `8029014` bytes
- Digest: `sha256:e7d3e59f1ae11809086b1c31a2948f80c20c38edad559ab3c07ef18304ea2e71`
- Created: `2026-07-27T03:11:53Z`
- Expires: `2026-08-10T03:11:52Z`

The first attempt, run `30233578031`, passed object verification but could not
start the merge because Git had no local committer identity. Its exact error was
`Committer identity unknown`. No merge state or repository ref was produced.
The corrected run configured a local workflow-only identity and passed.

## Pinned H.40 build environment

The following revisions and entry points remain immutable for this milestone
unless a verified incompatibility is isolated and separately justified:

- Vendor/modules repository:
  `KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150`
- Vendor/modules commit: `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`
- Expected external modules: exactly `32`
- Clang repository commit: `252aba16f513a857bc923172f67b0e55e23de35f`
- Clang package: `clang-r377782c`
- AArch64 GCC/binutils commit: `606f80986096476912e04e5c2913685a8f2c3b65`
- ARM32 GCC/binutils commit: `b0c6a654327ca8796bed1e61dffcf523d04dceaa`
- AOSP build-tools commit: `7322db1e1e4715fe217a27f721613e6be8438676`
- Production stock config: `h40-repro/config/GM1911_11_H.40.config`
- Production build driver: `h40-repro/build-h40.sh`
- Kernel CI wrapper: `scripts/miru/ci_build_4.14.190.sh`
- External-module driver: `scripts/miru/build_external_modules_4.14.190.sh`

No toolchain, config or vendor-source upgrade is part of this LTS integration.

## Repository reconnaissance

- Default and production branch: `miru-h40`
- Immutable production SHA: `61371a1024e341f434deaf61b79a05f73827260a`
- Production source version: Linux `4.14.269`
- Ledger path: `Documentation/miru/lts-4.14.305-conflicts.md`
- Existing integration branch check before creation: branch absent
- Integration branch creation point: exact production SHA above
- Previous exact validated source is present in production ancestry.
- New target object is available in the repository object graph but is not in
  production ancestry.
- Draft helper PR: `#70`, explicitly marked **DO NOT MERGE**.
- Completed preview-only push workflow was retired after successful artifact
  retrieval to prevent obsolete repeated runs.

## Authentic merge preview

The exact command was:

```text
git merge --no-commit --no-ff 4415bf5e08942aee6487946a3e0a50956ef68f1e
```

The successful preview produced the expected nonzero merge exit status because
33 content conflicts remained. Evidence preserved in artifact `8641000034`:

- complete merge stdout and stderr;
- complete porcelain and short status;
- exactly 33 conflicted paths;
- exactly 99 unmerged index entries, proving stages 1, 2 and 3 existed for all
  33 conflicts;
- every stage-1/base, stage-2/Miru and stage-3/Android Common blob;
- raw and name-status index/worktree diffs;
- 2067 cleanly merged paths listed separately;
- pre-preview and post-abort status and index evidence;
- SHA-256 manifest for every diagnostic file.

After `git merge --abort`:

- restored head: `b387c2a84d031a26ff44edd66e2a867c5aaf2b9b`
- restored tracked tree: `d5b23d98ebd90b3baf1b58310054f6f888622292`
- tracked worktree restoration: **PASS**
- staged diff restoration: **PASS**
- workflow-created `lts305-recon/` diagnostics were ignored only for tracked
  cleanliness checks.

## Authentic scaffold procedure

The scaffold job is allowed to proceed only from this ledger/preparation commit.
It must independently repeat production-ref, integration-ref, object, version,
ancestry and exact conflict-manifest gates.

The required scaffold parent order is:

- parent 1: this final ledger/preparation commit based on production;
- parent 2: `4415bf5e08942aee6487946a3e0a50956ef68f1e`.

The job must retain every cleanly merged stage-0 entry exactly as Git produced
it. It may stage only the stage-2/Miru blob for each of the 33 authentic conflict
paths, and must prove those staged blobs equal the preserved stage-2 identities.
Every such path remains `index-resolved but semantically unresolved` after the
scaffold. The push is non-force and guarded by exact live production and
integration SHAs immediately before writing.

## Authentic conflict manifest

All conflicts were `UU` content conflicts and all had stages 1, 2 and 3.
Subsystem labels below are preliminary audit groupings, not final commit groups.

| # | Path | Provisional subsystem | Index status | Semantic status | Owning commit | Targeted compile | Clean reversal |
|---:|---|---|---|---|---|---|---|
| 1 | `Documentation/arm64/silicon-errata.txt` | ARM64 errata documentation | index-resolved in scaffold | resolved | `8633007f8d97174821bd9f200aa675e50e4bd9f2` | targeted compile PASS | clean reversal PASS |
| 2 | `arch/arm64/Kconfig` | ARM64 configuration / mitigations | index-resolved in scaffold | resolved | `8633007f8d97174821bd9f200aa675e50e4bd9f2` | targeted compile PASS | clean reversal PASS |
| 3 | `arch/arm64/include/asm/cpucaps.h` | ARM64 CPU capabilities | index-resolved in scaffold | resolved | `8633007f8d97174821bd9f200aa675e50e4bd9f2` | targeted compile PASS | clean reversal PASS |
| 4 | `arch/arm64/include/asm/cputype.h` | ARM64 CPU identification | index-resolved in scaffold | resolved | `8633007f8d97174821bd9f200aa675e50e4bd9f2` | targeted compile PASS | clean reversal PASS |
| 5 | `arch/arm64/kernel/cpu_errata.c` | ARM64 CPU errata | index-resolved in scaffold | resolved | `8633007f8d97174821bd9f200aa675e50e4bd9f2` | targeted compile PASS | clean reversal PASS |
| 6 | `arch/arm64/kernel/setup.c` | ARM64 boot/setup | index-resolved in scaffold | resolved | `8633007f8d97174821bd9f200aa675e50e4bd9f2` | targeted compile PASS | clean reversal PASS |
| 7 | `arch/arm64/mm/mmu.c` | ARM64 MMU / mappings | index-resolved in scaffold | resolved | `8633007f8d97174821bd9f200aa675e50e4bd9f2` | targeted compile PASS | clean reversal PASS |
| 8 | `drivers/char/Kconfig` | character-driver configuration | index-resolved in scaffold | unresolved | — | — | — |
| 9 | `drivers/clk/qcom/clk-rcg2.c` | Qualcomm clock RCG | index-resolved in scaffold | unresolved | — | — | — |
| 10 | `drivers/edac/edac_device.c` | EDAC polling/lifetime | index-resolved in scaffold | unresolved | — | — | — |
| 11 | `drivers/mailbox/mailbox.c` | mailbox core | index-resolved in scaffold | unresolved | — | — | — |
| 12 | `drivers/mmc/core/host.c` | MMC host core | index-resolved in scaffold | unresolved | — | — | — |
| 13 | `drivers/mmc/core/mmc_ops.c` | MMC command operations | index-resolved in scaffold | unresolved | — | — | — |
| 14 | `drivers/mmc/host/sdhci.c` | SDHCI host | index-resolved in scaffold | unresolved | — | — | — |
| 15 | `drivers/net/ethernet/stmicro/stmmac/stmmac_hwtstamp.c` | Ethernet timestamping | index-resolved in scaffold | unresolved | — | — | — |
| 16 | `drivers/rpmsg/qcom_glink_native.c` | Qualcomm GLINK | index-resolved in scaffold | resolved | `0986f57a7fed5bf69ca14f141666a648a1471350` | targeted compile PASS | clean reversal PASS |
| 17 | `drivers/usb/core/quirks.c` | USB device quirks | index-resolved in scaffold | unresolved | — | — | — |
| 18 | `drivers/usb/dwc3/core.c` | DWC3 core / power | index-resolved in scaffold | unresolved | — | — | — |
| 19 | `drivers/usb/gadget/function/f_fs.c` | FunctionFS / ADB | index-resolved in scaffold | unresolved | — | — | — |
| 20 | `drivers/usb/gadget/function/rndis.c` | USB RNDIS gadget | index-resolved in scaffold | unresolved | — | — | — |
| 21 | `drivers/usb/host/xhci.c` | xHCI host lifecycle | index-resolved in scaffold | unresolved | — | — | — |
| 22 | `drivers/usb/host/xhci.h` | xHCI interfaces | index-resolved in scaffold | unresolved | — | — | — |
| 23 | `fs/fat/fatent.c` | FAT allocation table | index-resolved in scaffold | unresolved | — | — | — |
| 24 | `include/net/netfilter/nf_queue.h` | netfilter queue API | index-resolved in scaffold | unresolved | — | — | — |
| 25 | `include/net/sock.h` | socket core API | index-resolved in scaffold | unresolved | — | — | — |
| 26 | `include/uapi/linux/virtio_ids.h` | Virtio UAPI IDs | index-resolved in scaffold | unresolved | — | — | — |
| 27 | `kernel/exit.c` | task exit / oops handling | index-resolved in scaffold | resolved | `6f9a178101753ca7e5dab46d963609d34ea2cc23` | targeted compile PASS | clean reversal PASS |
| 28 | `kernel/panic.c` | panic/warn accounting | index-resolved in scaffold | resolved | `6f9a178101753ca7e5dab46d963609d34ea2cc23` | targeted compile PASS | clean reversal PASS |
| 29 | `lib/Makefile` | library build composition | index-resolved in scaffold | unresolved | — | — | — |
| 30 | `mm/memory.c` | page fault / memory core | index-resolved in scaffold | unresolved | — | — | — |
| 31 | `net/ipv4/tcp_output.c` | IPv4 TCP output | index-resolved in scaffold | unresolved | — | — | — |
| 32 | `net/ipv6/ip6_output.c` | IPv6 output / fragmentation | index-resolved in scaffold | unresolved | — | — | — |
| 33 | `net/netfilter/nf_conntrack_irc.c` | IRC conntrack parsing | index-resolved in scaffold | unresolved | — | — | — |

Clean merges and future clean-merge corrections do not increase this authentic
conflict count.

## Semantic resolution requirements

Final subsystem groupings will be chosen only after inspecting merge-base, Miru
and Android Common stages and relevant history. Each resolution commit must:

- own an explicit set of authentic conflict paths;
- record merge-base, Miru and Android Common behavior;
- cite relevant upstream commits;
- explain the downstream semantic decision and vendor-interface impact;
- preserve Miru, Qualcomm, OnePlus and vendor-module behavior unless evidence
  proves a behavior obsolete or unsafe;
- compile the smallest meaningful object or subsystem;
- revert cleanly in a disposable worktree;
- restore every owned path exactly to scaffold state after reversal;
- update this ledger before guarded push.

No-source-delta resolutions still require explicit ownership and evidence that
the retained Miru implementation already contains the target behavior.

## Mandatory clean-merge semantic audit

- [ ] DT2W and touchscreen gestures
- [ ] AOD luminance, HBM and brightness
- [ ] MSM/SDE shutdown and last-close paths
- [ ] GPU GEM/import/cache behavior
- [ ] smart-PA and audio
- [ ] USB gadget, FunctionFS, ADB, accessory and charging
- [ ] UFS initialization, suspend, resume and shutdown
- [ ] Qualcomm IPC, GLINK and QRTR
- [ ] reserved networking-port policy
- [ ] Binder and ColorOS 14 compatibility
- [ ] OPlus touchscreen/display interfaces
- [ ] scheduler, timerqueue and hrtimer APIs
- [ ] credential, namespace and capability APIs
- [ ] `CONFIG_MODVERSIONS`, exported symbols and CRCs
- [ ] private interfaces consumed by external modules
- [ ] every Miru change added after the prior 4.14.269 scaffold
- [ ] removed fields, changed return conventions and obsolete initializers
- [ ] dead labels and altered locking/lifetime requirements

Every discovered clean-merge regression must be reproduced, traced, fixed in a
separate focused commit, targeted-compiled, cleanly reversed, recorded here and
followed by a full build from the new exact source head.

## Build validation checklist

Pre-build source gates:

- [ ] exact integration head recorded
- [ ] production baseline remains an ancestor
- [ ] Android Common 4.14.305 target is an ancestor
- [ ] authentic scaffold parent order verified
- [ ] zero remaining authentic conflicts
- [ ] zero remaining semantic conflicts
- [ ] ledger ownership consistency verified
- [ ] top-level `SUBLEVEL = 305`
- [ ] pinned vendor and toolchain revisions verified
- [ ] QRTR/GLINK protected source gates pass
- [ ] no unexpected source drift after final correction

Kernel and module outputs:

- [ ] `Image`
- [ ] `Image.gz`
- [ ] `Image.gz-dtb`
- [ ] DTBs
- [ ] in-tree modules
- [ ] exactly 32 expected external modules
- [ ] exact kernel release recorded
- [ ] non-empty image checks pass
- [ ] SHA-256 manifests preserved
- [ ] DTB count recorded
- [ ] `Module.symvers` preserved
- [ ] exact module-name manifest matches
- [ ] all modules are AArch64
- [ ] all 32 vermagic strings match the kernel
- [ ] binary symbol CRC compatibility passes
- [ ] integration-attributable unresolved symbols equal zero
- [ ] ABI audit errors equal zero

## Explicit safety status

- Physical device testing: **not performed**
- Boot/runtime testing: **not performed**
- Flashing: **not performed**
- Production merge: **not performed**
- Production branch modification during this milestone: **prohibited**

## Authentic scaffold evidence

- Scaffold commit: `b92a77e96dd54fd30f8f39c7eef23e76f211c515`
- Parent 1 (preparation): `b125a425ef1559871b1d6cd662806c8afc53e934`
- Parent 2 (Android Common): `4415bf5e08942aee6487946a3e0a50956ef68f1e`
- Scaffold workflow run: `30234354643`
- Scaffold artifact ID: `8641187330`
- Parent order: **PASS**
- Cleanly merged stage-0 preservation: **PASS for 2067 paths**
- Conflicted stage-2/Miru preservation: **PASS for 33 paths**

## Semantic resolution records

### ARM64 errata, CPU capabilities, FDT setup and MMU

- Owning source commit: `8633007f8d97174821bd9f200aa675e50e4bd9f2`
- Owned paths: `Documentation/arm64/silicon-errata.txt`, `arch/arm64/Kconfig`, `arch/arm64/include/asm/cpucaps.h`, `arch/arm64/include/asm/cputype.h`, `arch/arm64/kernel/cpu_errata.c`, `arch/arm64/kernel/setup.c`, `arch/arm64/mm/mmu.c`.
- Relevant Android Common commits: `786ec17678a480c8dc31620aca56b117ac191a6a`, `9aeb4a5a73d392580a2f5ee018dfe5506a2e8359`, `3aee35ffc45b29e795573c047930fb849830806b`, `0b1c660d8516e8960227a92b9ee890e9e3682b31`, `3e3904125fccd042fda24294624e8f66699fd06d`, `2e53c83ea673b657d33cc4fa0018fe41b500afe4`, `06035fd1efb772a178f4a0848d20731ba0973860`, `3c2ae48eceaa40f1ecb18ba31dda3f6fe755796c`, `64bb608e39b5bf0455a9c2380f16f79518a7b4c6`, `9e8261dfa7570b671f2655d68d58f749a2fc856e`, and `a6d363d48a816877d9f9d12da8fc5ed786e333b8`.
- Downstream intent retained: Cortex-A76 erratum 1286807; Qualcomm Kryo CPU identifiers and the Kryo-4G erratum 1188873 range; `arch_read_machine_name()`; boot-reason/cold-boot interfaces; the downstream early memblock reservation diagnostic; memory-hotplug and mapping behavior outside the conflict hunks.
- Android behavior imported: the complete timer out-of-line workaround for erratum 1188873 with `COMPAT` dependency; Spectre-BHB capability numbering and mitigation registration; erratum 1742098 COMPAT AES masking; current ARM part identifiers; multi-page trampoline-compatible MMU layout; and the FDT read-write early scan followed by read-only remapping.
- Semantic decision: take a strict union where identifiers and mitigations are independent, retain Qualcomm-specific ranges, and migrate downstream early-FDT users to the target `fixmap_remap_fdt(dt_phys, &size, prot)` API. The obsolete one-argument MMU wrapper is removed because all remaining callers use the cleanly merged size/protection interface.
- Audited source patch SHA-256: `9e81960bc6b5eff4b6ac9fa108f5ae96a3d22e862cfaa62bbc097746d440f2c6`.
- Targeted compilation: **PASS** for `arch/arm64/kernel/setup.o`, `arch/arm64/kernel/cpu_errata.o`, `arch/arm64/kernel/cpufeature.o`, `arch/arm64/kernel/entry.o`, and `arch/arm64/mm/mmu.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Clean reversal: **PASS**; reverting `8633007f8d97174821bd9f200aa675e50e4bd9f2` in a disposable worktree restored all seven owned paths exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`.
- Validation workflow run: `30237605611`.

- Validation artifact: run `30237605611`, artifact `8642205498`, digest `sha256:afae78d8aaed42e59eb08d92362b7f8740f609e9ce4903f85ce3e639c09b26f2`, size `20433` bytes.
- Canonical patch serialization: `git diff --binary --full-index`; artifact patch SHA-256 `9e81960bc6b5eff4b6ac9fa108f5ae96a3d22e862cfaa62bbc097746d440f2c6`.

### Task-exit and panic/warn hardening

- Owning source commit: `6f9a178101753ca7e5dab46d963609d34ea2cc23`
- Owned paths: `kernel/exit.c`, `kernel/panic.c`.
- Relevant Android Common commits: `5eded74b4928860a7d75928c4842b103e02c0853`, `53aca559a2a58025012ea2d9ff69259a0ae582b2`, `784bf591aebdf26e3b08c03a48d6b91dd052e83b`, `2ba1ec154608abb51c4b588542f903ca51db6fe7`, `4ba2f65e6f48e08d8888efb2c14be1f315ee25e6`, `3bd9e479d3bd1a11a5b4f640627413ef6c0db30a`, `a83bcc5fc4e93b76d225981d83d22dbfe353dbd8`, `f86706f4580f141e5ad7812559cbd03b4618f9f1`, and `11bece14153cd05b9e823d6452f2483003150d0a`.
- Downstream intent retained: virtual-reserve-memory task-exit integration; Qualcomm minidump and panic tracepoints; panic-time device-cache flush; download-mode gating; and OPlus aging-test dump-reason persistence.
- Android behavior imported: `make_task_dead()`, bounded oops and warning counters, disable-able `oops_limit`, `warn_limit`, sysctl/sysfs exposure, `READ_ONCE()` limit reads, consolidated `check_panic_on_warn()`, and panic-path reset of `panic_on_warn`.
- Semantic decision: strict union of independent platform diagnostics with the upstream repeated-oops/repeated-warning hardening. The generic counters and limits do not replace or bypass Miru crash collection.
- Audited source patch SHA-256: `1c719cf6207dd2e93928710e6420b3d812ac7b124655151173ebcc1b63733446` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `kernel/exit.o` and `kernel/panic.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Clean reversal: **PASS**; reverting `6f9a178101753ca7e5dab46d963609d34ea2cc23` restored both owned paths exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`.
- Validation workflow run: `30238384152`.

### Qualcomm GLINK channel teardown and RX error propagation

- Owning source commit: `0986f57a7fed5bf69ca14f141666a648a1471350`
- Owned path: `drivers/rpmsg/qcom_glink_native.c`.
- Relevant Android Common commit: `12faed72cf1a7e32253cb7b839104e03a923cbff` (upstream `766279a8f85df32345dbda03b102ca1ee3d5ddea`).
- Downstream commits retained: `0ba2ae45391418c93ab9af4f7a24acbcfa678a11`, `bdd4cc49080e8a0a56c844600c4e243aa1ad7b97`, and `935b66cf9efbcbd40063e830935744b35a3d5cf`.
- Downstream intent retained: a missing channel intent advances the RX FIFO; a missing local intent drains the current payload before returning `-ENOENT`; and the native interrupt loop propagates all RX errors instead of suppressing `-ENOENT`.
- Android behavior imported: `qcom_glink_rx_close()` now uses `strscpy_pad()` for the fixed-size channel name, preserving NUL termination and the original padding contract without deprecated `strncpy()` semantics.
- Semantic decision: replace only the target-range `qcom_glink_rx_close()` copy. The downstream-only `qcom_glink_rx_close_ack()` teardown remains otherwise unchanged, and all Miru FIFO/error-propagation fixes are source-gated.
- Audited source patch SHA-256: `d257d6330ea310935320023e090dfb59aff0cc92cdbb137d5620bac62632af4f` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/rpmsg/qcom_glink_native.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Protected GLINK source gates: **PASS**.
- Clean reversal: **PASS**; reverting `0986f57a7fed5bf69ca14f141666a648a1471350` restored the owned path exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`.
- Validation workflow run: `30240476056`.
