# Miru H.40 to Android Common 4.14.241 integration ledger

This ledger tracks the staged integration of Android Common Linux 4.14.211
through 4.14.241 into the Miru H.40 OnePlus 7 Pro kernel. It is the audit
record for both authentic Git conflicts and cleanly merged changes that require
downstream semantic review.

## Current status

- Integration branch: `miru-h40-lts241-integration`
- Production branch: `miru-h40`
- Production baseline: `cc49ffcb5c5207746618a799b250c67decdc0d15`
- Production baseline version: `4.14.210`
- Merge date: `2026-07-21`
- Reconnaissance: **complete**
- Target verification: **complete**
- Initial authentic conflicts: **32**
- Index-resolved conflicts: **0**
- Semantically resolved conflicts: **0**
- Remaining semantic conflicts: **32**
- Merge scaffold: **not yet created**
- Targeted compilation: **not started**
- Full kernel build: **not started and prohibited while semantic conflicts remain**
- External-module build: **not started**
- Device-test status: **not performed; physical testing is reserved for the device owner**
- Flash status: **not performed and not permitted in this integration task**

## Immutable production baseline

The live `miru-h40` ref was read directly from GitHub before this branch was
created and resolved to:

```text
cc49ffcb5c5207746618a799b250c67decdc0d15
```

The top-level `Makefile` at that commit reports Linux `4.14.210`. Its recent
first-parent history contains the successful 4.14.210 production merge
`f78e220d9b5b49fb309b25877f6f423e5eb4f55e`, followed only by production
validation documentation. The authentic Android Common 4.14.210 parent
`39a7f9a39c0bd6d0f67869df227f6fa23286edd2` is an ancestor of the production
baseline.

The production branch must remain unchanged. This integration branch was
created directly from the immutable baseline above.

## Authoritative Android Common target

- Repository: `https://android.googlesource.com/kernel/common`
- Tag: `ASB-2021-08-05_4.14-stable`
- Annotated tag object: `aa8d24a5e5fff6645eb1ef44072e1e8848a63b61`
- Peeled target commit: `a446f52a5d3fc71698a073d08ce1eeb923727b42`
- Target version: `4.14.241`
- Tag tree: `b168f247c9259750772b3e1ed901c08f412a5aa3`

Verification performed in GitHub Actions run `29798735690`:

1. fetched the exact annotated tag ref from Android Common;
2. verified `refs/tags/ASB-2021-08-05_4.14-stable` resolves to the supplied tag-object SHA;
3. verified peeling the tag resolves to the supplied target commit SHA;
4. verified the object types are `tag` and `commit` respectively;
5. re-hashed the canonical tag and commit object payloads with Git and matched both supplied SHA-1 object IDs;
6. verified the target `Makefile` reports `4.14.241`;
7. verified the target commit is not already an ancestor of production.

The annotated tag contains no embedded GPG signature, so no GPG-signature claim
is made. Cryptographic object identity is established by canonical Git object
re-hashing and exact ref peeling.

Reconnaissance artifact:

- Name: `miru-lts241-recon-29798735690`
- Artifact ID: `8483010337`
- Artifact SHA-256: `cde1b97d63783685fc356b5fb60032aa12c0fcabd044294aea3b30d01a72f043`

## Pinned build environment

The current repository workflow and documentation retain the deliberately
approved 4.14.210 build environment. It remains pinned for this integration:

- Vendor/modules repository: `KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150`
- Vendor/modules commit: `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`
- Expected external modules: exactly `32` `.ko` files
- Clang repository commit: `252aba16f513a857bc923172f67b0e55e23de35f`
- Clang package: `clang-r377782c`
- AArch64 GCC/binutils commit: `606f80986096476912e04e5c2913685a8f2c3b65`
- ARM32 GCC/binutils commit: `b0c6a654327ca8796bed1e61dffcf523d04dceaa`
- AOSP build-tools commit: `7322db1e1e4715fe217a27f721613e6be8438676`
- Production stock config: `h40-repro/config/GM1911_11_H.40.config`
- Official fallback defconfig entry point: `vendor/sm8150-perf_defconfig`
- Production build driver: `h40-repro/build-h40.sh`
- Existing CI wrapper: `scripts/miru/ci_build_4.14.190.sh`, adapted by the permanent workflow for the current milestone
- External-module build driver: `scripts/miru/build_external_modules_4.14.190.sh`, adapted by the workflow for the current milestone

No toolchain or vendor-source upgrade is part of this LTS integration.

## Repository reconnaissance summary

