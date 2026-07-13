# OnePlus 7 Pro GM1911_11_H.40 kernel reproducibility audit

## Result

The official H.40 kernel source compiles after one narrowly scoped Kconfig
compatibility repair. Two clean local builds were identical to one another,
but their raw kernel payload was **not** byte-for-byte identical to the kernel
extracted from the supplied H.40 `boot.img`.

The strongest supported verdict is:

> **D. Official source appears incomplete because specific shipped code has no
> published source.**

The concrete missing shipped inputs are the project 19861/18961 base and
overlay device-tree sources and the production RTIC MPGen input. The exact
Clang 10.0.7 binary and the Android DLKM packaging helper are also absent.
Nothing was flashed and no boot-compatibility claim is made.

## Exact official revisions

The repositories must be nested because checked-in relative symlinks depend on
the Android source-tree layout:

```text
android/                                      modules/vendor repository
  vendor/oplus/
  vendor/qcom/opensource/{audio-kernel,wlan}/
  kernel/msm-4.14/                            main kernel repository
```

| Repository | Branch | Audited commit |
|---|---|---|
| `OnePlusOSS/android_kernel_oneplus_sm8150` | `oneplus/sm8150_s_12.1_op7pro` | `180d787684d5965be5145bcfbf666ed427b4ea18` |
| `OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8150` | `oneplus/sm8150_s_12.1_op7pro` | `993439581252cf872cd3c184ed3eb9e0f286f4c3` |

The main commit subject is `Synchronize code for oneplus GM1911_11_H.40`.
The second repository's branch tip is labelled H.33, but is the exact current
tip of the official branch requested for this audit.

Both repositories were placed on a local branch named `h40-repro-build`.
No remote branch was changed or pushed.

## Supplied stock evidence

| Input | SHA-256 |
|---|---|
| `boot.img` | `991cf738f5a6dc874c6261fa073c89182e61935a9493dc27347699c4d0a68792` |
| `dtbo.img` | `2f6015b1f9fa9dafd5e7fbc61a297559741c6d33bb42cb2ccd7e6dbe0526c90c` |
| `KERNEL WORK(2).7z` | `0eba047adcd6c38a1d20d05f812c84f6170aeadd4f16bd8ef1b5f97da24341bb` |

The boot image has an Android v2 header, 4096-byte pages, a raw ARM64 kernel,
25 DTBs in its DTB field, and 15 recovery-DTBO entries. Its decompressed/raw
kernel payload is:

```text
size     40142864 bytes
SHA-256  78a2ec421a44e0b4c20d0132e25ce0e6d91b521929de0139cfff35e5c31f7b84
```

`h40-repro/extract-boot.py` independently extracts these components without
modifying the input. The IKCONFIG extracted from that raw Image is checked in
as `h40-repro/config/GM1911_11_H.40.config` and has SHA-256:

```text
676588ad9178c0f1e5252c854245d1d0901f78d0c7130acdc1b8a36727f9a684
```

After CRLF normalization, it is byte-identical to `stock.config` from the
runtime archive.

## Host and toolchain

The verified clean builds ran on Ubuntu 24.04.3 LTS, x86_64, Linux 6.12.47,
GNU bash 5.2.21, GNU Make 4.3, git 2.51.1 and host GCC 13.3.0.

The source uses the old Qualcomm/Android hybrid build arrangement: a Clang
frontend with `-no-integrated-as`, GNU cross assemblers/binutils, and GNU ld.
It is not an `LLVM=1 LLVM_IAS=1` build.

