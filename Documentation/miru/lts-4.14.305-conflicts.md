# Miru H.40 to Android Common 4.14.305 integration ledger

This ledger tracks the staged integration of Android Common Linux `4.14.270`
through `4.14.305` into the Miru H.40 OnePlus 7 Pro kernel. It distinguishes
Git index resolution from semantic resolution and separately tracks regressions
introduced by cleanly merged changes.

## Current status

- Production branch: `miru-h40`
- Clean release branch: `miru-h40-lts305-release`
- Immutable production baseline: `61371a1024e341f434deaf61b79a05f73827260a`
- Production baseline version: Linux `4.14.269`
- Exact boot-tested source: `53f76796d1b68260507a83968a4a4bee3b89754f`
- Android Common 4.14.305 target: `4415bf5e08942aee6487946a3e0a50956ef68f1e`
- Authentic integration merge: `b92a77e96dd54fd30f8f39c7eef23e76f211c515`
- Initial authentic conflicts: **33**
- Index-resolved conflicts: **33**
- Semantically resolved conflicts: **33**
- Remaining semantic conflicts: **0**
- Full kernel build: **PASS** — run `30701388376`
- External-module build: **PASS** — 32 modules
- In-tree module build: **PASS** — 13 modules
- ABI/MODVERSIONS errors: **0**
- Three-way audit: **PASS** — run `30714292944`
- Physical device testing: **PASS**
- Boot/runtime testing: **PASS**
- Flashing: **PASS**
- Production merge: **PASS** — PR #86 normal merge `489177590738e082a37e17fc9ef9290e4f168058`; permanent production run `30735235333` passed

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
| 8 | `drivers/char/Kconfig` | character-driver configuration | index-resolved in scaffold | resolved | `7727a2c3bade0f9d21aaab63a0d58dd13545949b` | Kconfig + random.o PASS | clean reversal PASS |
| 9 | `drivers/clk/qcom/clk-rcg2.c` | Qualcomm clock RCG | index-resolved in scaffold | resolved | `512d47f08402bf130a78e05a92341d62ae04c120` | targeted compile PASS | clean reversal PASS |
| 10 | `drivers/edac/edac_device.c` | EDAC polling/lifetime | index-resolved in scaffold | resolved | `e5e15c01d846b479836c7c8625c98794e9094302` | targeted compile PASS | clean reversal PASS |
| 11 | `drivers/mailbox/mailbox.c` | mailbox core | index-resolved in scaffold | resolved | `8b9ea460afb7692145090c2d307f6695bed12b3c` | targeted compile PASS | clean reversal PASS |
| 12 | `drivers/mmc/core/host.c` | MMC host core | index-resolved in scaffold | resolved | `ee7b6bc5a208fa0afcdebb7bd18882e7d0a8326e` | targeted compile PASS | clean reversal PASS |
| 13 | `drivers/mmc/core/mmc_ops.c` | MMC command operations | index-resolved in scaffold | resolved | `ee7b6bc5a208fa0afcdebb7bd18882e7d0a8326e` | targeted compile PASS | clean reversal PASS |
| 14 | `drivers/mmc/host/sdhci.c` | SDHCI host | index-resolved in scaffold | resolved | `ee7b6bc5a208fa0afcdebb7bd18882e7d0a8326e` | targeted compile PASS | clean reversal PASS |
| 15 | `drivers/net/ethernet/stmicro/stmmac/stmmac_hwtstamp.c` | Ethernet timestamping | index-resolved in scaffold | resolved | `0c2edde500e6c8f9c88e593c94731cdb6fe49cc5` | targeted compile PASS | clean reversal PASS |
| 16 | `drivers/rpmsg/qcom_glink_native.c` | Qualcomm GLINK | index-resolved in scaffold | resolved | `0986f57a7fed5bf69ca14f141666a648a1471350` | targeted compile PASS | clean reversal PASS |
| 17 | `drivers/usb/core/quirks.c` | USB device quirks | index-resolved in scaffold | resolved | `9a2b86edaa5e60488d29808a7fc89750f52213e5` | quirks.o PASS | clean reversal PASS |
| 18 | `drivers/usb/dwc3/core.c` | DWC3 core / power | index-resolved in scaffold | resolved | `dd3d84f1193fb6d902975175b708a9a0ecb6fe97` | core.o PASS | clean reversal PASS |
| 19 | `drivers/usb/gadget/function/f_fs.c` | FunctionFS / ADB | index-resolved in scaffold | resolved | `300e597ea849222a807c47c4dcf8c324025a5ac8` | f_fs.o PASS | clean reversal PASS |
| 20 | `drivers/usb/gadget/function/rndis.c` | USB RNDIS gadget | index-resolved in scaffold | resolved | `73952d0d69d680a113768bf7ca0a64ec6b50312e` | rndis.o PASS | identity + reversal PASS |
| 21 | `drivers/usb/host/xhci.c` | xHCI host lifecycle | index-resolved in scaffold | resolved | `a7fbd76fc6643a2d1d3fdbe778d33c9447376889` | xhci-hcd.o PASS | clean reversal PASS |
| 22 | `drivers/usb/host/xhci.h` | xHCI interfaces | index-resolved in scaffold | resolved | `a7fbd76fc6643a2d1d3fdbe778d33c9447376889` | xhci-hcd.o PASS | clean reversal PASS |
| 23 | `fs/fat/fatent.c` | FAT allocation table | index-resolved in scaffold | resolved | `f0a8bbd0f352fe031a519a32d8b7db7d15ac3853` | targeted compile PASS | clean reversal PASS |
| 24 | `include/net/netfilter/nf_queue.h` | netfilter queue API | index-resolved in scaffold | resolved | `413ff863d871397a6bed7965f3700945daaaab76` | nf_queue.o PASS | clean reversal PASS |
| 25 | `include/net/sock.h` | socket core API | index-resolved in scaffold | resolved | `78cd6e970789a247c91e72c8505d06b384e0e207` | net/core/sock.o PASS | clean reversal PASS |
| 26 | `include/uapi/linux/virtio_ids.h` | Virtio UAPI IDs | index-resolved in scaffold | resolved | `9dccbdfb6ec081b2ab47ab99556cdbed8d8ef13c` | consumer compile PASS | clean reversal PASS |
| 27 | `kernel/exit.c` | task exit / oops handling | index-resolved in scaffold | resolved | `6f9a178101753ca7e5dab46d963609d34ea2cc23` | targeted compile PASS | clean reversal PASS |
| 28 | `kernel/panic.c` | panic/warn accounting | index-resolved in scaffold | resolved | `6f9a178101753ca7e5dab46d963609d34ea2cc23` | targeted compile PASS | clean reversal PASS |
| 29 | `lib/Makefile` | library build composition | index-resolved in scaffold | resolved | `47a4987038f558d655dc83145d5e01ed1fd4f4ac` | lib archive PASS | clean reversal PASS |
| 30 | `mm/memory.c` | page fault / memory core | index-resolved in scaffold | resolved | `e524813ff07ae26098c1fe9ece87504aed28ffb7` | compile deferred by request | clean reversal PASS |
| 31 | `net/ipv4/tcp_output.c` | IPv4 TCP output | index-resolved in scaffold | resolved | `ff5cddfef73c86f16decff679b8cb9f977ce2c13` | compile deferred by request | clean reversal PASS |
| 32 | `net/ipv6/ip6_output.c` | IPv6 output / fragmentation | index-resolved in scaffold | resolved | `db132652ece797c45d368938ca127b6a8e3e366e` | compile deferred by request | clean reversal PASS |
| 33 | `net/netfilter/nf_conntrack_irc.c` | IRC conntrack parsing | index-resolved in scaffold | resolved | `79cda4424b7fb203bfe57404eefd27392d1b5fcc` | nf_conntrack_irc.o PASS | clean reversal PASS |

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

