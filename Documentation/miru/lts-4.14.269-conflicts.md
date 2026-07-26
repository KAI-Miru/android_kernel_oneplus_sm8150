# Miru H.40 to Android Common 4.14.269 integration ledger

This ledger tracks the staged integration of Android Common Linux 4.14.242
through 4.14.269 into the Miru H.40 OnePlus 7 Pro kernel. It distinguishes
Git index resolution from complete semantic resolution and also records cleanly
merged changes that require downstream review.

## Current status

- Integration branch: `miru-h40-lts269-integration`
- Production branch: `miru-h40`
- Immutable production baseline: `4394ccbfa3805ce392b65b3ea148ff1eb084a974`
- Production baseline version: `4.14.241`
- Ledger preparation date: `2026-07-26`
- Reconnaissance: **complete**
- Target object verification: **complete**
- Authentic merge preview: **complete**
- Authentic merge scaffold: **created and verified**
- Initial authentic conflicts: **22**
- Index-resolved conflicts: **22**
- Semantically resolved conflicts: **22**
- Remaining semantic conflicts: **0**
- Targeted compilation: **PASS for all eight conflict batches plus two clean-merge corrections**
- Exact validated source head: `14d41d8a57b1e08aa15ff786973b855c78f58fd7`
- Validated kernel release: `4.14.269-miru-h40-lts269-14d41d8-ci3+`
- Full kernel build: **PASS** — GitHub Actions run `30197447946`
- External-module build: **PASS** — exact 32-module set, matching vermagic, ABI errors `0`
- Device-test status: **PASS** — the maintainer flashed ci3 on a OnePlus 7 Pro and confirmed normal operation on 2026-07-26
- Flash status: **PASS** — `4.14.269-miru-h40-lts269-14d41d8-ci3+` was flashed successfully

## Immutable production baseline

The live `miru-h40` ref was read directly from GitHub before the integration
branch was created and resolved to:

```text
4394ccbfa3805ce392b65b3ea148ff1eb084a974
```

The top-level `Makefile` at this commit reports Linux `4.14.241`. The commit is
the two-parent production merge titled `Merge Miru H.40 Linux 4.14.241 into
production`, with first parent
`cc49ffcb5c5207746618a799b250c67decdc0d15` and second parent
`0f419ca269b112a1fbf6cac188b6349cbc1a38ce`. The new integration branch was
created directly from this exact production SHA. Production must remain
unchanged throughout this milestone.

## Authoritative Android Common target

- Repository: `https://android.googlesource.com/kernel/common`
- Tag: `ASB-2022-03-05_4.14-stable`
- Annotated tag object: `7ec0138c8a212a717efbf37824b83eebd0b2b7f2`
- Peeled target commit: `0eec6f6001d15bb1108835a642ec4637d75eef19`
- Target tree: `8b5c01bc580aef81a77ce2dcf3f7a3a56e09b8b8`
- Target version: `4.14.269`
- Stable range for this milestone: `4.14.242` through `4.14.269`

GitHub Actions run `30180408281` fetched the exact annotated tag directly from
Android Common and verified all of the following before any merge scaffold was
created:

1. `refs/tags/ASB-2022-03-05_4.14-stable` resolves to the exact supplied tag
   object SHA;
2. peeling the tag resolves to the exact supplied target commit SHA;
3. the object types are `tag` and `commit`;
4. re-hashing each canonical object payload with Git reproduces the supplied
   object ID;
5. the target `Makefile` reports Linux `4.14.269`;
6. the previous Android Common 4.14.241 target
   `a446f52a5d3fc71698a073d08ce1eeb923727b42` is an ancestor of production;
7. the new 4.14.269 target is not an ancestor of production.

No embedded-signature claim is made. Cryptographic identity is established by
exact ref peeling and canonical Git-object SHA-1 re-hashing.

Reconnaissance artifact:

- Workflow run: `30180408281`
- Name: `miru-lts269-recon-30180408281`
- Artifact ID: `8625406799`
- Size: `880517` bytes
- SHA-256: `afea052dc34b06a65defc0492f10c746b75e7015f2a990b6b9b3ac208920397b`

