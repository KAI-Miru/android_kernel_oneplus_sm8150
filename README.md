# Miru H.40 kernel for OnePlus 7 Pro

Miru H.40 is a maintained kernel line for the OnePlus 7 Pro (`guacamole`), based on the official OnePlus GM1911_11_H.40 Android 12 source and updated to Android/Linux stable 4.14.190.

## Current tested build

| Item | Value |
|---|---|
| Kernel release | `4.14.190-miru-h40-lts190-ci1+` |
| Production branch | `miru-h40` |
| Target | OnePlus 7 Pro / SM8150 |
| Userspace | ColorOS 14 port with H.40 vendor and ODM |
| External modules | 32-module Miru v3 drop-in set |
| Device validation | Boots successfully; all v3 modules load; WLAN and audio work |

The 4.14.190 milestone preserves the H.40 Qualcomm/Oplus hardware architecture and the Miru display, fingerprint/AOD and NFC compatibility work. All 28 stable-merge conflicts were resolved explicitly.

## Build and validation

Kernel, DTBs and external modules are built by [GitHub Actions](.github/workflows/miru-h40-build.yml). The workflow performs the source sanity checks, builds the kernel and five production DTBs, rebuilds all 32 external modules against the final `Module.symvers`, verifies vermagic and symbol CRCs, and publishes installable and diagnostic artifacts.

The final pre-merge validation run was Actions run #48 at commit `c25ef04cb498fb9b23393aa7ee10a50359258fb8`.

## Source references

- Main H.40 source: `OnePlusOSS/android_kernel_oneplus_sm8150@180d787684d5965be5145bcfbf666ed427b4ea18`
- Companion vendor/module source: `OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8150@993439581252cf872cd3c184ed3eb9e0f286f4c3`
- Android 4.14.190 stable parent: `d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac`

## Documentation

- [4.14.190 integration record](Documentation/miru-lts-integration.md)
- [4.14.190 conflict ledger](Documentation/miru/lts-4.14.190-conflicts.md)
- [Historical H.40 source reproducibility audit](Documentation/miru/h40-source-reproducibility-audit.md)

## Warning

This kernel is device- and vendor-specific. Keep a known-good boot image and a recovery path before flashing. Do not mix the 4.14.190 kernel with older v2 or stock external modules.