- Full kernel build: **PASS** — run `30701388376`
- External-module build: **PASS** — 32/32 modules
- In-tree module build: **PASS** — 13/13 modules
- Binary ABI/MODVERSIONS CRC errors: **0**
- Physical device testing: **PASS** for the exact boot-tested source
- Boot/runtime testing: **PASS**
- Flashing: **PASS**
- Three-way audit: **PASS** — run `30714292944`
- Clean `lts305-ci1+` release-candidate workflow: **pending**
- Final full physical smoke test: **pending**
- Production merge: **pending**
- Production branch modification during diagnosis and validation: **none**

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
- Validation artifact: run `30240476056`, artifact `8643145751`, digest `sha256:77b97379d5b34a933cc86757edd4efe5806eb507af85f2e97f1c299f5b566787`, size `7883` bytes.

### Qualcomm pixel-clock fraction parity

- Owning semantic commit: `512d47f08402bf130a78e05a92341d62ae04c120` (empty source commit; tree identical to its parent).
- Owned path: `drivers/clk/qcom/clk-rcg2.c`.
- Relevant Android Common commit: `775be2311ae448df6eeb027412e836d75211caed` (upstream `b527358cb4cd58a8279c9062b0786f1fab628fdc`).
- Target behavior: the pixel-clock fraction table contains `(2, 3)` for the SM8350/SM8450 pixel-clock use cases.
- Downstream behavior retained: the Miru table already contains `(2, 3)` exactly once together with `(1, 1)`, `(4, 9)`, `(3, 8)`, and `(2, 9)`; the scaffold blob is `9fc98819321a4f00e0c21aed3fcb66f657ad3fb1`.
- Semantic decision: **no source delta**. The retained Miru implementation already contains the complete target behavior, so no duplicate fraction entry was added.
- Canonical source delta SHA-256: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` (empty `git diff --binary --full-index`).
- Targeted compilation: **PASS** for `drivers/clk/qcom/clk-rcg2.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Clean reversal: **PASS**; reverting the empty semantic commit in a disposable worktree preserved the complete integration tree, while the owned path remained byte-identical to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`.
- Validation workflow run: `30241067412`.
- Validation artifact: run `30241067412`, artifact `8643348682`, digest `sha256:956158e1b997af205636cfe77a71bd01f9f972926984203421396f75a767c31b`, size `7065` bytes.

### FAT allocation-table read-error ratelimit parity

- Owning semantic commit: `f0a8bbd0f352fe031a519a32d8b7db7d15ac3853` (empty source commit; tree identical to its parent).
- Owned path: `fs/fat/fatent.c`.
- Relevant Android Common commit: `4b5541035b59dfe77584e7fb5e283c4e00af5a25`.
- Downstream commit retained: `f3dd33108513be195dfa294de94a6e4345698827`.
- Target behavior: both FAT12 boundary-read failure and normal FAT entry-read failure use `fat_msg_ratelimit()` to prevent repeated I/O errors from flooding the kernel log.
- Downstream behavior retained: the Miru scaffold already ratelimits both paths; its owned-path blob is `a552a9b80d17f2141886bfb80de7010fa58e17e3`.
- Semantic decision: **no source delta**. The earlier Qualcomm implementation already contains the complete Android target behavior; formatting differences do not change semantics.
- Canonical source delta SHA-256: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` (empty `git diff --binary --full-index`).
- Targeted compilation: **PASS** for `fs/fat/fatent.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Clean reversal: **PASS**; reverting the empty semantic commit preserved the complete integration tree, while the owned path remained byte-identical to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`.
- Validation workflow run: `30241553608`.
- Validation artifact: run `30241553608`, artifact `8643522343`, digest `sha256:4f5c2c7743e80e12f2c22fe1bc592b1eec4133427aea7082896bc6fbfee16e97`, size `7001` bytes.

### EDAC polling interval and delayed-work lifetime

