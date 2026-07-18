#!/usr/bin/env python3

from pathlib import Path
import subprocess

DRIVER = Path("scripts/miru/ci_build_4.14.190.sh")
EXPECTED_BLOB = "22e14706ca055ffe68b35562f5874c647d1219a8"

actual = subprocess.check_output(["git", "hash-object", str(DRIVER)], text=True).strip()
if actual != EXPECTED_BLOB:
    raise SystemExit(f"build driver changed: expected {EXPECTED_BLOB}, found {actual}")

text = DRIVER.read_text()
old = 'rsync -a "${VENDOR_SOURCE}/vendor/" "${ANDROID_ROOT}/vendor/"\n'
new = '''rsync -a "${VENDOR_SOURCE}/vendor/" "${ANDROID_ROOT}/vendor/"

# Android 4.14.190 changed shared F2FS trace enums and the fscrypt dummy-context
# callback.  The official H.40 vendor filesystem forks predate those APIs, so
# apply the exact-hash-guarded compatibility migration before compilation.
python3 "${GITHUB_WORKSPACE}/scripts/miru/apply_vendor_lts190_compat_v3.py" \\
  "${ANDROID_ROOT}/vendor" \\
  --report "${DIAG_DIR}/vendor-lts190-compat-report.txt"

mkdir -p "${DIAG_DIR}/vendor-patches"
for rel in \\
  oplus/kernel/of2fs/f2fs.h \\
  oplus/kernel/of2fs/super.c \\
  oplus/kernel_4.14/ext4/ext4.h \\
  oplus/kernel_4.14/ext4/super.c; do
  safe="${rel//\//__}"
  diff -u \\
    "${VENDOR_SOURCE}/vendor/${rel}" \\
    "${ANDROID_ROOT}/vendor/${rel}" \\
    > "${DIAG_DIR}/vendor-patches/${safe}.diff" || true
done
'''
if text.count(old) != 1:
    raise SystemExit("vendor rsync insertion point missing or duplicated")
DRIVER.write_text(text.replace(old, new, 1))