- Default branch: `miru-h40`
- Live production head: `cc49ffcb5c5207746618a799b250c67decdc0d15`
- Production kernel version: `4.14.210`
- Permanent workflow: `.github/workflows/miru-h40-build.yml`
- Existing ledgers: 4.14.190 and 4.14.210
- Existing validation record: `Documentation/miru/lts-4.14.210-validation.md`
- Stale 4.14.210 integration/helper branches: none found
- Permanent non-production source branch: `oneplus/sm8150_s_12.1_op7pro`
- Android Common 4.14.210 ancestry in production: present
- Android Common 4.14.241 target in production ancestry: absent
- Commits in the verified 4.14.210..4.14.241 lineage: `2438`
- Patch-equivalent target-lineage commits already present in production: `4`

The four patch-equivalent commits identified by `git cherry` are:

```text
0b456c623afe5445e0edf6ffe44930cec6709ddf
84f747ade2fbbe5ab5cc8ff6a0cbad434cb2c553
d5e62e55287d98fa99e51ae4058d1232655fa9fe
dee735834d1ea8cd49f2537022145abdb5551a81
```

These are not treated as proof that any larger 4.14.211-4.14.241 subsystem is
already integrated. Every remaining target change still enters through the
authentic merge.

## Authentic merge procedure

The scaffold transaction will use the following procedure on the exact ledger
commit created from production:

```text
git fetch --force --no-tags https://android.googlesource.com/kernel/common \
  refs/tags/ASB-2021-08-05_4.14-stable:refs/tags/ASB-2021-08-05_4.14-stable
git checkout miru-h40-lts241-integration
git merge --no-commit --no-ff a446f52a5d3fc71698a073d08ce1eeb923727b42
```

The original conflict list and all stage-1/base, stage-2/Miru and
stage-3/Android-Common blobs will be preserved as a workflow artifact. Cleanly
merged paths will remain exactly as produced by Git. For scaffold creation only,
each authentic conflict path will be staged from the existing Miru side so that
a representable two-parent merge commit can be created. Every such path will
remain counted as **index-resolved but semantically unresolved** until a focused
subsystem commit imports or deliberately rejects the relevant upstream behavior.

Required scaffold parents:

- Parent 1: this ledger/preparation commit
- Parent 2: `a446f52a5d3fc71698a073d08ce1eeb923727b42`

## Authentic conflict manifest

The authoritative no-commit merge preview produced exactly `32` conflicts.
The list below is complete and is not inferred from a compare API.