- Owning source commit: `e5e15c01d846b479836c7c8625c98794e9094302`.
- Owned path: `drivers/edac/edac_device.c`.
- Relevant Android Common commits: `dd187d7e80c37ebc098e8cf7d370c58febabb8b7` and `49ac46598653f36100ce5594b0e3dbdc6e52bd54`.
- Downstream behavior retained: driver-supplied `poll_msec` support from `623a16f3e9c6f73a688cffd56713deea5f81f035` and deferrable EDAC work from `b5537b9be757d0355cc757261405ba8f3c472540`.
- Android behavior imported: a named 1000-ms default, correct rounding of converted jiffies in `edac_device_reset_delay_period()`, and use of the default only when a driver leaves `poll_msec` at zero.
- Semantic decision: remove the downstream one-second minimum so nonzero driver-supplied intervals are honored, retain conditional `INIT_DEFERRABLE_WORK()`, and round only the default one-second delay using `edac_dev->delay`.
- Audited source patch SHA-256: `af52570dcd8048a12a1576e55179da0a2610165d908b3299f2147967f0f4157b` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/edac/edac_device.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- EDAC source-behavior gates: **PASS**.
- Clean reversal: **PASS**; reverting `e5e15c01d846b479836c7c8625c98794e9094302` restored the owned path exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`.
- Validation workflow run: `30242138170`.
- Validation artifact: run `30242138170`, artifact `8643726041`, digest `sha256:88f9eed2aff39e90a5c0449315d622c004377d2a9f784b4bb921e923d46ec957`, size `8793` bytes.

### Mailbox polling hrtimer serialization

- Owning source commit: `8b9ea460afb7692145090c2d307f6695bed12b3c`.
- Owned path: `drivers/mailbox/mailbox.c`.
- Cleanly merged dependency: `include/linux/mailbox_controller.h` already contains `poll_hrt_lock`; scaffold blob `4868590fa0d52c9307f6afc9607b75720a1c063e` was preserved unchanged.
- Relevant Android Common commit: `e75b5ea2d6b15ba769d7c00261506ba35f13143e` (upstream `bca1a1004615efe141fd78f360ecc48c60bc4ad5`).
- Downstream behavior retained: Miru's split `__msg_submit()` helper and the retry loop for controller `-EAGAIN` responses remain intact.
- Android behavior imported: polling-timer starts and forwards are serialized with `poll_hrt_lock`; the timer is forwarded only when it is not already queued; and rescheduling is requested only when an active transfer remains incomplete.
- Semantic decision: apply the upstream timer-race fix around the downstream retrying submission path rather than replacing that path with the target's single-attempt implementation.
- Audited source patch SHA-256: `d9028ee90f400fe1f9cfe6fe28ef09de6778fb989ccbbaa71eeb56123ba8a2b0` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/mailbox/mailbox.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Mailbox source-behavior and clean-header gates: **PASS**.
- Clean reversal: **PASS**; reverting `8b9ea460afb7692145090c2d307f6695bed12b3c` restored the owned path exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515` while preserving the cleanly merged header blob.
- Validation workflow run: `30243978850`.
- Validation artifact: run `30243978850`, artifact `8644384315`, digest `sha256:92bdd5562de50705ea27d7b4fe550a4c52d6af850e50c43da5602b36728e8829`, size `11031` bytes.

### MMC host validation, eMMC timeouts, and SDHCI voltage switching

- Owning source commit: `ee7b6bc5a208fa0afcdebb7bd18882e7d0a8326e`.
- Owned paths: `drivers/mmc/core/host.c`, `drivers/mmc/core/mmc_ops.c`, and `drivers/mmc/host/sdhci.c`.
- Cleanly merged dependency: `drivers/mmc/host/sdhci.h` already contains the target preset masks plus `drv_type` and `reinit_uhs`; scaffold blob `b3f0fb715b05dd1147fd3f97018c938fc90139f0` was preserved unchanged.
- Relevant Android Common commits: `3fac2cb56ba5205547e296b193e52871f9dc3845` (upstream `d6c9219ca1139b74541b2a98cee47a3426d754a9`), `0aa3b6395fa30613368b0a34aa208c7ea9ad78f5` (upstream `24ed3bd01d6a844fd5e8a75f48d0a3d10ed71bf9`), `327b6689898baa9734ca607939598d78b3cc234b` (upstream `533a6cfe08f96a7b5c65e06d20916d552c11b256`), `99c3d73a7f1225222efe573a0e0b39c8280f4679` (upstream `fa0910107a9fea170b817f31da2a65463e00e80e`), and `f60b9ea221edd04b591916ccabf1733e0d060860` (upstream `c981cdfb9925f64a364f13c2b4f98f877308a408`).
- Android behavior imported: reject an SDIO-IRQ-capable host lacking `enable_sdio_irq`; use 120-second BKOPS and 30-second cache-flush limits; default unspecified CMD6 timeouts to `generic_cmd6_time`; convert SDHCI preset extraction to `FIELD_GET`; and avoid redundant UHS/preset clock changes during voltage switching.
- Downstream behavior retained: MMC clock-scaling and sysfs setup; the five-retry busy-poll diagnostic path; cache-disable handling and HPI recovery after cache-flush timeout; SDHCI controller-clock/power sequencing; spinlock coverage; and SDIO IRQ disable/restore bookkeeping.
- Semantic decision: adapt the upstream SDHCI early-return case to jump through Miru's downstream `ios_done` cleanup tail, ensuring the temporarily disabled SDIO IRQ is restored before returning.
- Audited source patch SHA-256: `3b5b1036f041f1f2d3d429746e378d59ec951e5c88fdb7956ead7cbbe5c15cfa` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/mmc/core/host.o`, `drivers/mmc/core/mmc_ops.o`, and `drivers/mmc/host/sdhci.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- MMC source-behavior and clean-header gates: **PASS**.
- Clean reversal: **PASS**; reverting `ee7b6bc5a208fa0afcdebb7bd18882e7d0a8326e` restored all three owned paths exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`, restored the complete pre-resolution integration tree, and preserved the cleanly merged SDHCI header blob.
- Validation workflow run: `30245581170`.
- Validation artifact: run `30245581170`, artifact `8644971628`, digest `sha256:673d49900eb7e52c7c56d6b8dad1ea8bed92d06bcdb824fbedf8c118fe567ff6`, size `16827` bytes.

### STMMAC sub-second increment saturation

- Owning source commit: `0c2edde500e6c8f9c88e593c94731cdb6fe49cc5`.
- Owned path: `drivers/net/ethernet/stmicro/stmmac/stmmac_hwtstamp.c`.
- Cleanly merged dependency: `drivers/net/ethernet/stmicro/stmmac/stmmac_ptp.h` already renames the SSINC bound to `PTP_SSIR_SSINC_MAX`; scaffold blob `aa222e0cdce86e00a11d699fd66afb70ea747e23` was preserved unchanged.
- Relevant Android Common commit: `7a0674fd083d42cded14e0260052b5ec1c8c0fdb` (upstream `ede5a389852d3640a28e7187fb32b7f204380901`).
- Android behavior imported: saturate an oversized sub-second increment at `PTP_SSIR_SSINC_MAX` instead of masking high bits and potentially producing a zero increment that later becomes a divisor.
- Downstream behavior retained: Miru's 64-bit whole/fractional increment calculation, the `sns_inc` fractional field and mask, GMAC4 field shifts, and timestamp register composition remain intact.
- Semantic decision: apply the target saturation rule to downstream `ss_inc` while leaving the independent fractional `sns_inc` path unchanged.
- Audited source patch SHA-256: `03dd3247bc410120f95dd1eee41e15c5f980f6021425ad26425928e77058671e` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/net/ethernet/stmicro/stmmac/stmmac_hwtstamp.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- STMMAC source-behavior and clean-header gates: **PASS**.
- Clean reversal: **PASS**; reverting `0c2edde500e6c8f9c88e593c94731cdb6fe49cc5` restored the owned path exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`, restored the complete pre-resolution integration tree, and preserved the cleanly merged STMMAC header blob.
- Validation workflow run: `30247407576`.
- Validation artifact: run `30247407576`, artifact `8645678367`, digest `sha256:cdf4d4e7e9afe758f1185b39167ba554dd70788fbd7d539c4b212cadd11e389f`, size `10823` bytes.