| Component | Exact tested input |
|---|---|
| Clang | AOSP `clang-r377782c`, repository commit `252aba16f513a857bc923172f67b0e55e23de35f`, Android Clang 10.0.5, binary SHA-256 `6618ecab73b79a70b79263d2f477f669e564d81ca802112d2e5f93c74c6b22ca` |
| AArch64 GCC/binutils | commit `606f80986096476912e04e5c2913685a8f2c3b65`; GNU ld 2.27.0.20170315, SHA-256 `2a663de4ce3d702fe3f2a0de48cac366be676f850c2f5732d9cc2e4acb9335e2` |
| ARM32 GCC/binutils | commit `b0c6a654327ca8796bed1e61dffcf523d04dceaa`; assembler SHA-256 `2f78058a8549bc5c099dbea16d9f3dc571e072b1ade906c3539e419787b502dd` |
| AOSP build-tools | commit `7322db1e1e4715fe217a27f721613e6be8438676`; Python 2.7.15+, `gavinhoward-bc` 2.6.1 and toybox 0.8.3-android |

The shipped banner reports `clang version 10.0.7 for Android NDK`, but does
not identify a revision. The exact public binary was not found. The tested
AOSP Clang is the closest official candidate located during the audit.

## Build command

Place the four toolchain checkouts at paths of your choice, then run from the
main kernel repository:

```bash
export CLANG_DIR=/absolute/path/to/clang-r377782c
export GCC64_DIR=/absolute/path/to/aarch64-linux-android-4.9
export GCC32_DIR=/absolute/path/to/arm-linux-androideabi-4.9
export AOSP_BUILD_TOOLS=/absolute/path/to/aosp-build-tools/linux-x86

export KBUILD_BUILD_USER=root
export KBUILD_BUILD_HOST=dg02-pool03-kvm154
export KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_TIMESTAMP='Thu Mar 23 18:39:49 CST 2023'
export SOURCE_DATE_EPOCH=1679567989

h40-repro/build-h40.sh --clean
```

The script records the fully expanded `make` command. Its core invocation is:

```bash
make -C "$KERNEL_DIR" -j"$JOBS" \
  O="$OUT_DIR" ARCH=arm64 TARGET_PRODUCT=msmnile \
  BRAND_SHOW_FLAG=oneplus TARGET_BUILD_VARIANT=user \
  CROSS_COMPILE="$GCC64_DIR/bin/aarch64-linux-android-" \
  CROSS_COMPILE_ARM32="$GCC32_DIR/bin/arm-linux-androideabi-" \
  REAL_CC="$CLANG_DIR/bin/clang" CLANG_TRIPLE=aarch64-linux-gnu- \
  PYTHON="$AOSP_BUILD_TOOLS/bin/py2-cmd" \
  HOSTCC=gcc HOSTCXX=g++ LOCALVERSION=+ \
  Image Image.gz Image.gz-dtb dtbs modules
```

The production base-DTB invocation additionally uses:

```bash
CONFIG_BUILD_ARM64_DT_OVERLAY=y DTC_FLAGS='-@ -H epapr'
```

The default output directories are `android/out/h40-kernel` for the build and
`android/out/h40-artifacts` for collected outputs. The complete log is written
to `android/out/h40-build.log`. Use a fixed `MODULE_SIGNING_KEY` when comparing
two local builds; the test key is deliberately not committed and is not the
OnePlus production key.

## Source-completeness audit

The combined source contains 104 main-tree symlinks and five vendor-tree
symlinks. No `*.o_shipped`, `*.o`, `*.a`, or `*.ko` binary-only input was
found in either repository.

Two upstream self-referential symlinks exist:

```text
vendor/oplus/kernel/oplus_performance/sched_assist/sched_assist -> sched_assist
vendor/oplus/secure/biometrics/fingerprints/bsp/uff/driver/oplus_fp_drivers -> oplus_fp_drivers
```

Neither blocked the selected H.40 build. The valid Qualcomm audio symlinks
resolve only with the nested workspace shown above.

Specific missing inputs are:

1. `device/qcom/common/dlkm/AndroidKernelModule.mk` or
   `build/dlkm/AndroidKernelModule.mk`, required by the original external-DLKM
   Android packaging pipeline.
2. DTS/DTSI for stock project family 19861/18961.
3. The RTIC `MP_DATA` generator and production input selected by `RTIC_MPGEN`.
4. A compatible Android-platform DTC for the published overlay composition.
5. The exact production Clang 10.0.7 binary and production signing key.

