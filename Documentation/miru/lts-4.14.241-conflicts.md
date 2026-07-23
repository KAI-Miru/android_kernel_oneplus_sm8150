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
- Index-resolved conflicts: **32**
- Semantically resolved conflicts: **32**
- Remaining semantic conflicts: **0**
- Merge scaffold: `ff895111416c91c1aaf9acf518ca79ac3f66a80b` — authentic two-parent merge
- Targeted compilation: **PASS for every resolution batch**
- Exact-source kernel build: **PASS** — run `29967983528` built
  `935b66cf9ef5bcbd40063e830935744b35a3d5cf` as
  `4.14.241-miru-h40-lts241-qrtr-ci6+`.
- Matching external modules: the permanent 4.14.241 workflow rebuilds a
  matching `ci7` drop-in package and ABI report for this PR and again for the
  merge commit. The existing `ci4` package was device-tested successfully under
  the `ci6` kernel and is ABI-compatible through `CONFIG_MODVERSIONS`.
- Device-test status: **PASS** — the exact `ci6` kernel booted on a real
  OnePlus 7 Pro after the QRTR correction and GLINK revert.
- Flash status: performed by the device owner; the boot result is recorded in
  the validation report.
- Release decision: the source is approved for the normal merge-commit
  promotion after the PR workflow and post-merge workflow each create a
  matching `ci7` kernel and 32-module package with a zero-error ABI report.

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
| 1 | `arch/x86/Makefile` | non-target x86 build system | index-resolved in scaffold | resolved | `0818d274ec0f97a3fef70194b629821c3294e191` | targeted compile PASS; clean reversal PASS |
| 2 | `drivers/block/zram/zram_drv.c` | block / compressed memory | index-resolved in scaffold | resolved | `648f5dd2045b4c016cc7c3c411f7946ee48ec914` | targeted compile PASS; clean reversal PASS |
| 3 | `drivers/dma-buf/dma-buf.c` | dma-buf core | index-resolved in scaffold | resolved | `648f5dd2045b4c016cc7c3c411f7946ee48ec914` | targeted compile PASS; clean reversal PASS |
| 4 | `drivers/gpu/drm/msm/msm_drv.c` | MSM DRM / display shutdown | index-resolved in scaffold | resolved | `33956504e5210f733b042f005b09de4d8c9fba3b` | targeted compile PASS; clean reversal PASS |
| 5 | `drivers/mmc/core/core.c` | MMC core | index-resolved in scaffold | resolved | `4febfdd243664284e5c245b1664633ec3f8b816b` | targeted compile PASS; clean reversal PASS |
| 6 | `drivers/mmc/core/mmc.c` | MMC device initialization | index-resolved in scaffold | resolved | `4febfdd243664284e5c245b1664633ec3f8b816b` | targeted compile PASS; clean reversal PASS |
| 7 | `drivers/scsi/ufs/ufshcd.c` | UFS core / power management | index-resolved in scaffold | resolved | `4febfdd243664284e5c245b1664633ec3f8b816b` | targeted compile PASS; clean reversal PASS |
| 8 | `drivers/soc/qcom/smp2p.c` | Qualcomm SMP2P IPC | index-resolved in scaffold | resolved | `72fd5a8910a28d4a7aa2498a58794b6c3282eb44` | targeted compile PASS; clean reversal PASS |
| 9 | `drivers/tty/tty_jobctrl.c` | TTY job control | index-resolved in scaffold | resolved | `49d6e32da6048bbef578be52367256effeafb709` | targeted compile PASS; clean reversal PASS |
| 10 | `drivers/usb/core/hub.c` | USB hub / enumeration | index-resolved in scaffold | resolved | `5fe5c247754d0b958f389fbde25541ff6c23526b` | targeted compile PASS; clean reversal PASS |
| 11 | `drivers/usb/dwc3/core.c` | DWC3 core / power and role handling | index-resolved in scaffold | resolved | `5fe5c247754d0b958f389fbde25541ff6c23526b` | targeted compile PASS; clean reversal PASS |
| 12 | `drivers/usb/dwc3/gadget.c` | DWC3 gadget | index-resolved in scaffold | resolved | `5fe5c247754d0b958f389fbde25541ff6c23526b` | targeted compile PASS; clean reversal PASS |
| 13 | `drivers/usb/gadget/configfs.c` | USB gadget configfs / Android composition | index-resolved in scaffold | resolved | `5fe5c247754d0b958f389fbde25541ff6c23526b` | targeted compile PASS; clean reversal PASS |
| 14 | `drivers/usb/gadget/function/f_accessory.c` | Android USB accessory function | index-resolved in scaffold | resolved | `5fe5c247754d0b958f389fbde25541ff6c23526b` | targeted compile PASS; clean reversal PASS |
| 15 | `drivers/usb/gadget/function/f_fs.c` | FunctionFS / ADB | index-resolved in scaffold | resolved | `5fe5c247754d0b958f389fbde25541ff6c23526b` | targeted compile PASS; clean reversal PASS |
| 16 | `drivers/usb/gadget/function/f_uac1.c` | USB audio gadget UAC1 | index-resolved in scaffold | resolved | `5fe5c247754d0b958f389fbde25541ff6c23526b` | targeted compile PASS; clean reversal PASS |
| 17 | `drivers/usb/gadget/function/f_uac2.c` | USB audio gadget UAC2 | index-resolved in scaffold | resolved | `5fe5c247754d0b958f389fbde25541ff6c23526b` | targeted compile PASS; clean reversal PASS |
| 18 | `fs/incfs/data_mgmt.c` | Incremental FS data management | index-resolved in scaffold | resolved | `92bfc038c04c279027c0ddfb4cd88b9bbfa31273` | targeted compile PASS; clean reversal PASS |
| 19 | `fs/incfs/format.c` | Incremental FS on-disk format | index-resolved in scaffold | resolved | `92bfc038c04c279027c0ddfb4cd88b9bbfa31273` | targeted compile PASS; clean reversal PASS |
| 20 | `fs/incfs/main.c` | Incremental FS module lifecycle | index-resolved in scaffold | resolved | `92bfc038c04c279027c0ddfb4cd88b9bbfa31273` | targeted compile PASS; clean reversal PASS |
| 21 | `fs/incfs/pseudo_files.c` | Incremental FS pseudo files; modify/delete conflict | index-resolved in scaffold | resolved | `92bfc038c04c279027c0ddfb4cd88b9bbfa31273` | targeted compile PASS; clean reversal PASS |
| 22 | `fs/incfs/vfs.c` | Incremental FS VFS and mount behavior | index-resolved in scaffold | resolved | `92bfc038c04c279027c0ddfb4cd88b9bbfa31273` | targeted compile PASS; clean reversal PASS |
| 23 | `include/linux/usb/usbnet.h` | USB networking private interface | index-resolved in scaffold | resolved | `5fe5c247754d0b958f389fbde25541ff6c23526b` | targeted compile PASS; clean reversal PASS |
| 24 | `kernel/bpf/helpers.c` | BPF helper ABI | index-resolved in scaffold | resolved | `928cf84b7c73c03c14136efada744825a12d9d00` | targeted compile PASS; clean reversal PASS |
| 25 | `kernel/cgroup/cgroup.c` | cgroup core; downstream implementation retained | index-resolved in scaffold | resolved with no source delta | `928cf84b7c73c03c14136efada744825a12d9d00` (ledger resolution) | targeted compile PASS; clean reversal PASS |
| 26 | `kernel/cpu.c` | CPU hotplug / core lifecycle | index-resolved in scaffold | resolved | `928cf84b7c73c03c14136efada744825a12d9d00` | targeted compile PASS; clean reversal PASS |
| 27 | `kernel/futex.c` | futex core | index-resolved in scaffold | resolved | `928cf84b7c73c03c14136efada744825a12d9d00` | targeted compile PASS; clean reversal PASS |
| 28 | `kernel/sched/fair.c` | CFS scheduler | index-resolved in scaffold | resolved | `928cf84b7c73c03c14136efada744825a12d9d00` | targeted compile PASS; clean reversal PASS |
| 29 | `net/core/skbuff.c` | networking skb core | index-resolved in scaffold | resolved | `768a262b43ee51ce8aeb02863e0cf3729e67462a` | targeted compile PASS; clean reversal PASS |
| 30 | `net/qrtr/qrtr.c` | Qualcomm QRTR IPC | index-resolved in scaffold | resolved | `72fd5a8910a28d4a7aa2498a58794b6c3282eb44` | targeted compile PASS; clean reversal PASS |
| 31 | `net/sctp/sm_make_chunk.c` | SCTP networking | index-resolved in scaffold | resolved | `768a262b43ee51ce8aeb02863e0cf3729e67462a` | targeted compile PASS; clean reversal PASS |
| 32 | `security/selinux/avc.c` | SELinux AVC | index-resolved in scaffold | resolved | `ba427f46b9286f8bdd7223fc032472f26d519123` | targeted compile PASS; clean reversal PASS |

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
| merge scaffold | 32 | yes | no | prohibited | not applicable | `ff895111416c91c1aaf9acf518ca79ac3f66a80b` |
| non-target x86 build | 1 | yes | yes | PASS | PASS | `0818d274ec0f97a3fef70194b629821c3294e191` |
| zram and dma-buf | 2 | yes | yes | PASS | PASS | `648f5dd2045b4c016cc7c3c411f7946ee48ec914` |
| MSM DRM display | 1 | yes | yes | PASS | PASS | `33956504e5210f733b042f005b09de4d8c9fba3b` |
| MMC and UFS storage | 3 | yes | yes | PASS | PASS | `4febfdd243664284e5c245b1664633ec3f8b816b` |
| Qualcomm IPC | 2 | yes | yes | PASS | PASS | `72fd5a8910a28d4a7aa2498a58794b6c3282eb44` |
| TTY job control | 1 | yes | yes | PASS | PASS | `49d6e32da6048bbef578be52367256effeafb709` |
| USB core and gadget | 8 | yes | yes | PASS | PASS | `5fe5c247754d0b958f389fbde25541ff6c23526b` |
| Incremental FS | 5 | yes | yes | PASS | PASS | `92bfc038c04c279027c0ddfb4cd88b9bbfa31273` |
| kernel core and scheduler | 5 | yes | yes | PASS; `cgroup.c` retained downstream | PASS | `928cf84b7c73c03c14136efada744825a12d9d00` |
| networking | 2 | yes | yes | PASS | PASS | `768a262b43ee51ce8aeb02863e0cf3729e67462a` |
| SELinux AVC | 1 | yes | yes | PASS | PASS | `ba427f46b9286f8bdd7223fc032472f26d519123` |

