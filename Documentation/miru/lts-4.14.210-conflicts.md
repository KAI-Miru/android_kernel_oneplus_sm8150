# Miru H.40 to Android 4.14.210 integration ledger

This ledger tracks the staged integration of Android/Linux stable 4.14.191
through 4.14.210 into the validated Miru H.40 OnePlus 7 Pro kernel.

## Current status

- Integration branch: `miru-h40-lts210-integration`
- Phase 0 reference audit: **complete**
- Phase 1 ledger initialization: **complete**
- Merge scaffold: **created; conflicts deferred**
- Initial merge conflicts: **19**
- Resolved conflicts: **7**
- Remaining conflicts: **12 semantic resolutions**
- Build status: **not started**
- Flash status: **not permitted**

The existing 4.14.190 kernel, matching external modules, DT2W, smart-PA and AOD
fixes are the accepted production baseline. A redundant 4.14.190 rebuild is not
required for this milestone.

## Pinned production inputs

### Miru kernel

- Repository: `KAI-Miru/android_kernel_oneplus_sm8150`
- Production branch: `miru-h40`
- Integration base: `40a2cb6fcf0411c100a7aaa609e128705a0bc2d8`
- Existing 4.14.190 milestone merge: `a48222c3baa9c73943821da6b841d5a533a62fb1`

The integration base includes the validated post-4.14.190 DT2W, smart-PA and AOD
work. The 4.14.210 scaffold must use this commit as its first parent, not the
older 4.14.190 milestone merge.

### Android and Linux stable

- Android stable 4.14.190: `d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac`
- Android stable 4.14.210 merge source: `39a7f9a39c0bd6d0f67869df227f6fa23286edd2`
- Android P 4.14.210 audit reference: `8920709dad5f2852db970d11dffb6bbba4ba6c74`
- Upstream Linux 4.14.210 audit reference: `c196b3a9c83ae3491280b739d231d02b3cb9d041`

`39a7f9a39c0bd6d0f67869df227f6fa23286edd2` is the required second parent of
the future authentic merge scaffold. The upstream Linux commit is an audit
source only and must not replace the Android stable merge source.

### OnePlus vendor and external modules

- Repository: `KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150`
- Validated vendor/module commit: `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`
- Expected external modules: `32`

This vendor commit contains the H.40 smart-PA compatibility fix and includes the
DT2W companion change in its ancestry. It remains pinned unless a later phase
finds a documented source-level incompatibility that cannot be resolved in the
kernel.

### Reproducible toolchain

The existing validated 4.14.190 build environment remains pinned for 4.14.210:

- Clang repository commit: `252aba16f513a857bc923172f67b0e55e23de35f`
- Clang package: `clang-r377782c`
- AArch64 GCC/binutils commit: `606f80986096476912e04e5c2913685a8f2c3b65`
- ARM32 GCC/binutils commit: `b0c6a654327ca8796bed1e61dffcf523d04dceaa`
- Android build-tools commit: `7322db1e1e4715fe217a27f721613e6be8438676`

Toolchain upgrades are outside the scope of the LTS merge and must not be mixed
into the 4.14.210 source integration.

## LineageOS reference audit

### Exact downstream baseline available

- LineageOS/Qualcomm 4.14.190 merge resolution:
  `0190a01fb1cde1c2ba48e7836084bad818c14d94`
- LineageOS `lineage-18.1` head:
  `bd9fe823ffe6be682ba997b9cb593abb3b50252b`
- `lineage-18.1` kernel sublevel: `190`

### No exact OnePlus LineageOS 4.14.210 device branch was found

The accessible historical OnePlus LineageOS branches do not provide a branch
tip at 4.14.210:

- `lineage-18.1` remains at 4.14.190.
- `lineage-19.1` and `lineage-20` report 4.14.180.
- maintained branches later jump to substantially newer LTS/OpenELA revisions.