The modules/vendor repository contains no DTS or DTSI files despite its name.
All published production device trees are in the main repository.

## Configuration comparison and source fix

The official generated defconfig does not match the stock IKCONFIG.
`scripts/diffconfig` reports 77 entries:

| Class | Count/details |
|---|---|
| Official-only | 46 |
| Stock-only | 27 legacy OPPO/OPLUS names |
| Changed | 4: `DEBUG_FS`, `MSM_IDLE_STATS`, `PAGE_EXTENSION`, and `PAGE_OWNER`, all `y -> n` in stock |

On the unmodified published source, `olddefconfig` silently discards the old
`CONFIG_OPPO_HEALTHINFO` name. `OplusKernelEnvConfig.mk` nevertheless defines
`OPLUS_FEATURE_HEALTHINFO`, so the normal `request_queue::in_flight` field is
removed while its OPlus replacement is not enabled. Compilation then fails at
`include/linux/blkdev.h:769` with `no member named 'in_flight'`.

The sole functional-tree modification is:

```text
drivers/soc/oplus/Kconfig
```

It declares all 27 legacy stock configuration names and makes enabled legacy
names select their published OPLUS replacements. No C code was modified, no
driver was removed, and no warning was globally suppressed. The change alters
feature selection relative to the broken `olddefconfig` result, but restores
the intent encoded by the shipped config. The resulting `.config` preserves
every stock symbol/value and adds 17 modern/default symbols.

All other additions live under `h40-repro/` or in this report:

- `build-h40.sh` validates toolchains, performs stock/official configuration,
  builds out of tree, logs the command and collects/hashes all outputs.
- `extract-boot.py`, `extract-stock-boot.sh`, and
  `compare-stock-kernel.sh` extract and compare a boot payload read-only.
- `compare-symbols.py` normalizes `/proc/kallsyms` and writes missing, extra,
  order/type and summary reports.
- `compare-device-trees.py` hash-matches stock DTB/DTBO entries.
- `host-tools/` provides narrow AOSP-host-tool wrappers needed by this old
  build system.

## Build and payload result

The first unmodified attempt initially found a missing host `bc`; after the
AOSP wrapper repaired that environment issue, the first real failure was the
Kconfig/`in_flight` problem described above.

With the compatibility fix, these targets completed:

```text
Image  Image.gz  Image.gz-dtb  dtbs  modules
vmlinux  System.map  Module.symvers  .config
modules.order  modules.builtin  modules.builtin.modinfo
13 configured in-tree .ko files
```

All 13 in-tree modules report:

```text
4.14.180-perf+ SMP preempt mod_unload modversions aarch64
```

Key verified output hashes are:

| Artifact | Size / SHA-256 |
|---|---|
| Rebuilt raw `Image` | 40,134,672 bytes; `0e6f933221308a6ae2c6e1bf02550c8cc198254e4c547b7c14d8f0847204d728` |
| `vmlinux` | `bc89f166e7c684f9207a09786f624429dd1d8e8644c24d2c2c80a1e25ddc1037` |
| Direct-build `wlan.ko` | `00f30a10ed56d3add28e781c7739fcdf2a8d5e800d593d168f484541200bec55` |
| Direct-build `audio_extend_dlkm.ko` | `51cd16b9de0ca475fea6a18cdd3178445608a5798be9482e8d82e99152fc7712` |

The rebuilt Image differs from stock beginning at byte 18; even the ARM64
header size field differs because the payload is 8,192 bytes smaller.

The release, build user, host, number, linker and timestamp match the stock
banner. The compiler text does not: stock reports unidentified Clang 10.0.7,
while the rebuild records AOSP r377782c Clang 10.0.5.

## Symbols and ABI evidence

All stock kallsyms addresses are zero, so absolute and relative address
comparison is unavailable. Normalized comparison gives:

