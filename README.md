# Miru H.40 kernel for OnePlus 7 Pro

Miru H.40 is a maintained kernel line for the OnePlus 7 Pro (`guacamole`), based on the official OnePlus GM1911_11_H.40 Android 12 source. **OpenELA Linux 4.14.357 is the current production Miru H.40 release.** It preserves the original H.40/Oplus ancestry, genuine upstream merge topology, KCAL support, and the exact kernel/module combination validated on the device.

## OpenELA Linux 4.14.357 production release

| Item | Value |
|---|---|
| Target production kernel | OpenELA Linux 4.14.357 |
| Previous production release | Linux 4.14.336, promoted by `253775be7028de96f41ffcf3c5903573ff0b5fb8` |
| Validated Stage 357 source | Genuine merge `24626c96027f0bfc4431741ee0d249826a286293` |
| Exact OpenELA second parent | `1e6347375d088ecc896aabb067131d0f9e3c0575` |
| Production promotion merge | `50313dfbd4e8c369a04d6400c140c23909267021` (PR #88) |
| Final public release identity | `4.14.357-openela-miru-ci1+` |
| Final candidate build | PASS — run `30996359788`, job `92274276122` |
| Kernel output | Raw `Image.gz-dtb`, 19,101,303 bytes; not a packaged boot image |
| Compiler | `clang-r377782c` at `252aba16f513a857bc923172f67b0e55e23de35f` |
| External-module base | `3216c08bb3f97f865eb055296ea8034e1744caef` |
| External-module production repair | `c03a4c6339b959f1a9b288a157d5b5d16fbcf015` |
| External modules | 32 modules; ABI errors = 0 |
| Trace cleanup | 0 compiled `trace_printk` format entries |
| Device validation | PASS — maintainer confirmed normal operation on OnePlus 7 Pro |
| KCAL | Retained |

## Validation and build policy

The dedicated 4.14.357 integration/final-candidate workflows and the older 4.14.336 production workflow were retired after promotion. They are intentionally not repurposed: a future LTS milestone must add its own versioned, provenance-checked build workflow rather than generating a misleading 4.14.336 artifact.

The final 4.14.357 artifact verifies the exact source topology, kernel release and banner, compiler identity, matching external-module provenance, 32-module ABI compatibility, and zero compiled `trace_printk` entries. The downstream trace cleanup prevents the spurious DEBUG-kernel warning and avoids preallocating the tracing buffer that it caused.

## Source references

- Permanent production branch: `miru-h40`
- 4.14.357 production merge: `50313dfbd4e8c369a04d6400c140c23909267021` (PR #88)
- Validated Stage 357 source merge: `24626c96027f0bfc4431741ee0d249826a286293`
- Exact OpenELA 4.14.357 parent: `1e6347375d088ecc896aabb067131d0f9e3c0575`
- Pristine OnePlus H.40 source: `180d787684d5965be5145bcfbf666ed427b4ea18`
- Matching external-module base: `3216c08bb3f97f865eb055296ea8034e1744caef`
- Production external-module repair: `c03a4c6339b959f1a9b288a157d5b5d16fbcf015`

## Documentation

- [LTS milestone history](Documentation/miru-lts-integration.md)
- [4.14.357 conflict and semantic-resolution ledger](Documentation/miru/lts-4.14.357-conflicts.md)
- [4.14.357 validation record](Documentation/miru/lts-4.14.357-validation.md)
- [4.14.357 user-facing changelog](Documentation/miru/lts-4.14.357-changelog.md)
- [Historical 4.14.336 conflict ledger](Documentation/miru/lts-4.14.336-conflicts.md)
- [Historical 4.14.336 validation record](Documentation/miru/lts-4.14.336-validation.md)
- [Historical 4.14.336 user-facing changelog](Documentation/miru/lts-4.14.336-changelog.md)
- [Historical 4.14.305 validation](Documentation/miru/lts-4.14.305-validation.md)
- [Historical 4.14.305 user-facing changelog](Documentation/miru/lts-4.14.305-changelog.md)
- [Historical 4.14.269 validation](Documentation/miru/lts-4.14.269-validation.md)

## Warning

This kernel is device- and vendor-specific. Keep a known-good boot image and recovery path before flashing. Linux 4.14.357 requires matching 4.14.357 modules from the same validated artifact set. Do not mix it with 4.14.336, 4.14.305, 4.14.269, older Miru, stock, or other external-module packages.