### Virtio mac80211-hwsim device ID

- Owning source commit: `9dccbdfb6ec081b2ab47ab99556cdbed8d8ef13c`.
- Owned path: `include/uapi/linux/virtio_ids.h`.
- Cleanly merged consumer: `drivers/net/wireless/mac80211_hwsim.c` already contains the virtio device table using `VIRTIO_ID_MAC80211_HWSIM`; scaffold blob `39642c510d7740d54e4f6fd7287a631c6734d3e6` was preserved unchanged.
- Relevant Android Common commit: `ccba0f9c1296e98b6c3b9933a8514868408d2278` (upstream `f5a37f36fd0fad8451b1a6dddd5cd1b5fac4704e`).
- Android behavior imported: define virtio device ID 29 for mac80211-hwsim so the cleanly merged virtio driver has its matching UAPI identifier.
- Downstream behavior retained: Miru's IDs 30 through 34 for clock, regulator, I2C, SPMI, and FastRPC remain present with their original values.
- Semantic decision: form the union of the Android target's ID 29 and Miru's later downstream IDs instead of replacing the downstream header with the shorter target version.
- Audited source patch SHA-256: `42801b08707a7cedf9f287ed0b2ac9fe4fe0a47aed4375b4e1fa7a311cad6864` using `git diff --binary --full-index`.
- Header validation: **PASS** for a freestanding compile-time UAPI ID probe against the stock tree.
- Consumer compilation: **PASS** for `drivers/net/wireless/mac80211_hwsim.o` using the pinned H.40 toolchain and a compile-only `CONFIG_VIRTIO_MMIO=y` transport overlay, which selects `CONFIG_VIRTIO=y`, derived from the stock configuration. The overlay was not committed. Diagnostics were clean.
- Virtio ID source-behavior and clean-consumer gates: **PASS**.
- Clean reversal: **PASS**; reverting `9dccbdfb6ec081b2ab47ab99556cdbed8d8ef13c` restored the owned header exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`, restored the complete pre-resolution integration tree, and preserved the cleanly merged consumer blob.
- Validation workflow run: `30250061629`.

### Character-device Kconfig RNG trust union

- Owning source commit: `7727a2c3bade0f9d21aaab63a0d58dd13545949b`.
- Owned path: `drivers/char/Kconfig`.
- Relevant Android Common commits: CPU RNG trust configuration `eed01a6b3e563bcc6cbe27ab046dc3cd46febd22` and bootloader-seed trust configuration `7112098b69d5922b7d34c1f6088dad4b0507214e`, both target-reachable from `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- Android behavior imported: `RANDOM_TRUST_CPU` (conditionally on `ARCH_RANDOM`) and `RANDOM_TRUST_BOOTLOADER`, both defaulting to enabled so trusted early entropy can initialize the RNG under the target's documented policy.
- Downstream intent retained: the SMD packet entry; Qualcomm diagnostic, FASTCVPD, ADSPRPC, Virtio FastRPC and remote-debug entries; and the OKL4/Virtual Services serial configuration remains in its original menu scope after the character-device menu.
- Semantic decision: take an explicit textual union. The exact Android Common RNG block is inserted immediately before Miru's character-device `endmenu`; all downstream entries remain byte-for-byte in their scaffold order, including the `endmenu` boundary before `OKL4_PIPE`.
- Scaffold blob: `b92228b9851d68c3d75cf5a8525d86a928978c65`. Target blob: `e329d1cc019ae7e3736d77e83690af17e6db7270`.
- Audited source patch SHA-256: `736378a58e8578c44885d09b5972e8524fe26d8511395a4b8f382263ced18bcb` using `git diff --binary --full-index`.
- Kconfig validation: **PASS** via the pinned H.40 stock configuration and `olddefconfig`; `CONFIG_RANDOM_TRUST_BOOTLOADER=y` was selected by the target default.
- Targeted compilation: **PASS** for `drivers/char/random.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Downstream menu-order and target-block identity gates: **PASS**.
- Clean reversal: **PASS**; reverting `7727a2c3bade0f9d21aaab63a0d58dd13545949b` restored `drivers/char/Kconfig` exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515` and restored the complete pre-resolution integration tree.
- Validation workflow run: `30255039831`.

