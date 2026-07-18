#!/usr/bin/env python3

from pathlib import Path

path = Path("scripts/miru/resolve_step10.py")
text = path.read_text()
old = '        "spin_unlock_irq(&runtime->lock);",\n'
if text.count(old) != 1:
    raise SystemExit("Step 10 scoped raw-MIDI guard adjustment failed")
path.write_text(text.replace(old, "", 1))
