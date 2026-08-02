# Miru H.40 LTS integration

This document records production LTS milestones for the OnePlus 7 Pro Miru H.40 kernel. The permanent production branch is `miru-h40`; milestone integration branches are temporary and may be deleted after merge and tagging.

## Milestone 5: Linux 4.14.305

Status: **clean final release candidate CI-validated and device-confirmed; production promotion awaits explicit authorization**.

This milestone advances Miru H.40 from Linux 4.14.269 to Android Common Linux 4.14.305 while preserving pristine OnePlus H.40 ancestry, the authentic two-parent Android Common integration, all downstream Oplus/Qualcomm functionality, and KCAL.

| Item | Revision |
|---|---|
| Immutable production base | `61371a1024e341f434deaf61b79a05f73827260a` |
| Permanent rollback tag | `miru-h40-4.14.269-final` |
| Pristine OnePlus H.40 | `180d787684d5965be5145bcfbf666ed427b4ea18` |
| Android Common 4.14.305 | `4415bf5e08942aee6487946a3e0a50956ef68f1e` |
| Authentic Common merge | `b92a77e96dd54fd30f8f39c7eef23e76f211c515` |
| Exact boot-tested source | `53f76796d1b68260507a83968a4a4bee3b89754f` |
| External-module source | `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798` |
| Boot-tested release | `4.14.305-miru-h40-lts305-bootfix-ci1+` |
| Final public release | `4.14.305-miru-h40-lts305-ci1+` |
| Semantic conflicts | `33` initial / `33` resolved / `0` remaining |
| Proven full build | PASS — run `30701388376` |
| Clean final-identity build | PASS — run `30718744153` |
| Three-way audit | PASS — run `30714292944` |
| Module result | 13 in-tree + 32 external; ABI/MODVERSIONS errors `0` |
| Device validation | PASS — final `4.14.305-miru-h40-lts305-ci1+` package fully working on the OnePlus 7 Pro |
| Production merge | Pending explicit authorization |

### Completed evidence

- Android Common 4.14.305 is a literal ancestor; all 2,777 commits in the 4.14.269→4.14.305 range and all 36 stable endpoint merges are present.
- The authentic integration merge preserves parent order: Miru preparation first, Android Common target second.
- All 33 authentic conflicts have explicit semantic ownership and zero remain.
- The final source retains the RNG early-boot guard, extcon notifier lifetime repair, ARM64 SMCCC callbacks, public FDT path with downstream DDR-type API, and Qualcomm early-random includes.
- Run `30701388376` built the kernel, exact five production DTBs, 13 in-tree modules, and 32 external modules with matching vermagic and zero binary ABI/MODVERSIONS errors.
- Run `30714292944` found zero missing Common commits, zero unexpected Common-only kernel-source mismatches, and zero missing H.40 vendor paths or config symbols.
- Clean final-identity run `30718744153` passed source-equivalence, exact DTB, in-tree and external module, vermagic, MODVERSIONS and ABI gates. Its artifacts are `8824429036` (full validation) and `8824428231` (release candidate).
- Exact source `53f76796d1b68260507a83968a4a4bee3b89754f` passed physical boot. Runtime source on the clean release branch remains byte-identical to that source.
- The maintainer completed the final `4.14.305-miru-h40-lts305-ci1+` package smoke test on the OnePlus 7 Pro: complete boot, Wi-Fi, cellular signal/data, maximum-volume audio, NFC, 90 Hz, fingerprint/HBM, AOD, charging, USB/ADB, suspend/wake and reboot all passed.

### Remaining promotion gate

- Wait for the maintainer's explicit authorization to merge PR #86.
- After authorization, merge the pinned release head into `miru-h40` with a normal merge commit only—never squash, rebase or force-push.
- Validate the actual production merge and finalize its documentation. No GitHub Release or new tag is created in this promotion.

