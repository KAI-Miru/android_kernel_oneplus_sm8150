#!/usr/bin/env python3

from pathlib import Path
import subprocess

PATCHER = Path("scripts/miru/apply_vendor_lts190_compat.py")
EXPECTED_BLOB = "15c0273eddef52aaec19a75604f904733791af1b"

actual = subprocess.check_output(["git", "hash-object", str(PATCHER)], text=True).strip()
if actual != EXPECTED_BLOB:
    raise SystemExit(f"vendor patcher changed: expected {EXPECTED_BLOB}, found {actual}")

text = PATCHER.read_text()
old = '''    text = replace_regex(
        text,
        r"^#define DUMMY_ENCRYPTION_ENABLED\\(sbi\\).*?$",
        "#define DUMMY_ENCRYPTION_ENABLED(sbi) \\\\\n\\t(F2FS_OPTION(sbi).dummy_enc_ctx.ctx != NULL)",
    )
'''
new = '''    text = replace_regex(
        text,
        r"^#define DUMMY_ENCRYPTION_ENABLED\\(sbi\\)\\s*(?:\\\\\\n\\s*)?"
        r"\\(F2FS_OPTION\\(sbi\\)\\.test_dummy_encryption\\)$",
        "#define DUMMY_ENCRYPTION_ENABLED(sbi) \\\\\n\\t(F2FS_OPTION(sbi).dummy_enc_ctx.ctx != NULL)",
    )
'''
if text.count(old) != 1:
    raise SystemExit("broad of2fs dummy-encryption guard block missing or duplicated")
PATCHER.write_text(text.replace(old, new, 1))