| Metric | Result |
|---|---:|
| Stock kernel symbol lines | 120,302 |
| Stock module symbol lines | 25,329 |
| Rebuilt `System.map` lines | 119,776 |
| Missing occurrences | 939 (926 unique type/name pairs) |
| Extra occurrences | 413 (411 unique type/name pairs) |
| Unique common symbols | 114,299 |
| Minimum common symbols out of order | 61 |
| Unique-name type mismatches | 10 |

Of the 939 missing occurrences, 483 are present with the same type/name in
`vmlinux` but filtered by `mksysmap`; 61 are runtime BPF JIT symbols; 478 are
dominated by VL53L1/mksysmap behavior; and 293 OPPO-named entries correspond
to the OPPO-to-OPLUS source rename. In total, 446 missing occurrences are not
present in rebuilt `vmlinux`.

The high common-symbol count and order similarity are meaningful structural
evidence, but are insufficient for verdict B because the payload, compiler,
configuration naming and some source inputs differ.

Source and rebuilt-image strings account for the observed OPlus networking,
charging/VOOC, devinfo/project, healthinfo, secure-common, display, touch,
motor, tri-state-key, fingerprint, VL53L1 and audio interface families. This
does not prove every captured `/proc` or `/sys` node appears under identical
runtime conditions; no phone was booted with the result.

## External modules

All 25 loaded stock module families have corresponding official source:

- Qualcomm qcacld WLAN: one family, directly built successfully.
- OPlus `audio_extend_dlkm`: one family, directly built successfully.
- Qualcomm audio: 23 families, all mapped to source under
  `vendor/qcom/opensource/audio-kernel`.

The complete Qualcomm audio set was not claimed as packaged. Its Android.mk
pipeline depends on the missing `AndroidKernelModule.mk` helper and Android
product-output `Module.symvers` staging, including cyclic audio dependencies.
The stock `.ko` files were not supplied, so module CRC/signature identity is
unknown; matching vermagic alone is not proof of ABI identity.

## Device trees

With the production flags, all 20 published base trees match stock exactly:

```text
18821 18857 18865 19801 19863
  x sm8150 sm8150-v2 sm8150p sm8150p-v2
```

Thus 20 of the 25 boot DTBs are byte-identical. Stock entries 17-20 are the
unpublished 19861/18961 variants. Entry 25 is a 173-byte generated RTIC FDT.

Ten of the 15 stock recovery overlays have corresponding published source;
five belong to the absent project family. The bundled DTC
`1.4.4-g756ffc4f` cannot parse the production overlay composition. A trial
source rewrite was rejected because it produced nonidentical trees and could
change reference merging; it is not part of this branch.

## Local reproducibility

Two clean fixed-source builds were performed with the same toolchains,
metadata and fixed test signing key. SHA-256 hashes for 27 compared artifacts
were identical across both builds, including `Image`, `Image.gz`,
`Image.gz-dtb`, `vmlinux`, `System.map`, `Module.symvers`, `.config`, module
metadata, all 13 in-tree modules and five normal DTBs.

That proves the repaired local build is deterministic under the recorded
inputs. It does not make it identical to stock: both local Images had SHA-256
`0e6f9332...`, while stock is `78a2ec42...`.

## What is needed next

The single most important missing input is the complete unpublished H.40
Android product/kernel source for project family 19861/18961, including the
RTIC MPGen executable and production inputs. Without it, the shipped H.40
DTB/DTBO payload cannot be reproduced from official public source.

For exact kernel-payload work after that, obtain the precise production Clang
10.0.7 binary/revision. For exact module packaging and signature comparison,
also obtain the Android DLKM helper/product output, stock `.ko` files, and the
production signing material or accept that signatures cannot match.

Detailed evidence is retained in `h40-repro/reports/`. To recheck a supplied
boot image against a new build:

```bash
h40-repro/compare-stock-kernel.sh \
  /absolute/path/to/boot.img \
  "$ANDROID_ROOT/out/h40-artifacts/arch/arm64/boot/Image" \
  "$ANDROID_ROOT/out/h40-artifacts/stock-kernel-comparison.txt"
```