The run is red only because its final cleanup assertion expected a completely
empty worktree after `git merge --abort`, while the workflow's own untracked
`lts269-recon/` diagnostics directory was still present. Object verification,
repository reconnaissance, the authentic merge attempt, conflict-stage capture,
and artifact upload all completed. The cleanup assertion will be corrected
before any retry.

## Pinned build environment

The current workflow and repository documentation still retain the deliberately
approved 4.14.241 production environment. It remains pinned:

- Vendor/modules repository: `KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150`
- Vendor/modules commit: `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`
- Expected external modules: exactly `32` `.ko` files
- Clang repository commit: `252aba16f513a857bc923172f67b0e55e23de35f`
- Clang package: `clang-r377782c`
- AArch64 GCC/binutils commit: `606f80986096476912e04e5c2913685a8f2c3b65`
- ARM32 GCC/binutils commit: `b0c6a654327ca8796bed1e61dffcf523d04dceaa`
- AOSP build-tools commit: `7322db1e1e4715fe217a27f721613e6be8438676`
- Production stock config: `h40-repro/config/GM1911_11_H.40.config`
- Official defconfig entry points: `vendor/sm8150-perf_defconfig` and
  `vendor/sm8150_defconfig`
- Production build driver: `h40-repro/build-h40.sh`
- Existing CI wrapper: `scripts/miru/ci_build_4.14.190.sh`
- External-module build driver: `scripts/miru/build_external_modules_4.14.190.sh`

The production build driver uses the checked-in H.40 stock config by default and
builds `Image`, `Image.gz`, `Image.gz-dtb`, DTBs and in-tree modules. The external
module driver rebuilds the known 32-module manifest against the same kernel
output and validates vermagic and symbol CRCs. No compiler or vendor-source
upgrade is part of this LTS integration.

## Repository reconnaissance summary

- Default branch: `miru-h40`
- Live production head: `4394ccbfa3805ce392b65b3ea148ff1eb084a974`
- Production kernel version: `4.14.241`
- Current permanent workflow: `.github/workflows/miru-h40-build.yml`
- Existing completed ledgers: 4.14.190, 4.14.210 and 4.14.241
- Existing 4.14.241 validation record: `Documentation/miru/lts-4.14.241-validation.md`
- Previous Android Common target in production ancestry:
  `a446f52a5d3fc71698a073d08ce1eeb923727b42`
- Android Common 4.14.269 target in production ancestry: **absent**
- Full `rev-list` count in the previous-target to new-target graph: `1630`
- Patch-candidate entries reported by `git cherry`: `1602`
- Patch-equivalent entries already present in production: `3`
- Not patch-equivalent in production: `1599`
- Stale prior milestone branch: `miru-h40-lts241-integration` at
  `0f419ca269b112a1fbf6cac188b6349cbc1a38ce`
- Permanent non-production source branch: `oneplus/sm8150_s_12.1_op7pro` at
  `180d787684d5965be5145bcfbf666ed427b4ea18`
- Temporary helper base: `miru-h40-lts269-ci-base`; it must be deleted or
  neutralized after this milestone's CI work.

The three target-range commits whose patches are already equivalent in
production are:

```text
8b9d000e83eec02f11068583aa897268dc2d65d6
c8e76f849aed353347c5f08df575125324847834
2a899eeca5e8432a44d4cae9a7d44a0e862aff67
```

They are not treated as evidence that any larger 4.14.242-4.14.269 subsystem is
already integrated. The remaining target history enters through the authentic
merge.

## Authentic merge procedure

The exact ledger/preparation commit based on production will be merged with the
verified target using:

```text
git fetch --force --no-tags https://android.googlesource.com/kernel/common \
  refs/tags/ASB-2022-03-05_4.14-stable:refs/tags/ASB-2022-03-05_4.14-stable
git checkout miru-h40-lts269-integration
git merge --no-commit --no-ff 0eec6f6001d15bb1108835a642ec4637d75eef19
```

