#!/usr/bin/env python3

from pathlib import Path

path = Path("scripts/miru/ci_build_4.14.190.sh")
text = path.read_text()
anchor = '  --report "${DIAG_DIR}/vendor-lts190-compat-report.txt"\n'
insert = anchor + '''
python3 "${GITHUB_WORKSPACE}/scripts/miru/fix_vendor_lts190_format_quotes.py" \\
  "${ANDROID_ROOT}/vendor" \\
  --report "${DIAG_DIR}/vendor-lts190-format-quote-report.txt"
'''
if text.count(anchor) != 1:
    raise SystemExit("vendor compatibility report anchor missing or duplicated")
path.write_text(text.replace(anchor, insert, 1))
