# Miru H.40 kernel for OnePlus 7 Pro

Miru H.40 is a maintained kernel line for the OnePlus 7 Pro (`guacamole`), based on the official OnePlus GM1911_11_H.40 Android 12 source. Linux 4.14.336 is the production Miru H.40 line. It preserves the original H.40/Oplus ancestry, the authentic Android Common merge history, KCAL support, and the exact runtime source validated on the device.

## Linux 4.14.336 production release

| Item | Value |
|---|---|
| Target production kernel | Linux 4.14.336 |
| Previous production baseline | Linux 4.14.305 at `a97fcbe96ab6d8392a0a0acf91da46ccb37fdaee` |
| Production promotion merge | `253775be7028de96f41ffcf3c5903573ff0b5fb8` (PR #87 normal merge) |
| Final public release identity | `4.14.336-miru-h40-lts336-ci1+` |
| Expected vermagic | `4.14.336-miru-h40-lts336-ci1+ SMP preempt mod_unload modversions aarch64` |
| Android Common target | `014241ad77dda0eafbdf671d5b8e86917d8ec97e` |
| Authentic Common merge | `e0fc49a4660130692e6ac893f8119282b0192b85` |
| Pristine H.40 source | `180d787684d5965be5145bcfbf666ed427b4ea18` |
| External-module source | `3216c08bb3f97f865eb055296ea8034e1744caef` |
| Module set | 13 in-tree + 32 external |
| Semantic conflicts | 14 resolved / 0 remaining |
| Final release-candidate build | PASS — run `30854697145` |
| Device validation | PASS — maintainer confirmed full operation on the OnePlus 7 Pro on 2026-08-04 |
| Permanent production validation | PASS — run `30875788887` |
| KCAL | Retained |
| Production merge | PASS — PR #87 normal merge `253775be7028de96f41ffcf3c5903573ff0b5fb8` |

The integration preserves the authentic two-parent Android Common merge: the Miru candidate parent is first and the exact Android Common 4.14.336 target is second. All 14 semantic conflicts were explicitly resolved; the final candidate differs from that authentic merge only in the permanent release workflow and the device-tested Qualcomm DWC3 USB repairs.

## Build and validation

The permanent workflow is [`.github/workflows/miru-h40-build.yml`](.github/workflows/miru-h40-build.yml). It proves source and merge ancestry, validates the DWC3 semantics and external module source, builds the kernel and exact five production DTBs, rebuilds 13 in-tree and 32 external modules, checks vermagic/MODVERSIONS/ABI compatibility, and publishes diagnostics and package checksums.

The clean final `4.14.336-miru-h40-lts336-ci1+` release candidate passed in Actions run `30854697145`. Its full-validation artifact is `8872541554` (`sha256:bd3d3d74135383d3a4c8d48e47484acc5305b793a9188f33c03486349be1cb4b`) and its release-candidate artifact is `8872541095` (`sha256:a7f00718f1a02990ff377d0a8e1c921c44108f777852afd322b6ad105507670f`).

PR #87 was then merged normally as `253775be7028de96f41ffcf3c5903573ff0b5fb8`. The permanent gate was corrected in workflow-only commit `079c3a491e0260bbc795b8a7c2a074c2f40ac355` to validate the resulting production maintenance commit without weakening the original merge checks. Production run `30875788887` passed; its full-validation artifact is `8879975156` (`sha256:0cef6d7cfa450de843ef933ede4240daededd26fa402f2449297dd1698b77bd1`) and its package artifact is `8879974890` (`sha256:7fda33f4d6ed7c04899e3922ebed262ab476eb91d52c90706cc6797af73fa04e`).

## Source references

- Permanent production branch: `miru-h40`
- Production 4.14.336 merge: `253775be7028de96f41ffcf3c5903573ff0b5fb8` (PR #87 normal merge)
- Permanent production validation head: `079c3a491e0260bbc795b8a7c2a074c2f40ac355`
- 4.14.269 rollback tag: `miru-h40-4.14.269-final`
- Android Common 4.14.336 target: `014241ad77dda0eafbdf671d5b8e86917d8ec97e`
- Authentic Android Common integration merge: `e0fc49a4660130692e6ac893f8119282b0192b85`
- Pristine OnePlus H.40 source: `180d787684d5965be5145bcfbf666ed427b4ea18`
- Matching external-module source: `3216c08bb3f97f865eb055296ea8034e1744caef`

## Documentation

- [LTS milestone history](Documentation/miru-lts-integration.md)
- [4.14.336 conflict and semantic-resolution ledger](Documentation/miru/lts-4.14.336-conflicts.md)
- [4.14.336 validation record](Documentation/miru/lts-4.14.336-validation.md)
- [4.14.336 user-facing changelog](Documentation/miru/lts-4.14.336-changelog.md)
- [Historical 4.14.305 validation](Documentation/miru/lts-4.14.305-validation.md)
- [Historical 4.14.305 user-facing changelog](Documentation/miru/lts-4.14.305-changelog.md)
- [Historical 4.14.269 validation](Documentation/miru/lts-4.14.269-validation.md)

## Warning

This kernel is device- and vendor-specific. Keep a known-good boot image and recovery path before flashing. Linux 4.14.336 requires matching 4.14.336 modules from the same validated artifact set. Do not mix it with 4.14.305, 4.14.269, older Miru, stock, or other external-module packages.
