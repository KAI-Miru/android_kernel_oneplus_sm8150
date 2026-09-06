#!/usr/bin/env python3

from pathlib import Path
import subprocess

SCRIPT = Path("scripts/miru/build_external_modules_4.14.190.sh")
EXPECTED_BLOB = "4c7c17c4bbb3aa51b8f974edde27330d0367dd74"

actual = subprocess.check_output(["git", "hash-object", str(SCRIPT)], text=True).strip()
if actual != EXPECTED_BLOB:
    raise SystemExit(f"external module script changed: expected {EXPECTED_BLOB}, found {actual}")

text = SCRIPT.read_text()

anchor = "export TARGET_BUILD_VARIANT=user\n"
insert = anchor + '''
# This kernel Makefile hard-wires CC through scripts/gcc-wrapper.py and REAL_CC.
# Environment CC=clang is therefore insufficient for external M= builds.
# Pass the exact successful kernel toolchain as command-line make variables.
MODULE_MAKE_ARGS=(
  "ARCH=arm64"
  "TARGET_PRODUCT=msmnile"
  "BRAND_SHOW_FLAG=oneplus"
  "TARGET_BUILD_VARIANT=user"
  "CROSS_COMPILE=${GCC64_DIR}/bin/aarch64-linux-android-"
  "CROSS_COMPILE_ARM32=${GCC32_DIR}/bin/arm-linux-androideabi-"
  "REAL_CC=${CLANG_DIR}/bin/clang"
  "CLANG_TRIPLE=aarch64-linux-gnu-"
  "PYTHON=${AOSP_BUILD_TOOLS}/bin/py2-cmd"
  "HOSTCC=gcc"
  "HOSTCXX=g++"
  "LOCALVERSION=+"
)
'''
if text.count(anchor) != 1:
    raise SystemExit("toolchain argument insertion anchor missing or duplicated")
text = text.replace(anchor, insert, 1)

replacements = {
    'KERNEL_RELEASE="$(make -s -C "${KERNEL_DIR}" O="${OUT_DIR}" kernelrelease)"':
        'KERNEL_RELEASE="$(make -s -C "${KERNEL_DIR}" O="${OUT_DIR}" "${MODULE_MAKE_ARGS[@]}" kernelrelease)"',
    'make -j4 -C "${KERNEL_DIR}" O="${OUT_DIR}" M="${MIDAS_ROOT}" \\\n  CONFIG_OPLUS_FEATURE_MIDAS=n':
        'make -j4 -C "${KERNEL_DIR}" O="${OUT_DIR}" M="${MIDAS_ROOT}" \\\n  "${MODULE_MAKE_ARGS[@]}" \\\n  CONFIG_OPLUS_FEATURE_MIDAS=n',
    'make -j4 -C "${KERNEL_DIR}" O="${OUT_DIR}" M="${work}" \\\n    AUDIO_ROOT="${AUDIO_ROOT}"':
        'make -j4 -C "${KERNEL_DIR}" O="${OUT_DIR}" M="${work}" \\\n    "${MODULE_MAKE_ARGS[@]}" \\\n    AUDIO_ROOT="${AUDIO_ROOT}"',
    'make -j4 -C "${KERNEL_DIR}" O="${OUT_DIR}" M="${work}" \\\n    MODNAME=audio_extend_dlkm BOARD_PLATFORM=msmnile':
        'make -j4 -C "${KERNEL_DIR}" O="${OUT_DIR}" M="${work}" \\\n    "${MODULE_MAKE_ARGS[@]}" \\\n    MODNAME=audio_extend_dlkm BOARD_PLATFORM=msmnile',
    'make -j4 -C "${KERNEL_DIR}" O="${OUT_DIR}" M="${WLAN_ROOT}" \\\n  WLAN_ROOT="${WLAN_ROOT}"':
        'make -j4 -C "${KERNEL_DIR}" O="${OUT_DIR}" M="${WLAN_ROOT}" \\\n  "${MODULE_MAKE_ARGS[@]}" \\\n  WLAN_ROOT="${WLAN_ROOT}"',
}

for old, new in replacements.items():
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected one external make invocation, found {count}: {old[:80]!r}")
    text = text.replace(old, new, 1)

SCRIPT.write_text(text)

updated = SCRIPT.read_text()
if updated.count('"${MODULE_MAKE_ARGS[@]}"') != 5:
    raise SystemExit("not all five make invocations received the pinned toolchain arguments")
if 'REAL_CC=${CLANG_DIR}/bin/clang' not in updated:
    raise SystemExit("pinned Clang REAL_CC assignment is missing")
print("External module make invocations now use the pinned kernel Clang toolchain.")