A dedicated LineageOS OnePlus/SM8150 4.14.210 downstream merge commit therefore
must not be invented or implied.

### Secondary modern LineageOS semantic reference

- LineageOS `lineage-21` head:
  `123e95de0025ef73ccddf5c0ad6b180fbb2a7afb`
- Recorded sublevel at that head: `355-openela`

This modern reference may be consulted only file-by-file for surviving Qualcomm
or OnePlus integration patterns. Later LTS/OpenELA changes must not be imported
into the 4.14.210 milestone merely because they are present in this tree.

### Resolution policy resulting from the audit

For every conflict or clean semantic collision:

1. Android stable 4.14.210 defines the intended 4.14.191-210 fix.
2. The LineageOS/Qualcomm 4.14.190 resolution defines the known-good downstream
   SM8150 structure and conflict style.
3. Current Miru H.40 defines the OnePlus/OPlus behavior that must survive.
4. Modern LineageOS is a secondary check only when it still carries the same
   relevant Qualcomm design.
5. The final resolution should normally be the current Miru implementation plus
   the minimal Android stable semantic fix, adapted using downstream Qualcomm
   patterns where necessary.

## Pre-merge scope audit

### Android stable delta

The Android stable comparison from 4.14.190 to 4.14.210 contains 1,533 commits.
GitHub's compare API exposes only a capped changed-file window, so the complete
path manifest and exact conflict count must be generated from the real merge
scaffold in Phase 2. The pre-audit already confirms changes in these important
areas:

- `Makefile`, Kconfig and Android build configuration
- arm64 page-table, CPU-feature, exception, linker and KVM code
- Binder and Android memory-management paths
- block core and device mapper
- fscrypt, F2FS and IncFS-adjacent interfaces
- MMC/SDHCI and UFS-adjacent code
- USB core and gadget code
- networking and sysctl code
- ALSA and USB-audio code
- common driver-core, clock, power and suspend paths

No file from the capped API result is treated as the authoritative conflict
list. Only the actual two-parent scaffold merge may establish that list.

### Miru changes after the 4.14.190 milestone

The current production head is six commits ahead of the 4.14.190 milestone.
The directly changed kernel-repository paths are:

```text
Documentation/miru-lts-integration.md
Documentation/miru/lts-4.14.190-conflicts.md
README.md
drivers/gpu/drm/msm/dsi-staging/dsi_panel.c
scripts/miru/ci_build_4.14.190.sh
scripts/miru/inject_vendor_compat_v3_into_ci_build.py
```

The `dsi_panel.c` AOD luminance fix is runtime-critical. The CI changes also pin
and inject the currently validated vendor compatibility logic. These changes
must remain present after the 4.14.210 merge even if Git reports no direct
conflict.

### Runtime-critical preservation checklist

The following behavior is explicitly protected throughout the integration:

- [ ] Current DT2W kernel/vendor companion implementation remains present.
- [ ] H.40 smart-PA compatibility remains present.
- [ ] Maximum-volume audio remains free of garbling.
- [ ] H.40 AOD luminance programming remains authoritative.
- [ ] Ordinary backlight writes remain blocked in AOD and AOD-HBM scenes.
- [ ] Fingerprint HBM and panel brightness behavior remain intact.
- [ ] Qualcomm WLAN and audio external-module interfaces remain compatible.
- [ ] F2FS, fscrypt, IncFS, UFS, MMC and inline-encryption behavior remain intact.
- [ ] QRTR, modem IPC and networking vendor extensions remain intact.
- [ ] Charging, thermal, suspend/resume, camera and sensor paths remain intact.

## Phase 2 merge scaffold record

- Scaffold first parent: `33168a42f34f630ebeb87d90c250a53cac262b39`
- Miru production integration base: `40a2cb6fcf0411c100a7aaa609e128705a0bc2d8`
- Scaffold second parent: `39a7f9a39c0bd6d0f67869df227f6fa23286edd2`
- Initial semantic conflict count: `19`
- Index-level unmerged entries after deferral: `0`
- Conflict policy: retain every clean three-way merge result; temporarily retain the Miru side only for the paths listed below.
- Build/flash status: prohibited until all listed paths receive explicit subsystem-level resolution.