### Library Makefile crypto and Miru instrumentation union

- Owning source commit: `47a4987038f558d655dc83145d5e01ed1fd4f4ac`.
- Owned path: `lib/Makefile`.
- Relevant Android Common commit: `6adb419f06ffd185cbca84781846fe6054cf3d8e`, target-reachable from `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- Android behavior imported: add the cleanly merged `lib/crypto/` directory to the parent library build so its BLAKE2s implementation is linked into the kernel.
- Downstream intent retained: `KASAN_SANITIZE_find_bit.o := n` and the OPlus VMALLOC-debug stack-depot object under its original preprocessor guard.
- Semantic decision: take an explicit three-way union. Insert only `obj-y += crypto/` after the common `PARMAN` entry; preserve all Miru instrumentation lines byte-for-byte and retain the cleanly merged `lib/crypto/Makefile` blob.
- Scaffold blob: `f5125f285da3e82072c127cfe250abaadf5676e9`. Target blob: `4e3ae6a42dc38c57dc72a4d01d6ea797a14433ab`. Clean crypto Makefile blob: `d0bca68618f034c3b897a7604f11e4da41975395`.
- Audited source patch SHA-256: `8eb9802159761c16d557541f34b3d259b24113e681112cd9a9eedca3b5b13bbb` using `git diff --binary --full-index`.
- Build-graph validation: **PASS** via the pinned H.40 stock configuration and `lib/built-in.o`; the crypto child archive and `libblake2s.o` were produced.
- Consumer compilation: **PASS** for `drivers/char/random.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Downstream instrumentation and crypto-directory identity gates: **PASS**.
- Clean reversal: **PASS**; reverting `47a4987038f558d655dc83145d5e01ed1fd4f4ac` restored `lib/Makefile` exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`, preserved the clean crypto Makefile blob and restored the complete pre-resolution integration tree.
- Validation workflow run: `30257972136`.

### Netfilter queue reference API UAF fix

- Owning source commit: `413ff863d871397a6bed7965f3700945daaaab76`.
- Owned path: `include/net/netfilter/nf_queue.h`.
- Relevant Android Common commit: `ef97921ccdc243170fcef857ba2a17cf697aece5`, target-reachable from `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- Android behavior imported: the queue-reference helper returns `bool` so callers can abandon queueing when the socket refcount cannot be acquired.
- Downstream intent retained: preserve the exact scaffold header layout outside the single declaration change.
- Semantic decision: replace only the stale `void` prototype with Android Common's `bool` prototype. The cleanly merged `net/netfilter/nf_queue.c` already implements the failure path via `refcount_inc_not_zero`; Miru's clean scaffold implementation is preserved byte-for-byte.
- Scaffold header blob: `6a8fe020a400075cdce731057b1ea85bfd88cc56`. Target header blob: `f38cc6092c5a5ac4e609a6c40892e280d5fd4bf6`. Scaffold implementation blob: `da89ded3c9ffd49318f7d1be9a8ef11e3539749a`. Target implementation blob: `46984cdee6581729c42442fb3908936d93312762`.
- Audited source patch SHA-256: `713d9319ebe5399203c3054206954a83c7f1b226564829e6e5032779e4ca163e` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `net/netfilter/nf_queue.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Queue API identity and clean implementation-blob gates: **PASS**.
- Clean reversal: **PASS**; reverting `413ff863d871397a6bed7965f3700945daaaab76` restored `include/net/netfilter/nf_queue.h` exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515`, preserved the clean implementation blob and restored the complete pre-resolution integration tree.
- Validation workflow run: `30258863431`.

### USB device quirk union

- Owning source commit: `9a2b86edaa5e60488d29808a7fc89750f52213e5`.
- Owned path: `drivers/usb/core/quirks.c`.
- Relevant Android Common commits: `a85bffde5c01d0eed902e5cd8f14b8f57876fbbd,6ae382fd0253557a4d8baffc40295a8dc7ea417b,97a1b90db590b509c8c77f94734c324789dc71bf,ff4f627eb1694a27443913879797deac8fb8ff6e,bf9c3fa38cc0e40584f9f85b3dc439ac5cb791d3`, all target-reachable from `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- Provenance verification: each listed device marker was checked as an added line in its own target-reachable commit.
- Android behavior imported: add NO_LPM, RESET_RESUME, and CONFIG_INTF_STRINGS quirks for the Realforce keyboard, NVIDIA Jetson recovery devices, Realtek multicard reader, Dell Gen2 device, and VCOM device.
- Downstream intent retained: Miru's duplicate Kingston DataTraveler entry remains twice and its Galaxy MTP no-LPM entry remains once, in their original scaffold order.
- Semantic decision: take a non-overlapping union of all four Android insertion blocks; preserve all pre-existing Miru quirk-table entries byte-for-byte.
- Scaffold blob: `184c7d2e042244244796dfed3ac6f4c6457ebfdf`. Target blob: `c102c7a9a3b4fe0bce8100671c6c46206ef7d717`.
- Audited source patch SHA-256: `35bd66d9c49e4068d0d9b38ac484383ad990a30ffee5b2246bd5751cb4ba0980` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/usb/core/quirks.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android block identity and downstream quirk-preservation gates: **PASS**.
- Clean reversal: **PASS**; reverting `9a2b86edaa5e60488d29808a7fc89750f52213e5` restored `drivers/usb/core/quirks.c` exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515` and restored the complete pre-resolution integration tree.
- Validation workflow run: `30260382522`.

