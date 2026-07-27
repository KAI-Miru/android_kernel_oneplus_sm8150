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
- Reconnaissance: **in progress**
- Target object verification: **tag canonical payload re-hash PASS; peeled commit raw-object re-hash gated in reconnaissance workflow**
- Authentic merge preview: **not yet complete**
- Authentic merge scaffold: **not yet created**
- Initial authentic conflicts: **pending preserved merge preview**
- Index-resolved conflicts: **0**
- Semantically resolved conflicts: **0**
- Remaining semantic conflicts: **pending authentic conflict count**
- Full kernel build: **not performed**
- External-module build: **not performed**
- Physical device testing: **not performed**
- Boot/runtime testing: **not performed**
- Flashing: **not performed**
- Production merge: **not performed**

## Mandatory baseline verification

The live `miru-h40` ref was read directly from GitHub immediately before branch
creation and resolved to:

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
  `15785765ddf700681daa8ead543b5811ffa000ad` is treated as milestone evidence,
  not as the production baseline.
- `Documentation/miru/lts-4.14.269-conflicts.md` records all 22 authentic
  conflicts semantically resolved, zero remaining semantic conflicts, successful
  targeted compilation and clean reversal testing.
- `Documentation/miru/lts-4.14.269-validation.md` records a successful full
  kernel build, the exact 32-module external set, matching vermagic and zero ABI
  errors, including binary symbol-CRC validation with `CONFIG_MODVERSIONS`.

The integration branch was created directly from the exact live production SHA.
No prior integration branch was used as its base.

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

Official Gitiles independently reports the exact tag object, peeled commit,
target tree, author/committer identity and Linux `4.14.305` Makefile version. The
annotated Android tag's canonical payload was independently reconstructed and
SHA-1 re-hashed to exactly:

```text
fb7d1aa1e00554d9ac07b2a6267f58e585569b81
```

The target merge commit contains additional canonical merge metadata that is not
present in normalized API output. The reconnaissance workflow must fetch the
exact objects from Android Common, run `git cat-file`, and re-hash the canonical
commit and tag payloads before it is allowed to attempt the merge preview. A
mismatch is a hard stop. No GPG verification claim is made here.

Ancestry checks already demonstrated through the mirrored Git graph:

- `0eec6f6001d15bb1108835a642ec4637d75eef19` is an ancestor of
  `4415bf5e08942aee6487946a3e0a50956ef68f1e`.
- `4415bf5e08942aee6487946a3e0a50956ef68f1e` is not an ancestor of the
  production baseline.

## Pinned H.40 build environment

The following revisions and entry points are immutable for this milestone unless
a verified incompatibility is isolated and separately justified:

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
- Proposed ledger path: `Documentation/miru/lts-4.14.305-conflicts.md`
- Existing integration branch check before creation: branch absent
- Integration branch creation point: exact production SHA above
- Permanent production workflow: `.github/workflows/miru-h40-build.yml`
- Previous milestone records:
  - `Documentation/miru/lts-4.14.269-conflicts.md`
  - `Documentation/miru/lts-4.14.269-validation.md`
- Previous exact validated source is present in production ancestry.
- New target object is present in the repository object graph but not in
  production ancestry.

## Authentic merge procedure

The verified peeled Android Common commit is the required real second parent.
The preview command is:

```text
git merge --no-commit --no-ff 4415bf5e08942aee6487946a3e0a50956ef68f1e
```

Before any scaffold is created, reconnaissance must preserve:

1. complete merge stdout and stderr;
2. every conflicted path from `git ls-files -u` and porcelain status;
3. all available stage-1/base, stage-2/Miru and stage-3/Android Common blobs;
4. rename/delete, add/add, delete/modify and mode conflict metadata;
5. cleanly merged paths separately from authentic textual conflicts;
6. pre-preview and post-abort tracked-tree hashes;
7. proof that `git merge --abort` restores the tracked worktree exactly;
8. workflow-created untracked diagnostics excluded from tracked-cleanliness
   assertions only.

The authentic merge scaffold may be created only after the preview artifact is
retrieved and inspected. Its required parent order is:

- parent 1: the final ledger/preparation commit based on production;
- parent 2: `4415bf5e08942aee6487946a3e0a50956ef68f1e`.

Every authentic conflict path staged from the Miru side in the scaffold remains
`index-resolved but semantically unresolved` until a later focused owning commit
performs analysis, targeted compilation and clean reversal testing.

## Authentic conflict manifest

The manifest will be populated verbatim from the preserved merge preview. Clean
merges and later clean-merge corrections do not increase the authentic conflict
count.

| # | Path | Conflict form | Semantic subsystem | Index status | Semantic status | Owning commit | Targeted compile | Clean reversal |
|---:|---|---|---|---|---|---|---|---|
| — | pending preview | pending | pending | unresolved | unresolved | — | — | — |

## Semantic resolution requirements

Each resolution commit must:

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

The audit must cover at least:

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

## Validation evidence

No build, module, ABI, runtime or hardware result is claimed at ledger
initialization. Exact workflow run IDs, artifact IDs, digests, sizes, expiry
dates, source SHA, release string and file hashes will be recorded only after
inspection of successful reports and downloaded artifacts.

## Explicit safety status

- Physical device testing: **not performed**
- Boot/runtime testing: **not performed**
- Flashing: **not performed**
- Production merge: **not performed**
- Production branch modification during this milestone: **prohibited**