The no-commit preview was run against ledger commit
`48b12319641fc290d3b5dfe6232e0d5e12cdf6a6`. It produced exactly 22 authentic
conflicts. The authentic scaffold was then created at
`4f081ec063c9818adbe394b89f2ff035b27c30df` with first parent
`35404dc845143f99457e52b7b56d2392f9086123` and second parent
`0eec6f6001d15bb1108835a642ec4637d75eef19`. The complete original conflict list, index stages, and all available
stage-1/base, stage-2/Miru and stage-3/Android-Common files are preserved in the
reconnaissance artifact.

For scaffold creation, cleanly merged paths must remain exactly as Git produced
them. Every conflict path will be staged from the current Miru side only to make
a representable two-parent merge commit. Every such path will remain recorded as
`index-resolved but semantically unresolved` until a focused owning commit
completes the actual resolution.

Required scaffold parents:

- Parent 1: the final ledger/preparation commit based on production
- Parent 2: `0eec6f6001d15bb1108835a642ec4637d75eef19`

## Authentic conflict manifest

| # | Path | Semantic subsystem | Index status | Semantic status | Owning resolution commit | Validation |
|---:|---|---|---|---|---|---|
| 1 | `arch/arm/Makefile` | ARM build system | index-resolved in scaffold | resolved | 380d3aad61a3b26278017ebf35059783eb121b42 | targeted compile PASS; clean reversal PASS |
| 2 | `arch/arm64/mm/proc.S` | ARM64 MMU / processor setup | index-resolved in scaffold | resolved | 380d3aad61a3b26278017ebf35059783eb121b42 | targeted compile PASS; clean reversal PASS |
| 3 | `drivers/clk/clk.c` | common clock framework | index-resolved in scaffold | resolved | 4bf268ae2ad0a4a7128a16c9c5ae4a0e1022ca92 | targeted compile PASS; clean reversal PASS |
| 4 | `drivers/dma-buf/dma-buf.c` | dma-buf ownership and lifetime | index-resolved in scaffold | resolved with no source delta | 4bf268ae2ad0a4a7128a16c9c5ae4a0e1022ca92 | targeted compile PASS; clean reversal PASS |
| 5 | `drivers/hid/hid-chicony.c` | HID keyboard quirks | index-resolved in scaffold | resolved with no source delta | 7f3d8fd31204928c50fb7ad8c03db944410d6819 | targeted compile PASS; clean reversal PASS |
| 6 | `drivers/hid/hid-holtek-kbd.c` | HID keyboard quirks | index-resolved in scaffold | resolved | 7f3d8fd31204928c50fb7ad8c03db944410d6819 | targeted compile PASS; clean reversal PASS |
| 7 | `drivers/hid/hid-holtek-mouse.c` | HID mouse quirks | index-resolved in scaffold | resolved | 7f3d8fd31204928c50fb7ad8c03db944410d6819 | targeted compile PASS; clean reversal PASS |
| 8 | `drivers/hid/wacom_sys.c` | Wacom HID lifecycle | index-resolved in scaffold | resolved with no source delta | 7f3d8fd31204928c50fb7ad8c03db944410d6819 | targeted compile PASS; clean reversal PASS |
| 9 | `drivers/media/dvb-core/dmxdev.c` | DVB demux core | index-resolved in scaffold | resolved | e244ebbb15c0019bda151601ba6c96ad920e9ca7 | targeted compile PASS; clean reversal PASS |
| 10 | `drivers/staging/android/ion/ion.c` | Android ION memory allocator | index-resolved in scaffold | resolved with no source delta | 4bf268ae2ad0a4a7128a16c9c5ae4a0e1022ca92 | targeted compile PASS; clean reversal PASS |
| 11 | `drivers/usb/dwc3/gadget.c` | DWC3 gadget | index-resolved in scaffold | resolved | 37bd2903f8f5e7c2c687020d29bf33fe0df4a6b2 | targeted compile PASS; clean reversal PASS |
| 12 | `drivers/usb/gadget/composite.c` | USB composite gadget core | index-resolved in scaffold | resolved | 37bd2903f8f5e7c2c687020d29bf33fe0df4a6b2 | targeted compile PASS; clean reversal PASS |
| 13 | `drivers/usb/gadget/function/f_fs.c` | FunctionFS / ADB | index-resolved in scaffold | resolved | 37bd2903f8f5e7c2c687020d29bf33fe0df4a6b2 | targeted compile PASS; clean reversal PASS |
| 14 | `drivers/usb/gadget/function/rndis.c` | RNDIS gadget protocol | index-resolved in scaffold | resolved with no source delta | 37bd2903f8f5e7c2c687020d29bf33fe0df4a6b2 | targeted compile PASS; clean reversal PASS |
| 15 | `drivers/usb/gadget/function/rndis.h` | RNDIS private interface | index-resolved in scaffold | resolved with no source delta | 37bd2903f8f5e7c2c687020d29bf33fe0df4a6b2 | targeted compile PASS; clean reversal PASS |
| 16 | `drivers/usb/gadget/legacy/dbgp.c` | USB debug gadget | index-resolved in scaffold | resolved | 37bd2903f8f5e7c2c687020d29bf33fe0df4a6b2 | targeted compile PASS; clean reversal PASS |
| 17 | `drivers/usb/gadget/legacy/inode.c` | legacy gadget filesystem | index-resolved in scaffold | resolved | 37bd2903f8f5e7c2c687020d29bf33fe0df4a6b2 | targeted compile PASS; clean reversal PASS |
| 18 | `fs/file_table.c` | VFS file lifetime | index-resolved in scaffold | resolved | 7f777aa60e37ce39fa6d3d0975740089b5560a0a | targeted compile PASS; clean reversal PASS |
| 19 | `fs/fuse/file.c` | FUSE I/O and lifetime | index-resolved in scaffold | resolved | 7f777aa60e37ce39fa6d3d0975740089b5560a0a | targeted compile PASS; clean reversal PASS |
| 20 | `kernel/sched/cpufreq_schedutil.c` | schedutil frequency governor | index-resolved in scaffold | resolved | 4256e7d052a52c9db467dd095d2f9d1ed8e41cc9 | targeted compile PASS; clean reversal PASS |
| 21 | `net/ipv4/ip_gre.c` | IPv4 GRE networking | index-resolved in scaffold | resolved | 26f9bf82de03c2a094efceff0d568011f54ebfff | targeted compile PASS; clean reversal PASS |
| 22 | `net/packet/af_packet.c` | packet socket networking | index-resolved in scaffold | resolved | 26f9bf82de03c2a094efceff0d568011f54ebfff | targeted compile PASS; clean reversal PASS |

