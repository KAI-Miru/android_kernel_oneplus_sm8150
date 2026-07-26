# Miru H.40 kernel for OnePlus 7 Pro

Miru H.40 is a maintained kernel line for the OnePlus 7 Pro (`guacamole`), based on the official OnePlus GM1911_11_H.40 Android 12 source and updated through Android/Linux stable 4.14.241.

## Current production build

| Item | Value |
|---|---|
| Kernel release | `4.14.241-miru-h40-lts241-ci7+` |
| Production branch | `miru-h40` |
| Production 4.14.241 merge | `4394ccbfa3805ce392b65b3ea148ff1eb084a974` |
| Target | OnePlus 7 Pro / SM8150 |
| Userspace | ColorOS 14 port with H.40 vendor and ODM |
| External modules | 32 matching Miru v3 modules rebuilt against the final kernel tree |
| Integration status | Android stable 4.14.211–4.14.241 integrated; 32/32 semantic conflicts resolved |
| Production CI | PASS — kernel, 32 modules, ABI report, checksums, and artifact uploads in [run 30029365944](https://github.com/KAI-Miru/android_kernel_oneplus_sm8150/actions/runs/30029365944) |
| Device validation | PASS — `ci6` booted on a OnePlus 7 Pro; the final `ci7` kernel was subsequently confirmed fully working by the maintainer |
| Release status | Production milestone merged into `miru-h40` |

The 4.14.241 milestone preserves the H.40 Qualcomm/Oplus hardware architecture and the existing Miru DT2W, smart-PA, display, fingerprint, AOD and NFC compatibility work. Android stable history is retained rather than flattened.

The only commit after the production merge is documentation-only confirmation of the final `ci7` device result; the production runtime kernel source remains the validated 4.14.241 tree.

## Build and validation

Kernel, DTBs and external modules are built by [GitHub Actions](.github/workflows/miru-h40-build.yml). The permanent workflow validates 4.14.241 ancestry and source hygiene, checks the QRTR and GLINK fixes, builds the kernel, rebuilds exactly 32 external modules, verifies release/vermagic and symbol CRC compatibility, and publishes kernel, module, diagnostic, and checksum artifacts.

The actual production workflow [run 30029365944](https://github.com/KAI-Miru/android_kernel_oneplus_sm8150/actions/runs/30029365944) passed on merge commit `4394ccbfa3805ce392b65b3ea148ff1eb084a974`. It built release `4.14.241-miru-h40-lts241-ci7+`, reported 32 modules and zero ABI errors, and uploaded the matching package and diagnostics.

## Source references

- Main H.40 source: `OnePlusOSS/android_kernel_oneplus_sm8150@180d787684d5965be5145bcfbf666ed427b4ea18`
- Miru 4.14.241 production base: `cc49ffcb5c5207746618a799b250c67decdc0d15`
- Android 4.14.241 stable target: `a446f52a5d3fc71698a073d08ce1eeb923727b42`
- QRTR lifetime correction: `47f4767bd9040d574664d5b93abe3a54b97aa4e2`
- GLINK error-propagation restoration: `935b66cf9ef5bcbd40063e830935744b35a3d5cf`
- Production merge: `4394ccbfa3805ce392b65b3ea148ff1eb084a974`
- Companion vendor/module source: `KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150@125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`

## Documentation

- [LTS milestone history](Documentation/miru-lts-integration.md)
- [4.14.241 release validation summary](Documentation/miru/lts-4.14.241-validation.md)
- [4.14.241 conflict and resolution ledger](Documentation/miru/lts-4.14.241-conflicts.md)
- [4.14.241 user-facing changelog](Documentation/miru/lts-4.14.241-changelog.md)
- [Historical 4.14.210 release validation](Documentation/miru/lts-4.14.210-validation.md)
- [Historical H.40 source reproducibility audit](Documentation/miru/h40-source-reproducibility-audit.md)

## Warning

This kernel is device- and vendor-specific. Keep a known-good boot image and a recovery path before flashing. Use the matching 4.14.241 `ci7` external-module package; do not mix it with 4.14.190, 4.14.210, v2, or stock external modules.