### Exact deferred-conflict manifest

```text
arch/arm/configs/ranchu_defconfig
arch/arm64/configs/ranchu64_defconfig
arch/x86/configs/i386_ranchu_defconfig
arch/x86/configs/x86_64_ranchu_defconfig
drivers/clk/clk.c
drivers/gpu/drm/msm/msm_drv.c
drivers/hwtracing/coresight/coresight-tmc-etf.c
drivers/mailbox/mailbox.c
drivers/mmc/core/queue.c
drivers/mmc/host/sdhci-msm.c
drivers/scsi/ufs/ufs-qcom.c
drivers/scsi/ufs/ufshcd.c
drivers/usb/dwc3/core.c
drivers/usb/dwc3/gadget.c
fs/incfs/format.c
fs/incfs/main.c
fs/incfs/vfs.c
mm/memory.c
net/ipv4/inet_connection_sock.c
```

The paths above are staged only to make the merge commit representable. They are not considered semantically resolved. Each remains counted in `Remaining conflicts` until its owning subsystem commit records and validates the final resolution.

## Phase 3: non-target architecture and documentation

- Owning commit: `lts: resolve non-target architecture and documentation conflicts`
- Conflicts resolved in this batch: `4`
- Conflicts remaining after this batch: `15`
- Documentation conflicts: `0`; all clean Android 4.14.191-210 documentation merges remain retained.
- Resolution rule: accept Android stable deletion of obsolete Ranchu/Goldfish emulator defconfigs because none participates in the SM8150/guacamole build, external-module ABI, DTB/DTBO generation or OnePlus runtime behavior.
- Validation performed: exact changed-path gate; all four files absent; `Makefile` remains at 4.14.210; no production branch change.
- Build/flash status: not started and still prohibited while semantic conflicts remain.

### `arch/arm/configs/ranchu_defconfig`

- Subsystem batch: non-target architecture and documentation
- Android 4.14.191-210 change: remove obsolete Ranchu emulator defconfig from the generic Android kernel tree.
- Relevant Android commit: `cc34fcefe97688d21f83e3d544e155f55a847bed` (`ANDROID: Delete goldfish build configs and defconfigs`)
- LineageOS/Qualcomm reference: not required; this file is an emulator-only configuration and is not selected by the OnePlus SM8150 build.
- Miru/H.40 behavior retained: all guacamole and Qualcomm target configurations remain untouched.
- Final resolution: delete the file, matching Android stable 4.14.210.
- External-module ABI impact: none.
- Runtime risk: none for OnePlus 7 Pro; the file cannot affect a guacamole kernel image.
- Required validation: verify absence and verify no target defconfig, source, DT or module path changed in this commit.
- Resolution commit: this commit.
- Status: resolved

### `arch/arm64/configs/ranchu64_defconfig`

- Subsystem batch: non-target architecture and documentation
- Android 4.14.191-210 change: remove obsolete Ranchu emulator defconfig from the generic Android kernel tree.
- Relevant Android commit: `cc34fcefe97688d21f83e3d544e155f55a847bed` (`ANDROID: Delete goldfish build configs and defconfigs`)
- LineageOS/Qualcomm reference: not required; this file is an emulator-only configuration and is not selected by the OnePlus SM8150 build.
- Miru/H.40 behavior retained: all guacamole and Qualcomm target configurations remain untouched.
- Final resolution: delete the file, matching Android stable 4.14.210.
- External-module ABI impact: none.
- Runtime risk: none for OnePlus 7 Pro; the file cannot affect a guacamole kernel image.
- Required validation: verify absence and verify no target defconfig, source, DT or module path changed in this commit.
- Resolution commit: this commit.
- Status: resolved

