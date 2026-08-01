# Miru H.40 kernel for OnePlus 7 Pro

Miru H.40 is a maintained kernel line for the OnePlus 7 Pro (`guacamole`), based on the official OnePlus GM1911_11_H.40 Android 12 source. The clean Linux 4.14.305 release candidate preserves the original H.40/Oplus ancestry, Android Common ancestry, KCAL support, and the exact runtime source that completed Android boot on the device.

## Linux 4.14.305 release candidate

| Item | Value |
|---|---|
| Target production kernel | Linux 4.14.305 |
| Live production before promotion | Linux 4.14.269 at `61371a1024e341f434deaf61b79a05f73827260a` |
| Release branch | `miru-h40-lts305-release` |
| Exact boot-tested source ancestor | `53f76796d1b68260507a83968a4a4bee3b89754f` |
| Final public release identity | `4.14.305-miru-h40-lts305-ci1+` |
| Expected vermagic | `4.14.305-miru-h40-lts305-ci1+ SMP preempt mod_unload modversions aarch64` |
| Android Common 4.14.305 target | `4415bf5e08942aee6487946a3e0a50956ef68f1e` |
| Authentic Common merge | `b92a77e96dd54fd30f8f39c7eef23e76f211c515` |
| Pristine H.40 source | `180d787684d5965be5145bcfbf666ed427b4ea18` |
| External-module source | `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798` |
| Module set | 13 in-tree + 32 external |
| ABI/MODVERSIONS result | 0 errors |
| Three-way audit | PASS — run `30714292944` |
| Proven full build | PASS — run `30701388376` |
| Physical OnePlus 7 Pro boot | PASS — first splash passed, second boot screen reached, Android boot completed |
| KCAL | Retained |
| Production merge | Pending final release-candidate CI and physical smoke test |

The three-way audit compared pristine OnePlus H.40, booted Miru Linux 4.14.305, and Android Common Linux 4.14.305. It found all 2,777 Common commits in ancestry, all 36 stable endpoint merges, all 33 semantic conflicts resolved, zero remaining conflicts, zero unexpected Common-only kernel-source mismatches, and no missing H.40 vendor paths or config symbols.

## Build and validation

The permanent workflow is [`.github/workflows/miru-h40-build.yml`](.github/workflows/miru-h40-build.yml). It validates production, Android Common, pristine H.40, and boot-tested-source ancestry; proves runtime-source equivalence; checks the five mandatory compatibility areas; builds the kernel and exact five DTBs; rebuilds 13 in-tree and 32 external modules; verifies release, vermagic, symbol CRCs and MODVERSIONS; and publishes checksums, diagnostics, source-equivalence evidence, and a release-candidate package.

The exact boot-tested source was validated in Actions run `30701388376`. Its full-validation artifact is `8819279714` (`sha256:1ddcd8603ddbbc9a3e1d29a7cb1a61b7e1b95864b15eb801e1c13ce52c061aa9`) and its physical-test artifact is `8819278460` (`sha256:ad0f18ea4294cd44306244b255440581e868aa6902a5b5c0eef8ec367eb76260`). The authoritative three-way audit is run `30714292944`, artifact `8822867561` (`sha256:fdbc6eed9b41ff9a18e601d8acac9cf41890a5158a57165bcffe39f2f5329205`).

The clean `lts305-ci1+` release-candidate workflow run and final production merge are intentionally recorded as pending until they have actually passed and occurred. They will be added after validation rather than predicted here.

## Source references

- Permanent production branch: `miru-h40`
- 4.14.269 rollback tag: `miru-h40-4.14.269-final`
- Exact boot-tested 4.14.305 source: `53f76796d1b68260507a83968a4a4bee3b89754f`
- Android Common 4.14.305 target: `4415bf5e08942aee6487946a3e0a50956ef68f1e`
- Authentic Android Common integration merge: `b92a77e96dd54fd30f8f39c7eef23e76f211c515`
- Pristine OnePlus H.40 source: `180d787684d5965be5145bcfbf666ed427b4ea18`
- Matching external-module source: `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`

## Documentation

- [LTS milestone history](Documentation/miru-lts-integration.md)
- [4.14.305 conflict and semantic-resolution ledger](Documentation/miru/lts-4.14.305-conflicts.md)
- [4.14.305 validation record](Documentation/miru/lts-4.14.305-validation.md)
- [4.14.305 boot-regression investigation](Documentation/miru/lts-4.14.305-boot-regression.md)
- [4.14.305 user-facing changelog](Documentation/miru/lts-4.14.305-changelog.md)
- [Historical 4.14.269 validation](Documentation/miru/lts-4.14.269-validation.md)
- [Historical 4.14.241 validation](Documentation/miru/lts-4.14.241-validation.md)
- [Historical 4.14.210 validation](Documentation/miru/lts-4.14.210-validation.md)

## Warning

This kernel is device- and vendor-specific. Keep a known-good boot image and recovery path before flashing. Linux 4.14.305 requires the matching 4.14.305 module package from the same validated artifact set. Do not mix it with 4.14.269, 4.14.241, 4.14.210, 4.14.190, stock, or older Miru external modules.