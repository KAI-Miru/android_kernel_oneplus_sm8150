# Miru H.40 kernel for OnePlus 7 Pro

Miru H.40 is a maintained kernel line for the OnePlus 7 Pro (guacamole), based on the official OnePlus GM1911_11_H.40 Android 12 source and updated through Android/Linux stable 4.14.269.

## Current production build

| Item | Value |
|---|---|
| Kernel line | Linux 4.14.269 |
| Production branch | miru-h40 |
| 4.14.269 production merge | eb1cc39f93fb080c9903ffdba48f432ab0ac2b7b (PR #68) |
| KCAL production merge | c8107343ced9e589447aa29f8c025425bd148b0a (PR #69) |
| Target | OnePlus 7 Pro / SM8150 |
| Userspace | ColorOS 14 port with H.40 vendor and ODM |
| Integration status | Android stable 4.14.242–4.14.269 integrated; 22/22 semantic conflicts resolved |
| Validated LTS source | 14d41d8a57b1e08aa15ff786973b855c78f58fd7 |
| Validated kernel release | 4.14.269-miru-h40-lts269-14d41d8-ci3+ |
| Kernel and module CI | PASS — run 30197447946: kernel, 32 modules, ABI errors 0, checksums, and artifacts |
| KCAL CI | PASS — run 30204348781: kernel, 32 modules, ABI errors 0, checksums, and artifacts |
| Device validation | PASS — ci3 booted and worked on the OnePlus 7 Pro; confirmed again by the maintainer on 2026-07-27. KCAL was also maintainer-confirmed working before PR #69 was merged. |
| Release status | 4.14.269 and KCAL are merged into the production branch. |

The 4.14.269 milestone preserves the H.40 Qualcomm/Oplus hardware architecture, ColorOS ABI, and existing Miru device compatibility work. Android stable history is retained as a normal merge rather than flattened.

### Release identity

The ci3 release string is intentionally pinned by the reproducible build configuration. It identifies the exact LTS validation artifact built from 14d41d8a57b1e08aa15ff786973b855c78f58fd7. The later KCAL source head 5c21d9d15ac7228837f9cb63de3061bb6b383a5d was separately built and validated in run 30204348781 but deliberately keeps that same release string. Use the source commit and artifact ID, not the release string alone, when distinguishing those two validated builds.

## Build and validation

GitHub Actions uses the permanent [production workflow](.github/workflows/miru-h40-build.yml). It verifies 4.14.269 ancestry, conflict-ledger state, QRTR and GLINK safety gates, builds the kernel and DTBs, rebuilds exactly 32 external modules, verifies module release/vermagic and symbol CRC compatibility, and publishes kernel, module, diagnostic, and checksum artifacts.

The exact 4.14.269 LTS validation run was [30197447946](https://github.com/KAI-Miru/android_kernel_oneplus_sm8150/actions/runs/30197447946). It built 4.14.269-miru-h40-lts269-14d41d8-ci3+, produced 32 matching modules, and reported zero ABI errors. KCAL was validated separately by [30204348781](https://github.com/KAI-Miru/android_kernel_oneplus_sm8150/actions/runs/30204348781) from its exact PR head before the normal production merge. The merge commits intentionally use [skip ci] to avoid duplicate compilation after their already successful validation runs.

## Source references

- Main H.40 source: OnePlusOSS/android_kernel_oneplus_sm8150@180d787684d5965be5145bcfbf666ed427b4ea18
- 4.14.241 production parent: 4394ccbfa3805ce392b65b3ea148ff1eb084a974
- Android 4.14.269 stable target: 0eec6f6001d15bb1108835a642ec4637d75eef19
- Device-tested 4.14.269 LTS source: 14d41d8a57b1e08aa15ff786973b855c78f58fd7
- 4.14.269 production merge: eb1cc39f93fb080c9903ffdba48f432ab0ac2b7b
- KCAL source: 5c21d9d15ac7228837f9cb63de3061bb6b383a5d
- KCAL production merge: c8107343ced9e589447aa29f8c025425bd148b0a
- Companion vendor/module source: KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150@125ff7d0153cbb3aaa8f9fd618c33b7f728d7798

## Documentation

- [LTS milestone history](Documentation/miru-lts-integration.md)
- [4.14.269 production validation summary](Documentation/miru/lts-4.14.269-validation.md)
- [4.14.269 conflict and resolution ledger](Documentation/miru/lts-4.14.269-conflicts.md)
- [4.14.269 user-facing changelog](Documentation/miru/lts-4.14.269-changelog.md)
- [Historical 4.14.241 release validation](Documentation/miru/lts-4.14.241-validation.md)
- [Historical 4.14.210 release validation](Documentation/miru/lts-4.14.210-validation.md)
- [Historical H.40 source reproducibility audit](Documentation/miru/h40-source-reproducibility-audit.md)

## Warning

This kernel is device- and vendor-specific. Keep a known-good boot image and a recovery path before flashing. Use a matching 4.14.269 ci3 external-module package from the same validated source/artifact set; do not mix it with 4.14.190, 4.14.210, 4.14.241, v2, or stock external modules.
