#!/usr/bin/env python3

from pathlib import Path
import subprocess

LEDGER = Path("Documentation/miru/lts-4.14.190-conflicts.md")
EXPECTED_BLOB = "384d260481930f917a95cad761230cc42dba19a2"
FUNCTIONAL_SHA = "15ac7e5128349f446221947fa7947433e962f1bd"

actual = subprocess.check_output(["git", "hash-object", str(LEDGER)], text=True).strip()
if actual != EXPECTED_BLOB:
    raise SystemExit(f"ledger blob changed: expected {EXPECTED_BLOB}, found {actual}")

text = LEDGER.read_text()
old = """```text
lts: resolve transparent hugepage split conflict
```"""
new = f"""```text
{FUNCTIONAL_SHA}
lts: resolve transparent hugepage split conflict
```"""
if text.count(old) != 1:
    raise SystemExit("Step 9 resolution placeholder missing or duplicated")
LEDGER.write_text(text.replace(old, new, 1))