### `arch/x86/configs/i386_ranchu_defconfig`

- Subsystem batch: non-target architecture and documentation
- Android 4.14.191-210 change: remove obsolete Ranchu emulator defconfig from the generic Android kernel tree.
- Relevant Android commit: `cc34fcefe97688d21f83e3d544e155f55a847bed` (`ANDROID: Delete goldfish build configs and defconfigs`)
- LineageOS/Qualcomm reference: not required; this file is an emulator-only configuration and is not selected by the OnePlus SM8150 build.
- Miru/H.40 behavior retained: all guacamole and Qualcomm target configurations remain untouched.
- Final resolution: delete the file, matching Android stable 4.14.210.
- External-module ABI impact: none.
- Runtime risk: none for OnePlus 7 Pro; the file cannot affect a guacamole kernel image.
- Required validation: verify absence and verify no target defconfig, source, DT or module path changed in this commit.
- Resolution commit: this commit.
- Status: resolved

### `arch/x86/configs/x86_64_ranchu_defconfig`

- Subsystem batch: non-target architecture and documentation
- Android 4.14.191-210 change: remove obsolete Ranchu emulator defconfig from the generic Android kernel tree.
- Relevant Android commit: `cc34fcefe97688d21f83e3d544e155f55a847bed` (`ANDROID: Delete goldfish build configs and defconfigs`)
- LineageOS/Qualcomm reference: not required; this file is an emulator-only configuration and is not selected by the OnePlus SM8150 build.
- Miru/H.40 behavior retained: all guacamole and Qualcomm target configurations remain untouched.
- Final resolution: delete the file, matching Android stable 4.14.210.
- External-module ABI impact: none.
- Runtime risk: none for OnePlus 7 Pro; the file cannot affect a guacamole kernel image.
- Required validation: verify absence and verify no target defconfig, source, DT or module path changed in this commit.
- Resolution commit: this commit.
- Status: resolved

## Phase 4: build and module ABI

- Owning commit: `lts: resolve build and module ABI conflicts`
- Conflicts resolved in this batch: `3`
- Conflicts remaining after this batch: `12`
- Direct Makefile, Kconfig, modpost, symversion, exported-header and device-table conflicts: `0`; their clean Android 4.14.191-210 merges remain retained.
- ABI policy: preserve all H.40 exported interfaces and Qualcomm/OPlus extensions; import only fixes that change internal implementation without changing exported function signatures or structure layouts.
- Validation status: **PASS** — pinned Clang/GCC/AOSP tools and vendor tree; stock H.40 config completed `olddefconfig` and `modules_prepare`; `CONFIG_MODULES=y`, `CONFIG_MODVERSIONS=y`, generated `autoconf.h`/`utsrelease.h`, and `modpost` were verified.
- Full kernel and external-module compilation: deferred until all semantic conflicts are resolved.

### `drivers/clk/clk.c`

- Android change: evict an unregistered clock from every cached parent array to prevent dangling `clk_core` pointers.
- Relevant Android commit: `f114a36246812b5c06b0a6066412215e45b3ac8c` (`clk: Evict unregistered clks from parent caches`).
- Miru/H.40 behavior retained: Qualcomm voltage voting, bus-vote callbacks, clock debugfs extensions, OPlus standby diagnostics and all existing exported clock APIs.
- Final resolution: make the root/orphan list arrays available outside `CONFIG_DEBUG_FS`, add the stable recursive cache eviction helpers, and call eviction before unlinking the unregistered clock.
- External-module ABI impact: none; no exported symbol, prototype, device ID or structure layout changes.
- Runtime risk/validation: shared clock framework; require stock-config `olddefconfig` and `modules_prepare`, followed later by full build and device clock/display/storage validation.
- Resolution commit: this commit.
- Status: resolved

### `drivers/hwtracing/coresight/coresight-tmc-etf.c`