| # | Path | Semantic subsystem | Index status | Semantic status | Owning resolution commit | Validation |
|---:|---|---|---|---|---|---|
| 1 | `arch/x86/Makefile` | non-target x86 build system | pending scaffold | unresolved | pending | pending |
| 2 | `drivers/block/zram/zram_drv.c` | block / compressed memory | pending scaffold | unresolved | pending | pending |
| 3 | `drivers/dma-buf/dma-buf.c` | dma-buf core | pending scaffold | unresolved | pending | pending |
| 4 | `drivers/gpu/drm/msm/msm_drv.c` | MSM DRM / display shutdown | pending scaffold | unresolved | pending | pending |
| 5 | `drivers/mmc/core/core.c` | MMC core | pending scaffold | unresolved | pending | pending |
| 6 | `drivers/mmc/core/mmc.c` | MMC device initialization | pending scaffold | unresolved | pending | pending |
| 7 | `drivers/scsi/ufs/ufshcd.c` | UFS core / power management | pending scaffold | unresolved | pending | pending |
| 8 | `drivers/soc/qcom/smp2p.c` | Qualcomm SMP2P IPC | pending scaffold | unresolved | pending | pending |
| 9 | `drivers/tty/tty_jobctrl.c` | TTY job control | pending scaffold | unresolved | pending | pending |
| 10 | `drivers/usb/core/hub.c` | USB hub / enumeration | pending scaffold | unresolved | pending | pending |
| 11 | `drivers/usb/dwc3/core.c` | DWC3 core / power and role handling | pending scaffold | unresolved | pending | pending |
| 12 | `drivers/usb/dwc3/gadget.c` | DWC3 gadget | pending scaffold | unresolved | pending | pending |
| 13 | `drivers/usb/gadget/configfs.c` | USB gadget configfs / Android composition | pending scaffold | unresolved | pending | pending |
| 14 | `drivers/usb/gadget/function/f_accessory.c` | Android USB accessory function | pending scaffold | unresolved | pending | pending |
| 15 | `drivers/usb/gadget/function/f_fs.c` | FunctionFS / ADB | pending scaffold | unresolved | pending | pending |
| 16 | `drivers/usb/gadget/function/f_uac1.c` | USB audio gadget UAC1 | pending scaffold | unresolved | pending | pending |
| 17 | `drivers/usb/gadget/function/f_uac2.c` | USB audio gadget UAC2 | pending scaffold | unresolved | pending | pending |
| 18 | `fs/incfs/data_mgmt.c` | Incremental FS data management | pending scaffold | unresolved | pending | pending |
| 19 | `fs/incfs/format.c` | Incremental FS on-disk format | pending scaffold | unresolved | pending | pending |
| 20 | `fs/incfs/main.c` | Incremental FS module lifecycle | pending scaffold | unresolved | pending | pending |
| 21 | `fs/incfs/pseudo_files.c` | Incremental FS pseudo files; modify/delete conflict | pending scaffold | unresolved | pending | pending |
| 22 | `fs/incfs/vfs.c` | Incremental FS VFS and mount behavior | pending scaffold | unresolved | pending | pending |
| 23 | `include/linux/usb/usbnet.h` | USB networking private interface | pending scaffold | unresolved | pending | pending |
| 24 | `kernel/bpf/helpers.c` | BPF helper ABI | pending scaffold | unresolved | pending | pending |
| 25 | `kernel/cgroup/cgroup.c` | cgroup core | pending scaffold | unresolved | pending | pending |
| 26 | `kernel/cpu.c` | CPU hotplug / core lifecycle | pending scaffold | unresolved | pending | pending |
| 27 | `kernel/futex.c` | futex core | pending scaffold | unresolved | pending | pending |
| 28 | `kernel/sched/fair.c` | CFS scheduler | pending scaffold | unresolved | pending | pending |
| 29 | `net/core/skbuff.c` | networking skb core | pending scaffold | unresolved | pending | pending |
| 30 | `net/qrtr/qrtr.c` | Qualcomm QRTR IPC | pending scaffold | unresolved | pending | pending |
| 31 | `net/sctp/sm_make_chunk.c` | SCTP networking | pending scaffold | unresolved | pending | pending |
| 32 | `security/selinux/avc.c` | SELinux AVC | pending scaffold | unresolved | pending | pending |

## Conflict-state definitions

### Index-level conflict resolution

An index-level resolution means Git no longer reports an unmerged stage for a
path. It does **not** establish semantic correctness. The scaffold will perform
index-level resolution only so the authentic two-parent merge commit can exist.

### Semantic conflict resolution

A path becomes semantically resolved only after a focused commit documents the
upstream stable intent, compares base/Miru/target implementations, applies the
correct combined behavior, checks callers and interfaces, performs targeted
compilation where applicable, and passes clean-reversal validation back to the
scaffold state.

### Non-conflicting upstream changes

All cleanly merged 4.14.211-4.14.241 changes remain in the scaffold. They are not
listed as authentic conflicts, but high-risk clean merges in DT2W, AOD/display,
audio/smart-PA, USB, UFS, MMC, QRTR, Binder, networking, power/thermal,
filesystems, module exports and MODVERSIONS interfaces must receive a separate
semantic audit before the full build.

### Downstream behavior intentionally retained

Downstream behavior may be retained when it implements required Qualcomm,
OnePlus, OPlus, ColorOS or Miru semantics absent from generic Android Common.
Retention must be explicit and justified; whole-file `ours` resolution is not an
acceptable final semantic decision.

### Upstream behavior intentionally imported

Upstream behavior is imported when it fixes a bug or security issue without
breaking required downstream semantics. The final source may need a manual
adaptation rather than a textual selection of either side.

### No-source-change resolutions

A conflict may ultimately require no source delta from the scaffold when audit
shows the current Miru implementation already contains the upstream semantic fix
or the upstream code is inapplicable to the target configuration. Such cases
still require a focused owning commit, normally a ledger-only commit, and the
same reversal and validation record.

## Protected downstream behavior and ABI checklist

The following areas require explicit review even without textual conflicts:

- [ ] DT2W kernel and vendor companion functionality
- [ ] AOD luminance programming and AOD-HBM backlight filtering
- [ ] Fingerprint HBM and panel brightness behavior
- [ ] H.40 smart-PA compatibility and maximum-volume audio behavior
- [ ] MSM/SDE last-close and shutdown behavior
- [ ] Qualcomm reserved networking-port policy
- [ ] USB gadget, ADB, accessory, charging and role-switch behavior
- [ ] UFS initialization, power management and shutdown behavior
- [ ] MMC initialization and suspend/resume behavior
- [ ] Qualcomm SMP2P, QRTR and modem IPC behavior
- [ ] Binder compatibility with the ColorOS 14 port
- [ ] OPlus touchscreen and display interfaces
- [ ] `CONFIG_MODVERSIONS=y`
- [ ] kernel symbol exports and CRC stability
- [ ] external vendor headers and private interfaces
- [ ] all explicit Miru fixes after the 4.14.210 integration base