## Conflict-state definitions

### Index-level conflict resolution

An index-level resolution means Git no longer reports an unmerged stage for a
path. It does **not** establish semantic correctness. The scaffold performs only
this mechanical step so the authentic two-parent merge commit can exist.

### Semantic conflict resolution

A path becomes semantically resolved only after a focused commit identifies the
upstream stable changes and their bug intent, compares base/Miru/target code,
applies the correct combined behavior, checks declarations/callers/private
interfaces, performs targeted compilation, and passes clean-reversal validation
back to the scaffold state.

### Non-conflicting upstream changes

All cleanly applicable 4.14.242-4.14.269 changes remain in the scaffold. They are
not authentic conflicts, but cleanly merged changes in downstream-sensitive
areas require explicit semantic review before the full build.

### Downstream behavior intentionally retained

Downstream behavior may be retained when it implements required Qualcomm,
OnePlus, OPlus, ColorOS or Miru semantics absent from generic Android Common.
Retention must be explicit and justified; whole-file `ours` resolution is not an
acceptable final semantic decision.

### Upstream behavior intentionally imported

Upstream behavior is imported when it fixes a bug or security issue without
breaking required downstream semantics. The final source may require a manual
adaptation rather than textual selection of either side.

### No-source-change resolutions

A conflict may ultimately require no source delta from the scaffold when audit
shows the Miru implementation already contains the upstream semantic fix or the
upstream code is inapplicable to the target configuration. Such a path still
requires an owning focused ledger commit and validation.

## Clean-merge semantic audit

The following downstream-sensitive areas require explicit review even though the
merge preview produced no textual conflict in most of them:

