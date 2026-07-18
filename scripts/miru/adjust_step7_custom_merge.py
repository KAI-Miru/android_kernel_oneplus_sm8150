#!/usr/bin/env python3

from pathlib import Path

path = Path("scripts/miru/resolve_step7.py")
text = path.read_text()

old_hash = 'EXPECTED_RESOLVED_COMPOSITE = "cfcd8259355b84c54ee6998aa59b6919f4b1997b"'
new_hash = 'EXPECTED_RESOLVED_COMPOSITE = "2abedb7faed8d78639f19e38a679d92c037f65cc"'
if text.count(old_hash) != 1:
    raise SystemExit("Step 7 composite hash adjustment guard failed")
text = text.replace(old_hash, new_hash, 1)

old_error = 'f"resolved composite blob differs from audited Lineage result: {actual}"'
new_error = 'f"resolved composite blob differs from guarded H.40 custom result: {actual}"'
if text.count(old_error) != 1:
    raise SystemExit("Step 7 composite error-message adjustment guard failed")
text = text.replace(old_error, new_error, 1)

path.write_text(text)
