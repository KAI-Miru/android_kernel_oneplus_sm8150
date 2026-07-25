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
- Reconnaissance: **in progress**
- Target object verification: **official ref identified; canonical Git-object re-hash pending CI**
- Authentic merge: **not started**
- Initial authentic conflicts: **pending merge preview**
- Index-resolved conflicts: **0**
- Semantically resolved conflicts: **0**
- Remaining semantic conflicts: **pending merge preview**
- Targeted compilation: **not started**
- Full kernel build: **not started**
- External-module build: **not started**
- Device-test status: **not performed for this milestone**
- Flash status: **not performed for this milestone**

## Immutable production baseline

The live `miru-h40` ref was read directly from GitHub before the integration
branch was created and resolved to:

```text
4394ccbfa3805ce392b65b3ea148ff1eb084a974
```

The top-level `Makefile` at this commit reports Linux `4.14.241`. The commit is
the production merge titled `Merge Miru H.40 Linux 4.14.241 into production`.
The new integration branch was created directly from this exact SHA. Production
must remain unchanged throughout this milestone.

## Authoritative Android Common target

- Repository: `https://android.googlesource.com/kernel/common`
- Tag: `ASB-2022-03-05_4.14-stable`
- Annotated tag object: `7ec0138c8a212a717efbf37824b83eebd0b2b7f2`
- Peeled target commit: `0eec6f6001d15bb1108835a642ec4637d75eef19`
- Target version: `4.14.269`
- Stable range for this milestone: `4.14.242` through `4.14.269`

The official Gitiles tag page identifies the tag object and peeled commit above
and identifies the peeled commit as the Android Common merge of Linux 4.14.269.
The annotated tag contains no known embedded signature claim at this stage.
Canonical tag and commit payloads must be re-hashed with Git and the ref must be
peeled in CI before the merge begins.

## Pinned build environment

The deliberately approved 4.14.241 production environment remains pinned unless
a newer repository document explicitly supersedes it:

- Vendor/modules repository: `KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150`
- Vendor/modules commit: `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`
- Expected external modules: exactly `32` `.ko` files
- Clang repository commit: `252aba16f513a857bc923172f67b0e55e23de35f`
- Clang package: `clang-r377782c`
- AArch64 GCC/binutils commit: `606f80986096476912e04e5c2913685a8f2c3b65`
- ARM32 GCC/binutils commit: `b0c6a654327ca8796bed1e61dffcf523d04dceaa`
- AOSP build-tools commit: `7322db1e1e4715fe217a27f721613e6be8438676`
- Production stock config: `h40-repro/config/GM1911_11_H.40.config`
- Official fallback defconfig: `vendor/sm8150-perf_defconfig`
- Production build driver: `h40-repro/build-h40.sh`
- Existing CI wrapper: `scripts/miru/ci_build_4.14.190.sh`
- External-module build driver: `scripts/miru/build_external_modules_4.14.190.sh`

No toolchain or vendor-source upgrade is part of this LTS integration.

## Repository reconnaissance summary

- Default branch: `miru-h40`
- Live production head: `4394ccbfa3805ce392b65b3ea148ff1eb084a974`
- Production kernel version: `4.14.241`
- Current permanent workflow: `.github/workflows/miru-h40-build.yml`
- Existing completed ledgers: 4.14.190, 4.14.210 and 4.14.241
- Existing 4.14.241 validation record: `Documentation/miru/lts-4.14.241-validation.md`
- Previous Android Common target in production ancestry: `a446f52a5d3fc71698a073d08ce1eeb923727b42`
- Stale prior milestone branch observed: `miru-h40-lts241-integration` at `0f419ca269b112a1fbf6cac188b6349cbc1a38ce`
- 4.14.269 target ancestry in production: **pending explicit Git verification; version and history indicate absent**
- Patch-equivalent 4.14.242–4.14.269 commits already present: **pending `git cherry` reconnaissance**

## Authentic merge procedure

After target verification and final reconnaissance, the exact ledger/preparation
commit will be merged with the verified target using:

```text
git fetch --force --no-tags https://android.googlesource.com/kernel/common \
  refs/tags/ASB-2022-03-05_4.14-stable:refs/tags/ASB-2022-03-05_4.14-stable
git checkout miru-h40-lts269-integration
git merge --no-commit --no-ff 0eec6f6001d15bb1108835a642ec4637d75eef19
```

Before a scaffold commit is created, the complete original conflict list and all
stage-1/base, stage-2/Miru and stage-3/Android-Common conflict blobs must be
preserved. Cleanly merged paths must remain as Git produced them. For scaffold
creation only, unresolved conflict paths may be staged from the Miru side, but
every such path remains `index-resolved but semantically unresolved` until a
focused owning commit completes the semantic resolution.

Required scaffold parents:

- Parent 1: the final ledger/preparation commit based on production
- Parent 2: `0eec6f6001d15bb1108835a642ec4637d75eef19`

## Authentic conflict manifest

Pending the no-commit merge preview.

| # | Path | Semantic subsystem | Index status | Semantic status | Owning resolution commit | Validation |
|---:|---|---|---|---|---|---|

## Clean-merge semantic audit

The following downstream-sensitive areas require explicit review even when Git
reports no textual conflict:

- DT2W
- AOD and brightness behavior
- smart-PA and audio fixes
- MSM/SDE display shutdown and last-close behavior
- Qualcomm reserved networking-port policy
- USB gadget, ADB and charging behavior
- UFS initialization, power management and shutdown behavior
- Qualcomm IPC, GLINK and QRTR behavior
- Binder compatibility with the ColorOS 14 port
- OPlus touchscreen and display interfaces
- exported kernel symbols, `CONFIG_MODVERSIONS` and symbol CRCs
- private headers and interfaces consumed by external vendor modules
- all Miru changes applied after the 4.14.241 integration scaffold

## Resolution semantics

Each conflict row must record one of the following outcomes:

- upstream behavior semantically imported while downstream behavior is preserved;
- downstream behavior intentionally retained with upstream intent accounted for;
- a combined adaptation replaces both textual sides;
- no source change required after semantic analysis.

An unmerged-path count of zero is not semantic completion. Every authentic
conflict requires an owning focused commit and clean-reversal validation.

## Validation summary

- Remaining authentic conflict count: **pending**
- Remaining semantic conflict count: **pending**
- Clean-reversal results: **not started**
- Incremental compilation: **not started**
- Final semantic audit: **not started**
- Full kernel and external-module build: **not started**
- Physical device validation: **not performed**