## Build and test policy

The semantic gate was satisfied before the exact-source build: all 32 authentic
conflicts were semantically resolved, each owning batch passed targeted
compilation and clean reversal, high-risk clean merges were audited, and no
semantic conflict remained. The later real-device boot test provides the
runtime gate. Automation itself does not flash a phone.

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

### lts: resolve USB core and gadget conflicts for 4.14.241

- Batch ID: `usb`
- Paths: `drivers/usb/core/hub.c drivers/usb/dwc3/core.c drivers/usb/dwc3/gadget.c drivers/usb/gadget/configfs.c drivers/usb/gadget/function/f_accessory.c drivers/usb/gadget/function/f_fs.c drivers/usb/gadget/function/f_uac1.c drivers/usb/gadget/function/f_uac2.c include/linux/usb/usbnet.h`
- Decision: Import stable resume, teardown, lifetime, descriptor and packet-size fixes while preserving Android gadget, ADB, synchronous audio and Qualcomm usbnet behavior.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.

### lts: resolve Incremental FS conflicts for 4.14.241

- Batch ID: `incfs`
- Paths: `fs/incfs/data_mgmt.c fs/incfs/format.c fs/incfs/main.c fs/incfs/pseudo_files.c fs/incfs/vfs.c`
- Decision: Follow Android Common's deliberate v2 rollback and preserve mount-owner credential overrides and downstream open validation.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.