### FunctionFS EP0 lifetime safety

- Owning source commit: `300e597ea849222a807c47c4dcf8c324025a5ac8`.
- Owned path: `drivers/usb/gadget/function/f_fs.c`.
- Relevant Android Common commits: `facf353c9e8d7885b686d9a4b173d4e0af6441d2,62484437578573a04d23a8ab6db5247a4fd35b92`, both target-reachable from `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- Provenance verification: each listed safety marker was checked as an added line in its own target-reachable commit.
- Android behavior imported: guard the EP0 request before queueing it, dequeue it before freeing it, and serialize the unbind state transition with the FunctionFS mutex.
- Downstream intent retained: Miru's three FunctionFS state diagnostics remain exactly once; the unbind diagnostic stays within the new mutex-protected state transition.
- Semantic decision: apply the Android lifetime-safety sequence without removing Miru diagnostics or changing any unrelated FunctionFS behavior.
- Scaffold blob: `30da2ae088d7796ffc4d2f6a35562be9426344fe`. Target blob: `946cf039edddb7d5cf4b144c61703218a24d6c41`.
- Audited source patch SHA-256: `e4f8e83e16016981768eddd2990ae1c76c1adb72ac623f40c90b44861d52611c` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/usb/gadget/function/f_fs.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android safety-sequence and downstream-diagnostic preservation gates: **PASS**.
- Clean reversal: **PASS**; reverting `300e597ea849222a807c47c4dcf8c324025a5ac8` restored `drivers/usb/gadget/function/f_fs.c` exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515` and restored the complete pre-resolution integration tree.
- Validation workflow run: `30262867644`.

### RNDIS no-source-delta ownership anchor

- Owned path: `drivers/usb/gadget/function/rndis.c`.
- This documentation-only anchor establishes explicit ownership for a target-equivalence validation. No kernel source change is made by this commit.

### RNDIS set-request bounds equivalence

- Owning no-source-delta validation commit: `73952d0d69d680a113768bf7ca0a64ec6b50312e`.
- Owned path: `drivers/usb/gadget/function/rndis.c`.
- Relevant Android Common commit: `c7953cf03a26876d676145ce5d2ae6d8c9630b90`, target-reachable from `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- Merge-base behavior: the original stage lacks the `BufOffset > RNDIS_MAX_TOTAL_SIZE` bounds check.
- Android and retained Miru behavior: both contain exactly one canonical guard rejecting an oversize information-buffer offset before response allocation.
- Downstream intent retained: Miru's RNDIS flow-control, negotiated transfer-size, packet aggregation, and locking extensions remain byte-for-byte at scaffold identity.
- Semantic decision: make no whitespace-only source commit. The retained Miru guard is behaviorally identical to Android Common while preserving downstream coding style and all local RNDIS extensions.
- Source identity: scaffold and resolution-head blobs are both `d1737f27147067ea9044027fbae5cedf8bab6e6c`; the target blob is `b6c707246dadd7f727e1855b32d927df28db40c9`. Source-identity manifest SHA-256: `40ec72085a91989d16f6ef0985504d113724375be0729f4ae69baa286f83584e`.
- Targeted compilation: **PASS** for `drivers/usb/gadget/function/rndis.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Target-guard equivalence and downstream-extension preservation gates: **PASS**.
- Clean reversal: **PASS**; reverting the validation and ownership documentation commits in reverse order restores the complete pre-resolution integration tree, while the owned RNDIS source path remains exactly at scaffold identity.
- Validation workflow run: `30263767530`.

### DWC3 PHY lifecycle and ULPI timeout recovery

- Owning source commit: `dd3d84f1193fb6d902975175b708a9a0ecb6fe97`.
- Owned path: `drivers/usb/dwc3/core.c`.
- Relevant Android Common commits: `7c87f1a44a07becdb2439dc60e5551cedaf89ec4,967d57368d9a49af4f2150c8d9d3c3da865117da`, both target-reachable from `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- Provenance verification: the ULPI deferred-probe sequence and the PHY disable reordering were each checked as an added/removal sequence in their own target-reachable commit.
- Android behavior imported: retry an ULPI timeout through a core soft reset and deferred probe; suspend legacy PHYs and power off Generic PHYs before shutting either down or exiting it.
- Downstream intent retained: Miru dual-port PHY1 ordering, controller-instance bookkeeping, USB3 suspend helper, and controller-notify hook are preserved.
- Semantic decision: apply Android's two safety sequences to the matching Miru core-init and runtime-suspend topology. The existing core-init failure cleanup is asserted unchanged because it already performs generic power-off before Generic PHY exit and legacy suspend before legacy shutdown.
- Scaffold blob: `660868a5371f7f2737ce62ab3e13624477c6dcfb`. Target blob: `5a4bd093c311fd5a8abbbb45d85af3ef46a34ddd`.
- Audited source patch SHA-256: `7504c9cba829aaab86cb942467ab3a42d49cbade0a094389fb5eb5df52a0611a` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/usb/dwc3/core.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android safety-sequence, dual-port preservation, and unchanged error-cleanup gates: **PASS**.
- Clean reversal: **PASS**; reverting `dd3d84f1193fb6d902975175b708a9a0ecb6fe97` restored `drivers/usb/dwc3/core.c` exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515` and restored the complete pre-resolution integration tree.
- Validation workflow run: `30265814173`.

### xHCI lifecycle and LPM safety union

