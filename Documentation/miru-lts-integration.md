# Miru H.40 LTS integration

## Milestone 1: Linux 4.14.190

Status: **completed and device-validated on 2026-07-19**.

The milestone advances the tested Miru H.40 line from 4.14.180 to Android stable 4.14.190 while preserving the Qualcomm/Oplus hardware architecture and ColorOS ABI.

| Item | Revision |
|---|---|
| Miru base | `h40-miru-module-compat-test@59858c8f798778f4e6c1c4449baba631e353600e` |
| Official H.40 base | `180d787684d5965be5145bcfbf666ed427b4ea18` |
| Android stable parent | `d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac` |
| Validated kernel source head | `c25ef04cb498fb9b23393aa7ee10a50359258fb8` |
| Final cleanup head | `6fca0a481f79fc5737bbea218e2bb6033a846261` |
| Production merge | `a48222c3baa9c73943821da6b841d5a533a62fb1` |
| Kernel release | `4.14.190-miru-h40-lts190-ci1+` |

The Android stable parent carries Linux 4.14.181 through 4.14.190 together with Android-specific compatibility changes expected by a Qualcomm Android 4.14 kernel.

## Integration policy

1. Preserve H.40 Qualcomm/Oplus hardware behavior and the ColorOS ABI.
2. Preserve the tested Miru display timing, fingerprint/AOD and NFC fixes.
3. Review every conflict explicitly; never use a global `ours` or `theirs` resolution.
4. Keep `CONFIG_MODVERSIONS=y` and never bypass symbol CRC failures.
5. Rebuild WLAN and audio modules against the final tree, configuration and `Module.symvers`.
6. Validate the result through clean GitHub Actions and on the device before merging.

## Completed validation

- Global conflict-marker, unmerged-index and `git diff --check` scan passed.
- All 28 merge conflicts were resolved and recorded in the conflict ledger.
- Kernel, five production DTBs and 13 configured in-tree modules built successfully.
- All 32 H.40 external modules were rebuilt for 4.14.190.
- Final vermagic: `4.14.190-miru-h40-lts190-ci1+ SMP preempt mod_unload modversions aarch64`.
- External module filename, dependency, vermagic, imported-symbol and CRC audits passed.
- Clean pre-merge Actions run #3 and post-merge production run #4 completed successfully.
- The phone booted successfully with the resulting kernel and Miru v3 drop-in modules.
- All modules loaded; WLAN and audio were confirmed working.

The milestone was merged into the permanent `miru-h40` production branch as `a48222c3baa9c73943821da6b841d5a533a62fb1`. Post-merge Actions run #4 passed the same kernel, DTB, external-module and artifact gates. Future maintenance updates should use short-lived LTS branches and the same Actions/device validation gates.
