# Miru H.40 LTS integration

## Milestone 1: Linux 4.14.190

This branch starts from the tested Miru H.40 compatibility tip:

- Base branch: `h40-miru-module-compat-test`
- Base commit: `59858c8f798778f4e6c1c4449baba631e353600e`
- Initial kernel version: `4.14.180`
- Target kernel version: `4.14.190`

The update source is the Android 4.14 stable tip used by the Qualcomm msm-4.14 integration:

- Repository: `LineageOS/android_kernel_oneplus_sm8150`
- Android stable tip: `d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac`
- Commit subject: `Merge 4.14.190 into android-4.14-stable`

Using the Android stable tip is intentional. It carries the Linux 4.14.181 through 4.14.190 stable series together with Android-specific compatibility fixes expected by an Android/Qualcomm 4.14 kernel.

## Integration policy

1. Preserve the H.40 Qualcomm/Oplus hardware architecture and ColorOS ABI.
2. Preserve all tested Miru fixes, including display timing, fingerprint/AOD behavior and NFC legacy compatibility.
3. Do not resolve conflicts with global `ours` or `theirs` strategies.
4. Review every conflict against both H.40 behavior and Qualcomm's historical merge resolution.
5. Keep `CONFIG_MODVERSIONS` enabled. Never bypass symbol CRC or `module_layout` failures.
6. Rebuild external WLAN and audio modules against the final tree, configuration and `Module.symvers` before device testing.
7. Do not merge this milestone into the known-good H.40 branch until build and hardware validation are complete.

## Status values

Each conflicting or deliberately skipped change must be recorded as one of:

- `APPLIED_CLEANLY`
- `MANUALLY_ADAPTED`
- `ALREADY_PRESENT`
- `NOT_APPLICABLE`
- `DEFERRED`
- `REJECTED_WITH_REASON`

## Validation gates

The milestone is not complete until all of the following pass:

- Kernel and DTB build
- External module build with no unresolved or CRC-mismatched symbols
- Boot to Android
- WLAN and complete ALSA/audio initialization
- 60/90 Hz switching
- AOD and fingerprint HBM
- Double-tap-to-wake
- NFC
- Pop-up camera motor
- Charging and offline charging
- Suspend/resume and overnight idle test

## Current state

The integration branch and merge-probe workflow are being prepared. No upstream source changes have been accepted yet.