- Owning source commit: `a7fbd76fc6643a2d1d3fdbe778d33c9447376889`.
- Owned paths: `drivers/usb/host/xhci.c` and `drivers/usb/host/xhci.h`.
- Relevant Android Common commits: `f4a5311dfd1cbf9440f006974c1ceec8175f7652,da10a10feaaafdf94c4eec943dde7a7fb798fc6b,0b3787fca33fea855deb1c796f5af572bdc64788,e97d0b01017e3812925287629c8bea8331223d11,db730385457aac4b92fd9144a81281608c452744,0eec6f6001d15bb1108835a642ec4637d75eef19`, all target-reachable from `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- Provenance verification: reset-timeout	f4a5311dfd1cbf9440f006974c1ceec8175f7652;startup-grace	da10a10feaaafdf94c4eec943dde7a7fb798fc6b;shutdown-polling	0b3787fca33fea855deb1c796f5af572bdc64788;resume-reset-failure	e97d0b01017e3812925287629c8bea8331223d11;broken-suspend-warning	db730385457aac4b92fd9144a81281608c452744;usb2-lpm-baseline	0eec6f6001d15bb1108835a642ec4637d75eef19;suspend-timeout-baseline	0eec6f6001d15bb1108835a642ec4637d75eef19;halt-timeout-baseline	0eec6f6001d15bb1108835a642ec4637d75eef19; each target marker was checked in its own target-reachable diff.
- Android behavior imported: use a 10-second reset timeout only where reset completion is critical, retain 250 ms reset limits under shutdown/stop locks, use a 64-bit handshake timeout, add the xHC-start roothub grace period, stop roothub polling at shutdown, use the 512 us USB2 LPM default, and retain the target suspend/resume failure behavior.
- Downstream intent retained: Miru's IRQ flood guard, removal-aware handshake helper, secondary interrupter/event-ring APIs, physical-address helpers, core ID, and stop-endpoint hook remain present and are compiled together.
- Semantic decision: union Android's lifecycle and power-safety sequences with the downstream host-controller extensions. The reset command keeps Miru's removal-aware poll while adopting Android's tunable timeout; the clean companion `xhci-hub.c` grace-period consumer remains untouched at scaffold blob `2b9befbf41160f297ec06952130c2209fe6c4d99`.
- Scaffold blobs: `0bcf825fe895b4a4eac13bd1e45d610876e6bae4` and `4e3554115e1b0aa804d0d36d14b8121d537f5570`. Target blobs: `0f2b67f38d2ea64ada356269e63c28e28f8e0bac` and `7611fc893a0e14498bd033c5b0d77e89405d4f19`.
- Audited source patch SHA-256: `d7c4b1103ad274647d4a130a16b9984707aff9510c8a21d8e21924a2ce3cb176` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `drivers/usb/host/xhci-hcd.o`, including the core and roothub objects, using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android lifecycle, LPM, source-preservation, and clean-companion gates: **PASS**.
- Clean reversal: **PASS**; reverting `a7fbd76fc6643a2d1d3fdbe778d33c9447376889` restored both owned paths exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515` and restored the complete pre-resolution integration tree.
- Validation workflow run: `30273373592`.

### Socket core RCU and TX timestamp API union

- Owning source commit: `78cd6e970789a247c91e72c8505d06b384e0e207`.
- Owned path: `include/net/sock.h`.
- Relevant Android Common commits: `92e6e36ecd16808866ac6172b9491b5097cde449,f9324197f45924e2219b46311b79145e10a15612,add668be8f5e53f4471a075edaa70a7cb85fd036,2c8abafd6c72ef04bc972f40332c76c1dd04446d,0eec6f6001d15bb1108835a642ec4637d75eef19`, all target-reachable from `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- Provenance verification: rx-dst-rcu	92e6e36ecd16808866ac6172b9491b5097cde449;mem-limit-read-once	f9324197f45924e2219b46311b79145e10a15612;tx-timestamp-api	add668be8f5e53f4471a075edaa70a7cb85fd036;skb-frag-order	2c8abafd6c72ef04bc972f40332c76c1dd04446d;tskey-baseline	0eec6f6001d15bb1108835a642ec4637d75eef19; each imported marker was checked in its own target-reachable diff, with the pre-existing `sk_tskey` storage recorded as the Android Common baseline.
- Android behavior imported: annotate the receive-route pointer for RCU, read protocol memory limits with `READ_ONCE()`, add the keyed TX-timestamp helper and skb setup wrapper, and define the 32-bit skb-fragment page order.
- Downstream intent retained: Oplus modem socket fields and aliases, the pacing-shift helper, SOCKEV notifier APIs, and the downstream neighbour-confirm behavior are byte-preserved and compiled with the union.
- Semantic decision: retain every downstream extension while importing the Android concurrency and timestamping API as an exact target-derived helper block.
- Scaffold blob: `2271e669be9e73cbd3b1e6efa80b39c1ff17d70c`. Target blob: `4053eea6182addea78e34d684c72153dab6a4c53`.
- Audited source patch SHA-256: `d5b7e4da8452929f946df41f2687d911fe0ffbdab0f41a677d33f8f4be794ade` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `net/core/sock.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android socket-safety and downstream-preservation gates: **PASS**.
- Clean reversal: **PASS**; reverting `78cd6e970789a247c91e72c8505d06b384e0e207` restored `include/net/sock.h` exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515` and restored the complete pre-resolution integration tree.
- Validation workflow run: `30274749493`.

### IRC DCC parser safety union

- Owning source commit: `79cda4424b7fb203bfe57404eefd27392d1b5fcc`.
- Owned path: `net/netfilter/nf_conntrack_irc.c`.
- Relevant Android Common commits: `dbd64cf46c8a1fd1970e7ab3ac381981e82d26c6,6ce66e3442a5989cbe56a6884384bf0b7d1d0725`, all target-reachable from `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- Provenance verification: dcc-message-framing	dbd64cf46c8a1fd1970e7ab3ac381981e82d26c6;dcc-tuple-port-validation	6ce66e3442a5989cbe56a6884384bf0b7d1d0725; each imported parser and validation marker was checked as an exact added line in its target-reachable diff.
- Android behavior imported: restrict DCC recognition to the IRC message framing, skip leading whitespace, require the accepted `PRIVMSG` form when present, validate the peer tuple, and reject DCC port zero before creating an expectation.
- Downstream intent retained: Miru's IRC client list, nickname and MOTD transitions, client disconnect handling, and NAT mangle policy remain present. The parser passes the already-validated nickname position to the unchanged downstream mangle helper.
- Semantic decision: apply Android's DCC parsing safety checks before downstream expectation and NAT policy; all client-tracking helpers are byte-preserved.
- Scaffold blob: `b637e37bb85f35224f1b3ef452c30fa378d5e64f`. Target blob: `27e2f9785e5f4f2cc6ba1459ab0e425811b96165`.
- Audited source patch SHA-256: `8f7ba66abd60c72b014bf05d5acb12e0f9654e2209555c786850686a403163b9` using `git diff --binary --full-index`.
- Targeted compilation: **PASS** for `net/netfilter/nf_conntrack_irc.o` using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android IRC safety and downstream-preservation gates: **PASS**.
- Clean reversal: **PASS**; reverting `79cda4424b7fb203bfe57404eefd27392d1b5fcc` restored `net/netfilter/nf_conntrack_irc.c` exactly to scaffold `b92a77e96dd54fd30f8f39c7eef23e76f211c515` and restored the complete pre-resolution integration tree.
- Validation workflow run: `30276715839`.


