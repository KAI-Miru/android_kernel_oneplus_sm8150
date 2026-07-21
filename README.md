# Miru H.40 kernel for OnePlus 7 Pro

Miru H.40 is a maintained kernel line for the OnePlus 7 Pro (`guacamole`), based on the official OnePlus GM1911_11_H.40 Android 12 source and updated to Android/Linux stable 4.14.210.

## Current milestone candidate

| Item | Value |
|---|---|
| Kernel release | `4.14.210-miru-h40-lts210-ci1+` |
| Production branch | `miru-h40` |
| Integration branch | `miru-h40-lts210-integration` |
| Target | OnePlus 7 Pro / SM8150 |
| Userspace | ColorOS 14 port with H.40 vendor and ODM |
| External modules | 32-module Miru v3 drop-in set rebuilt against the final kernel tree |
| Integration status | Android stable 4.14.191-4.14.210 integrated; 19/19 semantic conflicts resolved |
| Release status | Production PR CI and final device validation required before release |

The 4.14.210 milestone preserves the H.40 Qualcomm/Oplus hardware architecture and the existing Miru DT2W, smart-PA, display, fingerprint, AOD and NFC compatibility work. The authentic Android-stable merge ancestry is retained rather than flattened.

## Build and validation

Kernel, DTBs and external modules are built by [GitHub Actions](.github/workflows/miru-h40-build.yml). The workflow performs source sanity checks, validates the 4.14.210 merge ancestry, builds the kernel and five production DTBs, rebuilds all 32 external modules against the final `Module.symvers`, verifies vermagic and symbol CRCs, and publishes installable and diagnostic artifacts.

The milestone must pass this workflow on the final pull request and again after promotion to `miru-h40`. Device validation must cover boot, module loading, WLAN, audio, DT2W, AOD brightness, fingerprint HBM and maximum-volume smart-PA behavior before the release is tagged.

## Source references

- Main H.40 source: `OnePlusOSS/android_kernel_oneplus_sm8150@180d787684d5965be5145bcfbf666ed427b4ea18`
- Miru 4.14.210 integration base: `40a2cb6fcf0411c100a7aaa609e128705a0bc2d8`
- Companion vendor/module source: `KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150@125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`
- Android 4.14.210 stable parent: `39a7f9a39c0bd6d0f67869df227f6fa23286edd2`

## Documentation

- [LTS milestone history and validation](Documentation/miru-lts-integration.md)
- [4.14.210 conflict and resolution ledger](Documentation/miru/lts-4.14.210-conflicts.md)
- [Historical 4.14.190 conflict ledger](Documentation/miru/lts-4.14.190-conflicts.md)
- [Historical H.40 source reproducibility audit](Documentation/miru/h40-source-reproducibility-audit.md)

## Warning

This kernel is device- and vendor-specific. Keep a known-good boot image and a recovery path before flashing. Do not mix the 4.14.210 kernel with 4.14.190, v2 or stock external modules.