See the 4.14.305 [validation record](miru/lts-4.14.305-validation.md), [conflict ledger](miru/lts-4.14.305-conflicts.md), [boot-regression record](miru/lts-4.14.305-boot-regression.md), and [user-facing changelog](miru/lts-4.14.305-changelog.md).

## Milestone 4: Linux 4.14.269

Status: **completed, merged into production, CI-validated, and device-confirmed on 2026-07-26 and 2026-07-27**.

This milestone advances the tested Miru H.40 line from Android stable 4.14.241 to 4.14.269 while preserving the Qualcomm/Oplus hardware architecture, ColorOS ABI, and established device compatibility work.

| Item | Revision |
|---|---|
| Miru production integration base | `4394ccbfa3805ce392b65b3ea148ff1eb084a974` |
| Android stable parent / target | `a446f52a5d3fc71698a073d08ce1eeb923727b42` → `0eec6f6001d15bb1108835a642ec4637d75eef19` |
| Exact device-tested LTS source | `14d41d8a57b1e08aa15ff786973b855c78f58fd7` |
| 4.14.269 production merge | `eb1cc39f93fb080c9903ffdba48f432ab0ac2b7b` (PR #68) |
| KCAL source / production merge | `5c21d9d15ac7228837f9cb63de3061bb6b383a5d` → `c8107343ced9e589447aa29f8c025425bd148b0a` (PR #69) |
| Kernel release | `4.14.269-miru-h40-lts269-14d41d8-ci3+` |
| Initial semantic conflicts | `22` |
| Resolved semantic conflicts | `22` |
| Remaining semantic conflicts | `0` |
| Full LTS build | PASS — run `30197447946` |
| KCAL build | PASS — run `30204348781` |
| Module result | 32 modules; ABI-report errors `0` in both validation runs |
| Device validation | PASS — ci3 flashed, booted, and worked on the OnePlus 7 Pro; maintainer reconfirmed on 2026-07-27. KCAL was confirmed working before PR #69 merge. |

### Completed validation and release decision

- The normal two-parent Android stable merge is preserved in production. The completed 4.14.269 integration and helper branches were deleted after promotion; their audit record remains in the merge history and permanent documentation.
- All 22 authentic semantic conflicts were resolved and recorded in `Documentation/miru/lts-4.14.269-conflicts.md`.
- The final LTS build from `14d41d8a57b1e08aa15ff786973b855c78f58fd7` succeeded, with 32 matching external modules and zero ABI-report errors.
- The real device booted and operated normally using `4.14.269-miru-h40-lts269-14d41d8-ci3+`.
- PR #69 added KCAL RGB display calibration after the LTS merge. Its exact PR source was built successfully with the same 32-module and zero-ABI-error checks, then device-confirmed by the maintainer before normal merge.
- The ci3 release suffix is intentionally static. The LTS and KCAL validation artifacts are distinguished by their exact source commits and artifact IDs, not by the release string alone.
- The permanent workflow contains the production 4.14.269 validation logic only. Documentation/merge commits use `[skip ci]` because the validated source has already completed its dedicated compilation run.

See the 4.14.269 [validation summary](miru/lts-4.14.269-validation.md), [conflict ledger](miru/lts-4.14.269-conflicts.md), and [user-facing changelog](miru/lts-4.14.269-changelog.md) for the full record.

## Milestone 3: Linux 4.14.241

Status: **completed, merged into production, CI-validated, and device-confirmed on 2026-07-26**.

This milestone advances the tested Miru H.40 line from Android stable 4.14.210 to
4.14.241 while preserving the Qualcomm/Oplus hardware architecture, ColorOS ABI,
and established device compatibility work.

| Item | Revision |
|---|---|
| Miru production integration base | `cc49ffcb5c5207746618a799b250c67decdc0d15` |
| Android stable parent / target | `39a7f9a39c0bd6d0f67869df227f6fa23286edd2` → `a446f52a5d3fc71698a073d08ce1eeb923727b42` |
| QRTR correction | `47f4767bd9040d574664d5b93abe3a54b97aa4e2` |
| GLINK error-propagation restoration | `935b66cf9ef5bcbd40063e830935744b35a3d5cf` |
| Final integration head | `0f419ca269b112a1fbf6cac188b6349cbc1a38ce` |
| Production merge | `4394ccbfa3805ce392b65b3ea148ff1eb084a974` |
| Kernel release | `4.14.241-miru-h40-lts241-ci7+` |
| Initial semantic conflicts | `32` |
| Resolved semantic conflicts | `32` |
| Remaining semantic conflicts | `0` |
| Pull-request workflow | PASS — run `30026823981` |
| Production workflow | PASS — run `30029365944` |
| Device validation | PASS — `ci6` booted; final `ci7` subsequently confirmed fully working on the OnePlus 7 Pro |

### Completed validation

- All 32 authentic semantic conflicts were resolved and retained in
  `Documentation/miru/lts-4.14.241-conflicts.md`.
- The dma-buf ownership/list lifetime correction was retained.
- The QRTR correction removed the erroneous second allocation while preserving
  the downstream fragment and backup-SKB lifetime model.
- The unsupported GLINK `-ENOENT → 0` workaround was removed; normal RX error
  propagation and the LineageOS-backed missing-channel FIFO advance remain.
- The permanent production workflow built the kernel and exactly 32 matching
  external modules from the pinned vendor source, with zero ABI-report errors.
- The production artifact release/vermagic is
  `4.14.241-miru-h40-lts241-ci7+ SMP preempt mod_unload modversions aarch64`.
- The earlier `ci6` source booted successfully on the OnePlus 7 Pro, and the
  maintainer subsequently confirmed the final `ci7` kernel fully working on
  the device.
- The merged 4.14.241 integration branch was retired after promotion; permanent
  ledgers, validation records, changelog, CI artifacts, and merge history remain.

See the 4.14.241 [validation summary](miru/lts-4.14.241-validation.md),
[conflict ledger](miru/lts-4.14.241-conflicts.md), and
[user-facing changelog](miru/lts-4.14.241-changelog.md) for the full record.

## Milestone 2: Linux 4.14.210

Status: **completed, device-validated and merged into production on 2026-07-21**.

This milestone advances the tested Miru H.40 line from Android stable 4.14.190 to 4.14.210 while preserving the Qualcomm/Oplus hardware architecture, ColorOS ABI and all validated post-4.14.190 compatibility work.

| Item | Revision |
|---|---|
| Miru production integration base | `40a2cb6fcf0411c100a7aaa609e128705a0bc2d8` |
| Existing 4.14.190 milestone merge | `a48222c3baa9c73943821da6b841d5a533a62fb1` |
| Android stable 4.14.210 parent | `39a7f9a39c0bd6d0f67869df227f6fa23286edd2` |
| Initial authentic merge scaffold | `33168a42f34f630ebeb87d90c250a53cac262b39` |
| Device-tested source head | `548efae59678abf8d9c1711df2a688a17a364f81` |
| Final pull-request head | `b265cd1f4f77b0cfe117d46adb7d18ac90821da2` |
| Production merge | `f78e220d9b5b49fb309b25877f6f423e5eb4f55e` |
| Production branch | `miru-h40` |
| Kernel release | `4.14.210-miru-h40-lts210-ci1+` |
| Initial semantic conflicts | `19` |
| Resolved semantic conflicts | `19` |
| Remaining semantic conflicts | `0` |
| Integration build | PASS — temporary 4.14.210 workflow run #4 |
| Final pull-request build | PASS — production workflow run #8 (`29792358348`) |
| Device validation | PASS — OnePlus 7 Pro, 2026-07-20 |

The Android stable parent carries Android/Linux changes from 4.14.191 through 4.14.210. The authentic two-parent merge ancestry is preserved rather than flattened. Every semantic conflict has an owning resolution commit and a detailed record in `Documentation/miru/lts-4.14.210-conflicts.md`.

### Preserved runtime-critical work

- DT2W kernel and vendor companion compatibility.
- H.40 smart-PA compatibility and maximum-volume audio behavior.
- H.40 AOD luminance programming and AOD-HBM backlight filtering.
- Fingerprint HBM and panel brightness behavior.
- Qualcomm WLAN and audio external-module interfaces.
- F2FS, fscrypt, IncFS, UFS, MMC and inline-encryption behavior.
- QRTR, modem IPC and downstream networking extensions.

### Completed validation

- Global conflict-marker, unmerged-index and `git diff --check` scans passed.
- All 19 authentic semantic conflicts were resolved and recorded.
- Kernel and five production DTBs built successfully.
- Configured in-tree modules built successfully.
- All 32 Miru v3 external modules were rebuilt against the final 4.14.210 tree.
- External-module filename, dependency, vermagic, imported-symbol and MODVERSIONS CRC audits passed.
- The production pull-request workflow passed as run #8 (`29792358348`).
- The build produced from `fix: use shared block sector size in dm-bow` (`548efae59678abf8d9c1711df2a688a17a364f81`) booted successfully on the OnePlus 7 Pro.
- All Miru v3 modules loaded and normal device functionality was confirmed working.
- All commits after the tested source head changed only CI or documentation, leaving the validated runtime kernel source unchanged.
- Pull request #24 was merged with a merge commit into the permanent `miru-h40` production branch.

The milestone was promoted to production as `f78e220d9b5b49fb309b25877f6f423e5eb4f55e`. Remaining repository housekeeping consists only of release tagging, optional branch-protection settings and deletion of obsolete temporary branch refs.

## Milestone 1: Linux 4.14.190

Status: **completed and device-validated on 2026-07-19**.

The milestone advanced the tested Miru H.40 line from 4.14.180 to Android stable 4.14.190 while preserving the Qualcomm/Oplus hardware architecture and ColorOS ABI.

| Item | Revision |
|---|---|
| Miru base | `h40-miru-module-compat-test@59858c8f798778f4e6c1c4449baba631e353600e` |
| Official H.40 base | `180d787684d5965be5145bcfbf666ed427b4ea18` |
| Android stable parent | `d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac` |
| Validated kernel source head | `c25ef04cb498fb9b23393aa7ee10a50359258fb8` |
| Final cleanup head | `6fca0a481f79fc5737bbea218e2bb6033a846261` |
| Production merge | `a48222c3baa9c73943821da6b841d5a533a62fb1` |
| Kernel release | `4.14.190-miru-h40-lts190-ci1+` |

### Completed validation

- Global conflict-marker, unmerged-index and `git diff --check` scans passed.
- All 28 merge conflicts were resolved and recorded in the conflict ledger.
- Kernel, five production DTBs and 13 configured in-tree modules built successfully.
- All 32 H.40 external modules were rebuilt for 4.14.190.
- Final vermagic: `4.14.190-miru-h40-lts190-ci1+ SMP preempt mod_unload modversions aarch64`.
- External-module filename, dependency, vermagic, imported-symbol and CRC audits passed.
- Clean pre-merge Actions run #3 and post-merge production run #4 completed successfully.
- The phone booted successfully with the resulting kernel and Miru v3 drop-in modules.
- All modules loaded; WLAN and audio were confirmed working.

The milestone was merged into `miru-h40` as `a48222c3baa9c73943821da6b841d5a533a62fb1`.

## Integration policy

1. Preserve H.40 Qualcomm/Oplus hardware behavior and the ColorOS ABI.
2. Preserve tested Miru runtime compatibility fixes.
3. Review every conflict explicitly; never use a global `ours` or `theirs` resolution.
4. Keep `CONFIG_MODVERSIONS=y` and never bypass symbol CRC failures.
5. Rebuild WLAN and audio modules against the final tree, configuration and `Module.symvers`.
6. Validate through clean GitHub Actions and on the device before release.
7. Use short-lived integration branches, retain permanent ledgers, and keep `miru-h40` as the stable default branch.