- [ ] DT2W kernel and vendor companion functionality
- [ ] AOD luminance, HBM and brightness behavior
- [ ] smart-PA and audio fixes
- [ ] MSM/SDE display shutdown and last-close behavior
- [ ] Qualcomm reserved networking-port policy
- [ ] USB gadget, ADB, accessory and charging behavior
- [ ] UFS initialization, power management and shutdown behavior
- [x] Qualcomm IPC, GLINK and QRTR behavior — protected QRTR/GLINK source gates PASS and full build PASS
- [ ] Binder compatibility with the ColorOS 14 port
- [ ] OPlus touchscreen and display interfaces
- [x] exported kernel symbols, `CONFIG_MODVERSIONS` and symbol CRCs — 32-module binary CRC audit errors `0`
- [x] private headers and interfaces consumed by external vendor modules — all expected 32 modules rebuilt successfully
- [ ] all Miru changes applied after the 4.14.241 integration scaffold

## Planned resolution batches

Only groups containing authentic conflicts will receive conflict-resolution
commits. Initial grouping, subject to upstream-history analysis:

1. ARM and ARM64 build/MMU conflicts;
2. common clock, dma-buf and ION memory-infrastructure conflicts;
3. HID input conflicts;
4. DVB demux conflict;
5. USB DWC3, composite, FunctionFS, RNDIS and legacy gadget conflicts;
6. VFS and FUSE conflicts;
7. schedutil conflict;
8. IPv4 GRE and packet-socket conflicts.

Unrelated groups will not be combined merely to reduce commit count.

## Validation summary

- Remaining authentic conflict count: **0** — all original 22 conflict paths are resolved
- Remaining semantic conflict count: **0**
- Clean-reversal results: **PASS for all eight owning commits**
- Incremental compilation: **PASS for all eight conflict batches**
- Final semantic audit: **PASS for source, ancestry, protected-path and build gates**
- Full kernel and external-module build: **PASS** — exact run `30197447946`
- Physical device validation: **PASS** — maintainer-flashed ci3 confirmed working on a OnePlus 7 Pro on 2026-07-26

## Semantic resolution records

### ARM and ARM64 build/MMU resolution
- Paths: `arch/arm/Makefile`, `arch/arm64/mm/proc.S`.
- Upstream commits: `1f66b391c76e40fc737ed4fd216bc9e217dcf4e0`, `11487021d37f28c1dfc22860b826d43d4a060c0f`, `c13d897b09515e63131c9e88318fbea653a1378d`.
- Decision: import the ARM build-flag cleanups while retaining Qualcomm/OnePlus overlay, module and downstream build behavior. Retain the downstream deferred DBM enable model in `proc.S`; widen the Cortex-A55 broken-DBM range in `arch/arm64/kernel/cpufeature.c` to all variants and revisions while retaining the Kryo-specific entries.
- Targeted compilation: ARM32 `arch/arm/kernel/entry-common.o`; ARM64 `arch/arm64/kernel/cpufeature.o` and `arch/arm64/mm/proc.o`.

- Owning commit token: `380d3aad61a3b26278017ebf35059783eb121b42`
- Clean reversal: PASS in a disposable worktree.

### Clock, dma-buf and ION resolution
- Paths: `drivers/clk/clk.c`, `drivers/dma-buf/dma-buf.c`, `drivers/staging/android/ion/ion.c`.
- Upstream commits: `bd0970398a7a50d5f4e09bfca73cb6249e7d5edc`, `6e6c15288df8c4c6264f394ece251ef9f64b0e3f`, `6c5bc69f722cb5e2fe47196ee8f1aabe6498f8a7`.
- Decision: remove the orphan clock list from the generic debugfs list array while preserving the downstream dedicated orphan debugfs views. The existing Miru dma-buf release/list lifecycle and ION mapping lifetime already contain the target fixes, so those two paths are semantic no-source-change resolutions.
- Targeted compilation: `drivers/clk/clk.o`, `drivers/dma-buf/dma-buf.o`, `drivers/staging/android/ion/ion.o`.

- Owning commit token: `4bf268ae2ad0a4a7128a16c9c5ae4a0e1022ca92`
- Clean reversal: PASS in a disposable worktree.