### lts: resolve kernel core and scheduler conflicts for 4.14.241

- Batch ID: `kcore`
- Paths: `kernel/bpf/helpers.c kernel/cgroup/cgroup.c kernel/cpu.c kernel/futex.c kernel/sched/fair.c`
- Decision: Import BPF boot time, CPU/cpuset, futex and scheduler fixes while retaining downstream cgroup feature controls and isolated-CPU policy. `kernel/cgroup/cgroup.c` was intentionally retained from downstream; its ledger resolution required no source change.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.

### lts: resolve networking conflicts for 4.14.241

- Batch ID: `net`
- Paths: `net/core/skbuff.c net/sctp/sm_make_chunk.c`
- Decision: Use stable tiny-skb/truesize and SCTP validation fixes while retaining forced DMA-zone allocation.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.

### lts: resolve SELinux AVC conflict for 4.14.241

- Batch ID: `selinux`
- Paths: `security/selinux/avc.c security/selinux/include/security.h`
- Decision: Retain the already-present __GFP_NOWARN allocation semantics, and remove the clean-merge duplicate android_netlink_getneigh field while preserving both Android netlink policy capabilities.
- Index state: resolved in the scaffold; this commit provides the semantic resolution.
- Targeted compilation: performed immediately after this commit.
- Clean-reversal validation: performed immediately after this commit against the scaffold.