### Memory-core fault, zap and page-table lifetime union

- Owning source commit: `e524813ff07ae26098c1fe9ece87504aed28ffb7`.
- Owned path: `mm/memory.c`.
- Android behavior imported: page-table synchronization for khugepaged/GUP-fast safety; correct swap and migration-entry zapping; exclusive anonymous-page reuse checks with the page unlocked before PTE reuse; recoverable clean hwpoison-page invalidation; and huge-page destination cache flushing.
- Downstream behavior retained: Miru speculative-page-fault VMA snapshots, `pte_map_lock()` validation, page-fault tracepoints, cooperative zap rescheduling and all Qualcomm/OPlus memory extensions outside the target changes.
- Semantic decision: apply the Android safety rules to Miru's newer speculative-fault topology rather than replacing the downstream file with the shorter Android target.
- Source behavior gates: **PASS**.
- Clean reversal: **PASS** to the exact pre-resolution integration tree.
- Audited source patch SHA-256: `95786b1030650a59b6d26f2b643936e60e234cceea1aff9c32de8dcaafba69dd`.
- Compilation: **not performed at maintainer request**.

### TCP output correctness and OPlus network-power union

- Owning source commit: `ff5cddfef73c86f16decff679b8cb9f977ce2c13`.
- Owned path: `net/ipv4/tcp_output.c`.
- Android behavior imported: output-path `tcp_check_space()` notification, corrected cwnd-utilization tracking, race-safe PMTU sysctl reads, retransmission fitting to a shrunken receive window, correct forced-memory accounting, Fast Open MSS-cache synchronization and process-context-safe SYNACK statistics.
- Downstream behavior retained: OPlus modem network-power output and SYN-retransmission hooks, socket PID/UID attribution and downstream pacing-shift behavior.
- Semantic decision: insert each independent Android safety fix around the existing OPlus instrumentation without moving or weakening the instrumentation hooks.
- Clean companion API gates: **PASS** for `tcp_check_space()` and `cwnd_usage_seq`.
- Source behavior gates: **PASS**.
- Clean reversal: **PASS** to the exact pre-resolution integration tree.
- Audited source patch SHA-256: `03e1bd91168d4ce057f67967c7a8ebed9b10e4b79fce73642eafb9031f892430`.
- Compilation: **not performed at maintainer request**.

### IPv6 fragmentation, XFRM MTU and UDP GSO union

- Owning source commit: `db132652ece797c45d368938ca127b6a8e3e366e`.
- Owned path: `net/ipv6/ip6_output.c`.
- Android behavior imported: hold RCU protection across fast-path fragment output and statistics, remove the blanket sub-1280 XFRM rejection, and reject fragment-size underflow/equality cases before calculating payload capacity.
- Downstream behavior retained: Miru UDP GSO cork sizing, paged payload construction, reusable caller-owned cork object and XFRM route-MTU selection.
- Semantic decision: use precise Android underflow guards while preserving Miru's GSO data path; the obsolete blanket MTU rejection is removed for both tunnel and non-tunnel routes.
- Source behavior gates: **PASS**.
- Clean reversal: **PASS** to the exact pre-resolution integration tree.
- Audited source patch SHA-256: `96e49c8f5eb311d484f59e6b1853d16611ccf607d4c31b809ec575df6b670e57`.
- Compilation: **not performed at maintainer request**.


## Final release-candidate CI and physical smoke test

- Clean release-candidate source: `7a720172326aac69dccb3becdb2f75b8a7ee9c29`.
- Actions run `30718744153`: **PASS**. Source-equivalence, authentic-parent-order, conflict-ledger, five compatibility, kernel/DTB, 13 in-tree module, 32 external module, vermagic, MODVERSIONS and ABI gates all passed.
- Full-validation artifact: `8824429036`, `sha256:135f611b0b4a1e244cb2f98c09f2d46ca91335f067821f1115dda79984810ad5`.
- Release-candidate artifact: `8824428231`, `sha256:239f0b95d845ebfb24008b4069f1c473e96c2ee242749bb368c2453913140660`.
- Final `Image.gz-dtb` SHA-256: `ba4d7a598a094f46fb852f5d0e7c9d604eaa4b3a3e0dac506d64ef346f7033ad`.
- Final physical smoke test: **PASS** — on 2026-08-02 the maintainer confirmed complete boot, Wi-Fi, cellular signal/data, maximum-volume audio, NFC, 90 Hz, fingerprint/HBM, AOD, charging, USB/ADB, suspend/wake and reboot on the OnePlus 7 Pro.
- The release branch's runtime kernel paths remain byte-identical to boot-tested source `53f76796d1b68260507a83968a4a4bee3b89754f`. Production `miru-h40` remains at `61371a1024e341f434deaf61b79a05f73827260a` pending separate explicit authorization for the normal merge commit.