### HID input resolution
- Paths: `drivers/hid/hid-chicony.c`, `drivers/hid/hid-holtek-kbd.c`, `drivers/hid/hid-holtek-mouse.c`, `drivers/hid/wacom_sys.c`.
- Upstream commits: `43cc4686b15d7d3a2b65b125393ea3f3d477e7d1`, `37a6a8d76b01e2669941719eba0bab842a55a8e6`, `641784eb0b4538b958893d5d9ab5cd9461eabdac`, `cad5c7582322e158ec6a064de56a539fa091d130`.
- Decision: retain the existing Chicony USB guard and Wacom lifecycle fixes. Correct the Holtek keyboard's uninitialized parse result and make the Holtek mouse probe parse and start hardware with proper error propagation.
- Targeted compilation: the four conflicted HID objects.

- Owning commit token: `7f3d8fd31204928c50fb7ad8c03db944410d6819`
- Clean reversal: PASS in a disposable worktree.

### DVB demux resolution
- Path: `drivers/media/dvb-core/dmxdev.c`.
- Upstream commit: `cde0f1a0a486fb47017ef74e79f31aaf3444fff9`.
- Decision: import device-registration error checking and complete unwind cleanup while preserving downstream buffer sizing, capability handling and debugfs behavior.
- Targeted compilation: `drivers/media/dvb-core/dmxdev.o`.

- Owning commit token: `e244ebbb15c0019bda151601ba6c96ad920e9ca7`
- Clean reversal: PASS in a disposable worktree.

### USB core and gadget resolution
- Paths: `drivers/usb/dwc3/gadget.c`, `drivers/usb/gadget/composite.c`, `drivers/usb/gadget/function/f_fs.c`, `drivers/usb/gadget/function/rndis.c`, `drivers/usb/gadget/function/rndis.h`, `drivers/usb/gadget/legacy/dbgp.c`, `drivers/usb/gadget/legacy/inode.c`.
- Upstream commits: `0d18cda400d506e01c9c8108447c6ceddc0288f7`, `24749050f167ee4734f8b6183b6cb7403c7a09b6`, `a58d290e7cd85aaef2500ad1daea14202d0570c7`, `3594650c3ec1dbf4fbea5860aa5822150ca60d9d`, `c4ae95a816290ee2b9df80a8ca5ff3ec7cbe3b54`, `e7c8afee149134b438df153b09af7fd928a8bc24`, `6be75351b0acbde12f8c604bd9590b4ecc1daf8e`, `c7ad83d561df15ac6043d3b0d783aee777cf1731`, `9b3a3a363591aa002cd5abedbdca098f398eddd5`, `d3c17d5e271ab688cb117330ec85e125ebf24d88`, `e74a5b78c45ff97f41554c49115237954e5ea27e`, `32048f4be071f9a6966744243f1786f45bb22dc2`, `52500239e3f2d6fc77b6f58632a9fb98fe74ac09`, `4c22fbcef778badb00fb8bb9f409daa29811c175`, `669c2b178956718407af5631ccbc61c24413f038`.
- Decision: preserve Miru's stronger full memory barrier and downstream diagnostics. Import DWC3 started-list ring accounting, stale delayed-status reset, timeout continuation and bottom-half protection; composite self-powered and request-direction fixes; FunctionFS stream/lifetime/locking fixes; and legacy gadget direction checks. Existing RNDIS bounds and IRQ-safe locking are retained as semantic no-source-change resolutions.
- Targeted compilation: DWC3 gadget, composite, FunctionFS, RNDIS and legacy gadget objects represented by their Makefiles.

- Owning commit token: `37bd2903f8f5e7c2c687020d29bf33fe0df4a6b2`
- Clean reversal: PASS in a disposable worktree.

### VFS and FUSE resolution
- Paths: `fs/file_table.c`, `fs/fuse/file.c`.
- Upstream commits: `1d8e40836044aeff3192f072425ea19f5c5807eb`, `2cd45139c0f28ebfa7604866faee00c99231a62b`.
- Decision: add the `fput_many()` implementation matching the cleanly merged declaration and callers, and consistently gate FUSE I/O/lifetime paths with `fuse_is_bad()` so aborted connections do not continue unsafe operations.
- Targeted compilation: `fs/file_table.o`, `fs/fuse/file.o`.

- Owning commit token: `7f777aa60e37ce39fa6d3d0975740089b5560a0a`
- Clean reversal: PASS in a disposable worktree.

