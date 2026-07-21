# Miru H.40 LTS integration

This document records production LTS milestones for the OnePlus 7 Pro Miru H.40 kernel. The permanent production branch is `miru-h40`; milestone integration branches are temporary and may be deleted after merge and tagging.

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
