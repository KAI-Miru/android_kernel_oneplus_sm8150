# Miru H.40 Linux 4.14.305 validation record

## Status

- Exact boot-tested source: `53f76796d1b68260507a83968a4a4bee3b89754f`
- Boot-tested release: `4.14.305-miru-h40-lts305-bootfix-ci1+`
- Final public release identity: `4.14.305-miru-h40-lts305-ci1+`
- Full kernel and module build: **PASS** — run `30701388376`
- Three-way provenance audit: **PASS** — run `30714292944`
- Physical boot on OnePlus 7 Pro: **PASS**
- Clean final-identity release-candidate build: **PASS** — run `30718744153`
- Final full physical smoke test: **PASS** — maintainer confirmed all required checks on 2026-08-02
- Production merge: **pending explicit authorization**

The boot-tested package passed the first OnePlus splash, reached the second boot screen, and completed Android boot. The final public suffix removes `bootfix`; the separately built `4.14.305-miru-h40-lts305-ci1+` package then completed the full physical smoke test on the OnePlus 7 Pro with every required check passing.

## Exact identities and ancestry

| Role | Revision |
|---|---|
| Immutable 4.14.269 production base | `61371a1024e341f434deaf61b79a05f73827260a` |
| Permanent 4.14.269 rollback tag | `miru-h40-4.14.269-final` |
| Pristine OnePlus H.40 | `180d787684d5965be5145bcfbf666ed427b4ea18` |
| Android Common 4.14.305 | `4415bf5e08942aee6487946a3e0a50956ef68f1e` |
| Android Common target tree | `b13cdb6b1f31e75df2d2dddeed15b04dceeed939` |
| Official Common tag object | `fb7d1aa1e00554d9ac07b2a6267f58e585569b81` |
| Authentic integration merge | `b92a77e96dd54fd30f8f39c7eef23e76f211c515` |
| Authentic merge parent 1 | `b125a425ef1559871b1d6cd662806c8afc53e934` |
| Authentic merge parent 2 | `4415bf5e08942aee6487946a3e0a50956ef68f1e` |
| Exact boot-tested kernel source | `53f76796d1b68260507a83968a4a4bee3b89754f` |
| Matching external-module source | `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798` |
| Clean final release-candidate head | `7a720172326aac69dccb3becdb2f75b8a7ee9c29` |

The production base, pristine H.40 commit, Android Common target, authentic two-parent integration merge, and exact boot-tested source are all retained in ancestry. The Common integration was not flattened or replaced by a synthetic snapshot.

## Authoritative successful build

- Actions run: `30701388376`
- Kernel source: `53f76796d1b68260507a83968a4a4bee3b89754f`
- External-module source: `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`
- Kernel release: `4.14.305-miru-h40-lts305-bootfix-ci1+`
- Vermagic: `4.14.305-miru-h40-lts305-bootfix-ci1+ SMP preempt mod_unload modversions aarch64`
- In-tree modules: `13/13`
- External modules: `32/32`
- In-tree MODVERSIONS errors: `0`
- External binary ABI/MODVERSIONS errors: `0`
- External vermagic: `32/32` correct
- In-tree vermagic: `13/13` correct

### Build artifacts

| Artifact | ID | Digest |
|---|---:|---|
| Full validation | `8819279714` | `sha256:1ddcd8603ddbbc9a3e1d29a7cb1a61b7e1b95864b15eb801e1c13ce52c061aa9` |
| Physical-test package | `8819278460` | `sha256:ad0f18ea4294cd44306244b255440581e868aa6902a5b5c0eef8ec367eb76260` |
| Three-way audit | `8822867561` | `sha256:fdbc6eed9b41ff9a18e601d8acac9cf41890a5158a57165bcffe39f2f5329205` |

## Clean final-identity release candidate

- Actions run: `30718744153`
- Release source: `7a720172326aac69dccb3becdb2f75b8a7ee9c29`
- Kernel release: `4.14.305-miru-h40-lts305-ci1+`
- Vermagic: `4.14.305-miru-h40-lts305-ci1+ SMP preempt mod_unload modversions aarch64`
- Runtime source equivalence: **PASS** against `53f76796d1b68260507a83968a4a4bee3b89754f`
- DTBs: exactly five in order `18821 19801 19863 18865 18857`
- In-tree modules: `13/13`; external modules: `32/32`; ABI/MODVERSIONS errors: `0`
- Final full-validation artifact: `8824429036` (`sha256:135f611b0b4a1e244cb2f98c09f2d46ca91335f067821f1115dda79984810ad5`)
- Final release-candidate artifact: `8824428231` (`sha256:239f0b95d845ebfb24008b4069f1c473e96c2ee242749bb368c2453913140660`)
- Final `Image.gz-dtb`: `ba4d7a598a094f46fb852f5d0e7c9d604eaa4b3a3e0dac506d64ef346f7033ad`