- Android change: read `TMC_MODE` only while the active SYSFS trace path guarantees the CoreSight hardware is powered.
- Relevant Android commit: `93934e5d463b31e9d118c4b52aa8d1266c7f503e` (`coresight: tmc: Fix TMC mode read in tmc_read_unprepare_etb()`).
- Miru/H.40 behavior retained: ETB/ETF buffer ownership, enable state, PERF exclusion and Qualcomm CoreSight integration.
- Final resolution: move the circular-buffer mode check inside the `CS_MODE_SYSFS` re-enable block, matching the stable and later Qualcomm/LineageOS implementation.
- External-module ABI impact: none.
- Runtime risk/validation: prevents a powered-down register read and asynchronous SError; validate through `modules_prepare` now and boot/debug tracing later.
- Resolution commit: this commit.
- Status: resolved

### `drivers/mailbox/mailbox.c`

- Android change: prevent polling hrtimer re-enqueue from its own callback and keep polling while any request remains active.
- Relevant Android commit: `e1d8263a59494079666d2ed7be058f54a127a693` (`mailbox: avoid timer start from callback`).
- Miru/H.40 behavior retained: the Qualcomm/H.40 `-EAGAIN` submission retry loop and all mailbox client/controller interfaces.
- Final resolution: start the polling timer only when inactive and set `resched` before checking completion for every active request.
- External-module ABI impact: none; internal timer behavior only.
- Runtime risk/validation: shared IPC infrastructure; require `modules_prepare`, then later QRTR/modem/audio/WLAN runtime testing.
- Resolution commit: this commit.
- Status: resolved

## Planned conflict-resolution batches

Conflicts and semantic collisions will be assigned to exactly one primary batch:

1. Non-target architecture and documentation
2. Build and module ABI
3. arm64 core
4. Memory management and Binder
5. Block, fscrypt, F2FS and IncFS
6. MMC, SDHCI and UFS
7. USB core and gadget
8. Networking and QRTR
9. ALSA and audio core
10. OnePlus runtime-critical reconciliation

A file may be cross-referenced by another batch, but its final source resolution
must have one owning commit and one ledger entry.

## Per-path resolution record

Each actual conflict will use this format:

```text
Path:
Subsystem batch:
Android 4.14.191-210 change:
Relevant Android/upstream commit:
LineageOS/Qualcomm reference:
Miru/H.40 behavior retained:
Final resolution:
External-module ABI impact:
Runtime risk:
Required validation:
Resolution commit:
Status: pending | resolved
```

## Merge-scaffold requirements for Phase 2

The next phase must create one authentic two-parent merge commit with:

- first parent: `33168a42f34f630ebeb87d90c250a53cac262b39` (the Phase 1 ledger commit; integration base `40a2cb6fcf0411c100a7aaa609e128705a0bc2d8` remains its parent)
- second parent: `39a7f9a39c0bd6d0f67869df227f6fa23286edd2`

During scaffold creation:

- all clean three-way merge results are retained;
- every real conflict temporarily keeps the Miru side;
- the exact unresolved path list is copied into this ledger;
- the measured initial, resolved and remaining conflict counts are recorded;
- the scaffold is marked incomplete and must not be built or flashed.

## Phase 0 and Phase 1 completion record

- [x] Current production Miru head pinned.
- [x] Android stable 4.14.190 and 4.14.210 commits pinned.
- [x] Upstream Linux 4.14.210 audit commit pinned.
- [x] Vendor/module source pinned.
- [x] Reproducible toolchain commits pinned.
- [x] LineageOS historical and modern reference limitations documented.
- [x] Post-4.14.190 Miru source changes identified.
- [x] Runtime-critical preservation checklist created.
- [x] Conflict-record template created.
- [x] Integration branch created from the validated production head.
- [x] Authentic 4.14.210 merge scaffold created.
- [x] Exact conflict list measured.