### Clean-merge audit: LPFC mailbox EOF whitespace

- Owning commit: `e8e94d363e57ab89d61fff638c89a274b84feab6`
- Source: `drivers/scsi/lpfc/lpfc_mbox.c`
- Decision: remove one Android Common-introduced blank line at EOF so the strict repository-wide `git diff --check` gate remains clean.
- Targeted compilation: `drivers/scsi/lpfc/lpfc_mbox.o` PASS.
- Clean reversal to scaffold state: PASS.

## CI transaction history

- Successful authoritative reconnaissance: run `29798735690`; artifact `miru-lts241-recon-29798735690`.
- Cancelled partial-clone reconnaissance: run `29798900321`; no artifact was uploaded and it is not used as evidence.
- Successful scaffold transaction: run `29800349747`; scaffold `ff895111416c91c1aaf9acf518ca79ac3f66a80b`.
- Earlier scaffold helper failures were closed without merge and did not move production or integration refs.

## Semantic resolution commits

| Batch | Commit | Subject | Source paths | Validation |
|---|---|---|---|---|
| `x86` | `0818d274ec0f97a3fef70194b629821c3294e191` | lts: resolve x86 build conflict for 4.14.241 | `arch/x86/Makefile` | targeted compile PASS; clean reversal PASS |
| `corebuf` | `648f5dd2045b4c016cc7c3c411f7946ee48ec914` | lts: resolve zram and dma-buf conflicts for 4.14.241 | `drivers/block/zram/zram_drv.c drivers/dma-buf/dma-buf.c` | targeted compile PASS; clean reversal PASS |
| `drm` | `33956504e5210f733b042f005b09de4d8c9fba3b` | lts: resolve MSM display conflict for 4.14.241 | `drivers/gpu/drm/msm/msm_drv.c` | targeted compile PASS; clean reversal PASS |
| `storage` | `4febfdd243664284e5c245b1664633ec3f8b816b` | lts: resolve MMC and UFS conflicts for 4.14.241 | `drivers/mmc/core/core.c drivers/mmc/core/mmc.c drivers/scsi/ufs/ufshcd.c` | targeted compile PASS; clean reversal PASS |
| `ipc` | `72fd5a8910a28d4a7aa2498a58794b6c3282eb44` | lts: resolve Qualcomm IPC conflicts for 4.14.241 | `drivers/soc/qcom/smp2p.c net/qrtr/qrtr.c` | targeted compile PASS; clean reversal PASS |
| `tty` | `49d6e32da6048bbef578be52367256effeafb709` | lts: resolve TTY job-control conflict for 4.14.241 | `drivers/tty/tty_jobctrl.c` | targeted compile PASS; clean reversal PASS |
| `usb` | `5fe5c247754d0b958f389fbde25541ff6c23526b` | lts: resolve USB core and gadget conflicts for 4.14.241 | `drivers/usb/core/hub.c drivers/usb/dwc3/core.c drivers/usb/dwc3/gadget.c drivers/usb/gadget/configfs.c drivers/usb/gadget/function/f_accessory.c drivers/usb/gadget/function/f_fs.c drivers/usb/gadget/function/f_uac1.c drivers/usb/gadget/function/f_uac2.c include/linux/usb/usbnet.h` | targeted compile PASS; clean reversal PASS |
| `incfs` | `92bfc038c04c279027c0ddfb4cd88b9bbfa31273` | lts: resolve Incremental FS conflicts for 4.14.241 | `fs/incfs/data_mgmt.c fs/incfs/format.c fs/incfs/main.c fs/incfs/pseudo_files.c fs/incfs/vfs.c` | targeted compile PASS; clean reversal PASS |
| `kcore` | `928cf84b7c73c03c14136efada744825a12d9d00` | lts: resolve kernel core and scheduler conflicts for 4.14.241 | `kernel/bpf/helpers.c kernel/cgroup/cgroup.c kernel/cpu.c kernel/futex.c kernel/sched/fair.c` | targeted compile PASS; clean reversal PASS |
| `net` | `768a262b43ee51ce8aeb02863e0cf3729e67462a` | lts: resolve networking conflicts for 4.14.241 | `net/core/skbuff.c net/sctp/sm_make_chunk.c` | targeted compile PASS; clean reversal PASS |
| `selinux` | `ba427f46b9286f8bdd7223fc032472f26d519123` | lts: resolve SELinux AVC conflict for 4.14.241 | `security/selinux/avc.c security/selinux/include/security.h` | targeted compile PASS; clean reversal PASS |