## Kernel and package SHA-256

| Output | SHA-256 |
|---|---|
| `Image` | `643a6397771669f10d14216fe27a65b93293f5677375224e64d10a8e6e961370` |
| `Image.gz` | `1c1ac2b027de30f926f9ef87ae725c2e54ef2d4b80d19ed4b45f4122d302f517` |
| `Image.gz-dtb` | `341a54fcec8e33a896324c6e257642be6457f13e66df550d43f78631e436b50e` |
| `.config` | `1b5fb97cceb1e2d8d6814c2f5a1e9e545092eb8055ae5b0cb2062e7a1933e13d` |
| `System.map` | `dad4b8ef3aaa5fb06ecf132a9b5a774f343307b146a2a785c0eb2be1a8601d52` |
| `Module.symvers` | `7b1abc8ad578d17807cc83cdc0b8be4d74fa9e880df021426ef3b25d54546054` |
| 32-module drop-in package | `9610010817179a2ed5e14def42da26b19cdaf35652d46a51f1b40f46ad8c5dc5` |
| Module audit ZIP | `3756ed0a6057269d6310d99d88aae1e2c01b87fcd0dee62830788a374693b14e` |

These hashes identify the successful `bootfix-ci1+` build. The final `lts305-ci1+` release candidate subsequently published its own checksum manifest and is recorded above with its artifact digests and final `Image.gz-dtb` hash.

## DTB validation

Exactly five production DTBs were built and appended in this exact order:

1. `18821/sm8150-v2-mtp.dtb`
2. `19801/sm8150-v2-mtp.dtb`
3. `19863/sm8150-v2-mtp.dtb`
4. `18865/sm8150-v2-mtp.dtb`
5. `18857/sm8150-v2-mtp.dtb`

The generated `Image.gz-dtb` was byte-compared against `Image.gz` followed by those five DTBs. No production DTBO was generated by the kernel workflow.

## Three-way audit

Run `30714292944` compared pristine OnePlus H.40, booted Miru 4.14.305, and Android Common 4.14.305. Result: **PASS**.

- Common commits in 4.14.269→4.14.305 range: `2,777`
- Common commits missing from Miru ancestry: `0`
- Stable endpoint merges present: `36/36`
- Common paths changed: `2,104`
- Common-only paths: `1,816`
- Unexpected Common-only kernel-source mismatches: `0`
- Original H.40 downstream delta: `22,849` files
- Vendor-named paths checked/missing: `357/0`
- Vendor config symbols checked/missing: `74/0`
- Semantic conflicts: `33` initial, `33` resolved, `0` remaining

The only final Common-only difference is the required OnePlus early-boot guard in `drivers/char/random.c`. The absent `phy-qcom-ufs-qmp-20nm.c/.h` pair was already dead and absent before this integration; it is not used by SM8150 and is not classified as lost Oplus functionality.

## Known audio_max98937 warnings

The isolated `audio_max98937` MODPOST log contains pre-existing warnings for:

- `afe_dsm_set_status`
- `afe_dsm_set_calib`
- `afe_dsm_post_calib`
- `afe_dsm_rx_set_params`
- `afe_dsm_ramp_dn_cfg`
- `afe_dsm_pre_calib`
- `afe_dsm_rx_get_params`
- `afe_dsm_get_calib`

These warnings were already present in previous successful builds. They are not hidden or counted as a clean log. The final ELF-level audit still validated all 32 external modules and reported zero unresolved binary ABI/MODVERSIONS CRC errors.

## Completed final release-package smoke test

On 2026-08-02, the maintainer confirmed that the exact `4.14.305-miru-h40-lts305-ci1+` package passed the full OnePlus 7 Pro smoke test:

- Complete boot
- Wi-Fi
- Cellular signal and data
- Audio, including maximum volume
- NFC
- 90 Hz
- Fingerprint and HBM
- AOD
- Charging
- USB/ADB
- Suspend and wake
- Reboot

This closes all release-candidate technical and physical validation gates. Production `miru-h40` remains at `61371a1024e341f434deaf61b79a05f73827260a` until the maintainer gives separate explicit authorization for the required normal merge commit.