### Schedutil resolution
- Path: `kernel/sched/cpufreq_schedutil.c`.
- Upstream commit: `463c46705f321201090b69c4ad5da0cd2ce614c9`.
- Decision: provide the governor kobject release callback and preserve cached tunables before the final kobject put can free the tunables object, preventing a use-after-free while retaining downstream schedutil policy behavior.
- Targeted compilation: `kernel/sched/cpufreq_schedutil.o`.

- Owning commit token: `4256e7d052a52c9db467dd095d2f9d1ed8e41cc9`
- Clean reversal: PASS in a disposable worktree.

### IPv4 GRE and packet-socket resolution
- Paths: `net/ipv4/ip_gre.c`, `net/packet/af_packet.c`.
- Upstream commits: `99279223a37b46dc7716ec4e0ed4b3e03f1cfa4c`, `899e0319b3f58d85ac9a2f1d2895a71a275e2f4e`, `c38023032a598ec6263e008d62c7f02def72d5c7`, `a829ff7c8ec494eca028824628a964cde543dc76`.
- Decision: retain the already-present GRE checksum guard and normalize the merged block. Import the packet-socket network-namespace helper and READ/WRITE_ONCE fanout synchronization while retaining the existing guarded bitmap cleanup.
- Targeted compilation: `net/ipv4/ip_gre.o`, `net/packet/af_packet.o`.

- Owning commit token: `26f9bf82de03c2a094efceff0d568011f54ebfff`
- Clean reversal: PASS in a disposable worktree.

## Clean-merge semantic correction — MSM GEM import cleanup

- Path: `drivers/gpu/drm/msm/msm_gem.c`
- Classification: non-conflicting upstream change requiring downstream semantic adaptation.
- Trigger: the exact H.40 build reported `unused label 'fail'` as a forbidden new warning.
- Upstream intent: return `ERR_PTR(ret)` immediately when `msm_gem_new_impl()` fails, rather than entering cleanup for an object that was not successfully created.
- Downstream adaptation: retain the immediate upstream error return and remove the now-unreachable `fail:` block. Miru's delayed-import/cache-flag behavior remains unchanged.
- Owning correction commit: `96029c92c2019065e5be870109f74721f7489be6`
- Targeted compilation: **PASS** — `drivers/gpu/drm/msm/msm_gem.o`.
- Clean reversal: **PASS** — reverting the owning commit restores both assigned paths to integration head `3a01e9e0434b633f034186e6df5115e60054733b`.
- Full-build validation: **PASS** — exact source head `14d41d8a57b1e08aa15ff786973b855c78f58fd7`, run `30197447946`.

## Clean-merge semantic correction — Qualcomm event timer cached-rbtree initializer

- Path: `drivers/soc/qcom/event_timer.c`
- Classification: non-conflicting upstream timerqueue API change requiring downstream driver adaptation.
- Trigger: the exact H.40 build failed because `struct timerqueue_head` no longer contains legacy `head` and `next` fields.
- Upstream compatibility fix: `04a7b0c73544b667407ccee19baab02fd083bccf` (`driver: soc: qcom: event_timer.c: fix the compile error for LTS 4.14.254`).
- Upstream intent: initialize the timerqueue's cached rbtree with `RB_ROOT_CACHED`; all existing add/delete/get-next behavior continues through the timerqueue API.
- Downstream adaptation: replace only the per-CPU initializer with `.rb_root = RB_ROOT_CACHED`; Qualcomm event ordering, affinity migration and hrtimer behavior remain unchanged.
- Owning correction commit: `733320a6cd9f74ec378ae6cf0a4956323b859128`
- Targeted compilation: **PASS** — `drivers/soc/qcom/event_timer.o`.
- Clean reversal: **PASS** — reverting the owning commit restores both assigned paths to integration head `e4a7100fc896ae9d35c0dc212fb1647fa79bf225`.
- Full-build validation: **PASS** — exact source head `14d41d8a57b1e08aa15ff786973b855c78f58fd7`, run `30197447946`.


## Exact full-build and external-module validation

The final source build was performed from exact integration head
`14d41d8a57b1e08aa15ff786973b855c78f58fd7`. This ledger-finalization
commit changes documentation only; no kernel source, configuration, build script,
or vendor interface changed after the tested source head.