All 32 authentic conflicts have an owning resolution record. The exact-source
kernel build and real-device boot test subsequently passed; the permanent
workflow is responsible for producing the fresh matching module package used
for production publication.

## Full-build clean-merge audit: Qualcomm qmi_rmnet ICMPv6 helper

- Source: `drivers/soc/qcom/qmi_rmnet.c`
- Discovery: full validation run `29809621281` failed because `icmp6_hdr()` was no longer visible through the previous transitive include chain.
- Decision: include the owning header `<linux/icmpv6.h>` explicitly; packet classification logic is unchanged.
- Validation contract: clean reversal to semantic head `259c596bf59d5717aa72f313437317ba72adda14`, followed by the complete pinned kernel and 32-module build.

## Device-panic audit: downstream dma-buf ownership and release lifecycle

- Panic: `mm/slub.c:343` from `delayed_fput -> dma_buf_release` after TWRP stopped `qseecomd`.
- Root cause: downstream `dma_buf_export()` aliases `dmabuf->name` to `dmabuf->buf_name`; the 4.14.241 destructor freed both pointers unconditionally.
- Ownership fix: free `dmabuf->name` only when it differs from `dmabuf->buf_name`, both when renaming and during final destruction.
- Lifecycle fix: restore `db_list` removal to `dma_buf_file_release()` and wire it through `dma_buf_fops.release`, matching the device-tested 4.14.210 tree.
- Validation contract: clean reversal to source head `65c63badd41cb56d98984ed664d6108ac7e36702`, full pinned kernel build, and exact 32-module ABI validation.


## Device-boot audit: GLINK missing-channel intent FIFO advance

- Symptom: SLPI/FastRPC repeatedly disconnected during early Android boot and userspace stopped before Zygote without a kernel panic.
- Root cause candidate: `qcom_glink_handle_intent()` returned for a missing channel without consuming the current `RPM_CMD_INTENT` packet, allowing the RX worker to process the same FIFO entry indefinitely.
- Decision: advance the RX FIFO by `ALIGN(msglen, 8)` before returning, while retaining the separate 4.14.241 `ret = -ENOENT` correction for missing local intents.
- Scope: one downstream-compatible line matching the later upstream/LineageOS fix; no whole-file rollback and no suspend-path changes.
- Validation contract: clean reversal to source head `eeccfbe1247e82b1071fe606785f97d97cdcc586`, full pinned kernel build, and exact 32-module ABI validation.


