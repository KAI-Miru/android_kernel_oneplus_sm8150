#!/usr/bin/env python3
"""Apply the one reviewed quoting correction to the stage-352 runner."""
from pathlib import Path

path = Path("scripts/miru/lts357/run_compile_checkpoint_352.sh")
text = path.read_text()
old = "test \"$(grep -Fc '__asmbl(\"\", \"ip\", \"__get_user_' arch/arm/include/asm/uaccess.h)\" -ge 2"
new = "test \"$(grep -Fc '__asmbl(\"\", \"ip\", \"__get_user_' arch/arm/include/asm/uaccess.h)\" -ge 2"
if old == new:
    raise SystemExit("internal correction definition is ineffective")
if text.count(old) != 1:
    raise SystemExit(f"expected one malformed checkpoint gate, found {text.count(old)}")
path.write_text(text.replace(old, new, 1))