### Source and ancestry audit

- Workflow run: `30197447946`
- Result: **PASS**
- Production baseline: `4394ccbfa3805ce392b65b3ea148ff1eb084a974`
- Android Common target: `0eec6f6001d15bb1108835a642ec4637d75eef19`
- Authentic merge scaffold: `4f081ec063c9818adbe394b89f2ff035b27c30df`
- Commits after production: `1648`
- Changed files: `1387`
- Insertions: `12665`
- Deletions: `6013`
- Authentic conflicts: `22/22` resolved
- Remaining semantic conflicts: `0`
- QRTR protected-path gate: **PASS**
- GLINK protected-path gate: **PASS**
- Production unchanged: **YES**

### Kernel result

- Release: `4.14.269-miru-h40-lts269-14d41d8-ci3+`
- Compiler: Android Clang `r377782c`, Clang `10.0.5`
- Kernel build result: **SUCCESS**
- `Image`: `40136720` bytes; SHA-256 `30a6f4fb53e668e4909dd5c08af4fb9439fdc12e61e3295db7cc952a2686e7ca`
- `Image.gz`: `16112246` bytes; SHA-256 `885a0cce45d9c6d34a55f26aef0856ac162278355f77cb2041cc0cabd53292f0`
- `Image.gz-dtb`: `19075695` bytes; SHA-256 `6c9ae94b5cddd73929f7b894d276302783a8bfa56e03f3115be0153cf6e52bed`
- `.config` SHA-256: `cfcc829d0cf4241d5956dc805cabdb01ef45d81a9d22938603b75c259863a646`
- `System.map` SHA-256: `f3ff1e66b42188269e69b0e756c7e059d00311e2a75737dae4d89a2a9edb7909`
- `Module.symvers` SHA-256: `425a0158a7b2f465f187e9b70ce065ea0e0182b9ea09a84884d41cdb4932f23e`
- DTBs built: `5`
- In-tree `.ko` files produced by the kernel build: `13`

### External-module result

- Expected module set: `32`
- Built module set: `32`
- Module-set diff: empty
- Architecture checks: `32/32` AArch64
- Expected vermagic: `4.14.269-miru-h40-lts269-14d41d8-ci3+ SMP preempt mod_unload modversions aarch64`
- Vermagic checks: `32/32` PASS
- Binary symbol-CRC audit: **PASS**, errors `0`
- Runtime archive: `3048826` bytes; SHA-256 `0512d48f23ef3899f6cd90136eaec825c739726d4671a5f087f313be51bdfe4c`
- Audit archive: `5442052` bytes; SHA-256 `1cf59d89ff5e304ef8c17d08937417a11f0f12f878f3211f1d9c6912e3547789`

### GitHub Actions artifacts

- Kernel build artifact ID: `8630770373`; size `438046876` bytes; artifact digest
  `sha256:0166e18df8158045f51ae168f8a5ebc8d339a70875cdfb5570588cedf5154152`
- External-module artifact ID: `8630770614`; size `8491234` bytes; artifact digest
  `sha256:2fabd3ed8de1388b58dd5d3cf292cb3392f1dbe76a5d9f0bdf34f285c4f4fde4`
- Diagnostics artifact ID: `8630770804`; size `496699` bytes; artifact digest
  `sha256:958b35219b6dcf1257032ead6f23caeea50ca231e2535a07aa781557a973c5c2`
- Artifact expiry: `2026-08-25`

### Physical device validation

- Device: OnePlus 7 Pro.
- Release flashed: `4.14.269-miru-h40-lts269-14d41d8-ci3+`.
- Source tested: `14d41d8a57b1e08aa15ff786973b855c78f58fd7`.
- Result: on 2026-07-26, the maintainer confirmed that ci3 flashed successfully and everything worked as expected.
- Scope note: this is a real-device confirmation supplied by the maintainer; the CI artifact set remains the authoritative record for the reproducible build, module, vermagic and ABI checks.

### Pending release action

- Production merge has been authorized after the successful ci3 device validation. The integration tip differs from the tested source only by documentation-only commits.