## Superseded experimental GLINK RX workaround (reverted)

- The earlier experiment converted `qcom_glink_rx_data()` returning `-ENOENT`
  into success in the `RPM_CMD_TX_DATA*` IRQ path so the RX loop would keep
  draining. It was an experiment, not a LineageOS-backed source resolution.
- Review found no supporting LineageOS reference for suppressing that error.
  The workaround was therefore removed in
  `935b66cf9ef5bcbd40063e830935744b35a3d5cf`
  (`rpmsg: restore GLINK RX error propagation`).
- The revert changes only `drivers/rpmsg/qcom_glink_native.c` and restores
  normal GLINK RX error propagation. It does **not** remove the independently
  justified missing-channel FIFO advance in `qcom_glink_handle_intent()`.

## Final device-tested fixes and evidence

### QRTR allocation/lifetime correction

- The splash-screen boot loop was traced to `net/qrtr/qrtr.c`.
  After `alloc_skb_with_frags()` had produced the downstream SKB and its backup
  / fragment state had been derived, an upstream
  `__netdev_alloc_skb()` allocation overwrote that pointer.
- `47f4767bd9040d574664d5b93abe3a54b97aa4e2`
  removes only that second allocation. The downstream
  `alloc_skb_with_frags()` and `qrtr_get_backup()` lifetime model remains
  intact.

### Exact-source build and phone boot

- GitHub Actions run: `29967983528`
- Source built: `935b66cf9ef5bcbd40063e830935744b35a3d5cf`
- Tested release: `4.14.241-miru-h40-lts241-qrtr-ci6+`
- Kernel artifact: `miru-h40-lts-4.14.241-qrtr-ci6-build`, ID `8548812175`,
  digest `sha256:c1a7b97368547b3fcb4a7b1abbd8de1cdc9e0549b5d7a7c13c6cf18d665d8e82`
- Diagnostics artifact: `miru-h40-lts-4.14.241-qrtr-ci6-diagnostics`, ID
  `8548812492`, digest
  `sha256:dad5dbce73723bcb7dfbee5ac2d0256b7a834572ecb09b71cf0625d05996c0d9`
- The overall Actions result is red only because the final temporary-workflow
  cleanup step failed. Checkout, exact-source verification, the clean kernel
  compilation, and both artifact uploads succeeded.
- The resulting kernel booted successfully on a real OnePlus 7 Pro. Earlier
  candidates boot-looped at the splash screen and fell back to TWRP.

### External module compatibility observed on the phone

- The phone used the existing 32-module `ci4` package. Its vermagic was
  `4.14.241-miru-h40-lts241-ci4+ SMP preempt mod_unload modversions aarch64`;
  the running kernel was
  `4.14.241-miru-h40-lts241-qrtr-ci6+`.
- This is valid with `CONFIG_MODVERSIONS=y`: `same_magic()` in
  `kernel/module.c` ignores the leading release-string field when version CRCs
  are present, while the individual exported-symbol CRCs are still checked.
- WLAN and the complete applicable audio stack loaded normally. No
  `version magic`, `Unknown symbol`, `disagrees about version`, invalid-module,
  or exec-format errors were observed in `dmesg`.
- This proves `ci4` is ABI-compatible with the booting `ci6` kernel. It does
  **not** claim that a newly rebuilt matching `ci6` module package was tested
  on the phone; the permanent workflow will publish a matching release package.

## Change classification

- **Authentic source integration:** the Android Common 4.14.211–4.14.241
  merge scaffold and clean upstream stable changes.
- **Semantic conflict resolutions:** the 32 focused resolution records listed
  above; `kernel/cgroup/cgroup.c` is explicitly a no-source-delta retention.
- **Later device-tested source fixes:** qmi-rmnet include correction, dma-buf
  lifetime/list correction, the LineageOS-backed GLINK missing-channel FIFO
  advance, the QRTR correction, and the GLINK workaround revert.
- **CI/documentation cleanup only:** temporary trigger workflows/branches and
  release records. These commits do not alter the runtime kernel source.