## Resolution batches

Only groups containing authentic conflicts will receive conflict-resolution
commits. Initial planned batches, subject to semantic analysis, are:

1. non-target x86 build conflict;
2. zram and dma-buf core conflicts;
3. MSM DRM display conflict;
4. MMC and UFS storage conflicts;
5. Qualcomm SMP2P and QRTR IPC conflicts;
6. TTY job-control conflict;
7. USB core, DWC3, gadget, FunctionFS, accessory, UAC and usbnet conflicts;
8. Incremental FS conflicts;
9. BPF, cgroup, CPU hotplug, futex and scheduler conflicts;
10. networking skb and SCTP conflicts;
11. SELinux AVC conflict.

These groups may be split further when the upstream commit history shows that a
smaller owning change is required. Unrelated subsystems will not be combined to
reduce commit count.

## Validation ledger

| Batch | Semantic paths | Index resolved | Semantic resolved | Targeted compilation | Clean reversal | Owning commit |
|---|---:|---|---|---|---|---|
| merge scaffold | 32 | pending | no | prohibited | not applicable | pending |
| non-target x86 build | 1 | pending | pending | pending | pending | pending |
| zram and dma-buf | 2 | pending | pending | pending | pending | pending |
| MSM DRM display | 1 | pending | pending | pending | pending | pending |
| MMC and UFS storage | 3 | pending | pending | pending | pending | pending |
| Qualcomm IPC | 2 | pending | pending | pending | pending | pending |
| TTY job control | 1 | pending | pending | pending | pending | pending |
| USB core and gadget | 8 | pending | pending | pending | pending | pending |
| Incremental FS | 5 | pending | pending | pending | pending | pending |
| kernel core and scheduler | 5 | pending | pending | pending | pending | pending |
| networking | 2 | pending | pending | pending | pending | pending |
| SELinux AVC | 1 | pending | pending | pending | pending | pending |

## Build and test policy

The final kernel and external-module build must not start until all 32 authentic
conflicts are semantically resolved, every owning commit passes clean-reversal
validation, targeted compilation passes, high-risk clean merges are audited, and
the remaining semantic conflict count reaches zero.

Physical device validation and flashing have not been performed and will not be
performed by automation. Production promotion is explicitly out of scope until
the device owner tests the generated build and authorizes a later merge.

### lts: resolve x86 build conflict for 4.14.241

- Batch ID: `x86`
- Paths: `arch/x86/Makefile`
- Decision: Retain Android CET disabling and Miru non-PIC policy; x86 is not a target architecture.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.

### lts: resolve zram and dma-buf conflicts for 4.14.241

- Batch ID: `corebuf`
- Paths: `drivers/block/zram/zram_drv.c drivers/dma-buf/dma-buf.c`
- Decision: Use atomic compacted-page accounting and move dma-buf destruction to dentry release while retaining dedup, names and ref tracking.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.

### lts: resolve MSM display conflict for 4.14.241

- Batch ID: `drm`
- Paths: `drivers/gpu/drm/msm/msm_drv.c`
- Decision: Guard failed component bind before preserving Miru last-close and shutdown ordering.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.

### lts: resolve MMC and UFS conflicts for 4.14.241

- Batch ID: `storage`
- Paths: `drivers/mmc/core/core.c drivers/mmc/core/mmc.c drivers/scsi/ufs/ufshcd.c`
- Decision: Power-cycle failed CMD11 with balanced clock gating, retain eMMC CMDQ/strobe support, and use translated UFS LUN with runtime-PM balancing.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.

### lts: resolve Qualcomm IPC conflicts for 4.14.241

- Batch ID: `ipc`
- Paths: `drivers/soc/qcom/smp2p.c net/qrtr/qrtr.c`
- Decision: Use IRQ-safe SMP2P locking and safe QRTR skb allocation while retaining downstream trace and wake behavior.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.

### lts: resolve TTY job-control conflict for 4.14.241

- Batch ID: `tty`
- Paths: `drivers/tty/tty_jobctrl.c`
- Decision: Use the stable outer ctrl_lock coverage without nested re-locking.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.
