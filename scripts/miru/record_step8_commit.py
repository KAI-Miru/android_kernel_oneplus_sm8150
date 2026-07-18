#!/usr/bin/env python3

from pathlib import Path
import subprocess

LEDGER = Path("Documentation/miru/lts-4.14.190-conflicts.md")
EXPECTED_BLOB = "4dd3a3dc7f13ae50b50bdbe4f49fae023f3cd442"
FUNCTIONAL_SHA = "fdf8bc143cc6e6a911d645e0f2eb4b025ce6e3cd"

actual = subprocess.check_output(["git", "hash-object", str(LEDGER)], text=True).strip()
if actual != EXPECTED_BLOB:
    raise SystemExit(f"ledger blob changed: expected {EXPECTED_BLOB}, found {actual}")

text = LEDGER.read_text()
old = """```text
lts: resolve conntrack IPv4 sysctl and QRTR conflicts
```"""
new = f"""```text
{FUNCTIONAL_SHA}
lts: resolve conntrack IPv4 sysctl and QRTR conflicts
```"""
if text.count(old) != 1:
    raise SystemExit("Step 8 resolution placeholder missing or duplicated")
LEDGER.write_text(text.replace(old, new, 1))
