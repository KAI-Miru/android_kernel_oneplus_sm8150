#!/usr/bin/env python3

from pathlib import Path
import subprocess

PATCHER = Path("scripts/miru/apply_vendor_lts190_compat_v6.py")
EXPECTED_BLOB = "044cc260e47a887d2394567a6882421199866e1f"

actual = subprocess.check_output(["git", "hash-object", str(PATCHER)], text=True).strip()
if actual != EXPECTED_BLOB:
    raise SystemExit(f"vendor v6 patcher changed: expected {EXPECTED_BLOB}, found {actual}")

text = PATCHER.read_text()
old = '''    if text.count("F2FS_OPTION(sbi).test_dummy_encryption") != 1:
        raise SystemExit("expected exactly one direct of2fs dummy boolean assignment")

'''
if text.count(old) != 1:
    raise SystemExit("redundant direct-reference count block missing or duplicated")
PATCHER.write_text(text.replace(old, "", 1))
