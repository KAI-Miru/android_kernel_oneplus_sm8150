#!/usr/bin/env python3

from __future__ import annotations

import difflib
import pathlib
import re
import subprocess
import sys

RESOLVED = "0190a01fb1cde1c2ba48e7836084bad818c14d94"
MOD = pathlib.Path("include/linux/mod_devicetable.h")
INPUT = pathlib.Path("include/uapi/linux/input-event-codes.h")
LEDGER = pathlib.Path("Documentation/miru/lts-4.14.190-conflicts.md")

EXPECTED_HASHES = {
    MOD: "129ceb61cfca80b4cc16e934e6845b13268be87f",
    INPUT: "385c141d54338ccb7f213b39dbfb37f8a81faac9",
    LEDGER: "26c851ea6241682ef476a142496918cc54006c77",
}


def git(*args: str, text: bool = True) -> str | bytes:
    return subprocess.check_output(["git", *args], text=text)


def verify_current_hashes() -> None:
    for path, expected in EXPECTED_HASHES.items():
        actual = git("hash-object", str(path)).strip()
        if actual != expected:
            raise SystemExit(f"{path}: expected blob {expected}, found {actual}")


def resolved_file(path: pathlib.Path) -> str:
    return git("show", f"{RESOLVED}:{path}")


def validate_mod_table(old: str, new: str) -> None:
    delta = list(difflib.ndiff(old.splitlines(), new.splitlines()))
    removed = [line[2:] for line in delta if line.startswith("- ")]
    added = [line[2:] for line in delta if line.startswith("+ ")]
    expected_added = [
        " *",
        " * Note: The ordering of the struct is different from upstream because the",
        " * static initializers in kernels < 5.7 still use C89 style while upstream",
        " * has been converted to proper C99 initializers.",
        "\t__u16 steppings;",
        "#define X86_STEPPING_ANY 0",
    ]
    if removed:
        raise SystemExit(f"mod_devicetable removes H.40 lines: {removed!r}")
    if added != expected_added:
        raise SystemExit(f"unexpected mod_devicetable additions: {added!r}")

    required = (
        "#define INPUT_DEVICE_ID_SW_MAX\t\t0x20",
        '#define GPR_MODULE_PREFIX "gpr:"',
        "struct gpr_device_id {",
        '#define SOUNDWIRE_MODULE_PREFIX "swr:"',
        "struct swr_device_id {",
        '#define SLIMBUS_MODULE_PREFIX "slim:"',
        "struct slim_device_id {",
        "struct mhi_device_id {",
        "\t__u16 steppings;",
        "#define X86_STEPPING_ANY 0",
    )
    for token in required:
        if token not in new:
            raise SystemExit(f"missing module-table token: {token}")


def parse_defines(text: str) -> dict[str, str]:
    pattern = re.compile(
        r"^#define\s+([A-Z][A-Z0-9_]*)\s+(.+?)(?:\s*/\*.*)?$", re.M
    )
    return {name: value.strip() for name, value in pattern.findall(text)}


def validate_input_codes(old_text: str, new_text: str) -> None:
    old = parse_defines(old_text)
    new = parse_defines(new_text)

    removed = sorted(set(old) - set(new))
    changed = sorted(k for k in set(old) & set(new) if old[k] != new[k])
    added = sorted(set(new) - set(old))

    if removed:
        raise SystemExit(f"input ABI definitions removed: {removed}")
    if changed:
        details = [(k, old[k], new[k]) for k in changed]
        raise SystemExit(f"input ABI values changed: {details}")
    if added != ["SW_MACHINE_COVER"] or new["SW_MACHINE_COVER"] != "0x14":
        raise SystemExit(f"unexpected input additions: {[(k, new[k]) for k in added]}")

    expected = {
        "KEY_FP_GESTURE_UP": "0x2e8",
        "KEY_FP_GESTURE_DOWN": "0x2e9",
        "KEY_FP_GESTURE_LEFT": "0x2ea",
        "KEY_FP_GESTURE_RIGHT": "0x2eb",
        "KEY_FP_GESTURE_LONG_PRESS": "0x2ec",
        "KEY_FP_GESTURE_TAP": "0x2ed",
        "SW_HPHL_OVERCURRENT": "0x10",
        "SW_HPHR_OVERCURRENT": "0x11",
        "SW_MICROPHONE2_INSERT": "0x12",
        "SW_UNSUPPORT_INSERT": "0x13",
        "SW_MACHINE_COVER": "0x14",
        "SW_MAX": "0x20",
    }
    for name, value in expected.items():
        if new.get(name) != value:
            raise SystemExit(f"{name}: expected {value}, found {new.get(name)}")


def update_ledger() -> None:
    text = LEDGER.read_text()
    replacements = {
        "- Resolved conflicts: 6": "- Resolved conflicts: 8",
        "- Remaining conflicts: 22": "- Remaining conflicts: 20",
        "include/linux/mod_devicetable.h\n": "",
        "include/uapi/linux/input-event-codes.h\n": "",
    }
    for old, new in replacements.items():
        count = text.count(old)
        if count != 1:
            raise SystemExit(f"ledger guard failed for {old!r}: found {count}")
        text = text.replace(old, new, 1)

    marker = "## Remaining deferred conflicts\n"
    if text.count(marker) != 1:
        raise SystemExit("remaining-conflicts marker missing or duplicated")

    section = """## Resolved in Step 2

The module matching and input ABI conflicts use the LineageOS SM8150
4.14.190 resolution from `0190a01fb1cde1c2ba48e7836084bad818c14d94`:

```text
include/linux/mod_devicetable.h
include/uapi/linux/input-event-codes.h
```

This preserves the H.40 GPR, SoundWire, Slimbus and MHI device-table
structures and `INPUT_DEVICE_ID_SW_MAX=0x20`, while adding the stable
x86 stepping field. All existing H.40 input codes retain their numeric
values. `SW_MACHINE_COVER` is added at the unused value `0x14`, avoiding
collisions with H.40 headset switch values `0x10` through `0x13`.

Resolution commit:

```text
lts: resolve module matching and input ABI conflicts
```

"""
    LEDGER.write_text(text.replace(marker, section + marker, 1))


def main() -> None:
    verify_current_hashes()

    old_mod = MOD.read_text()
    new_mod = resolved_file(MOD)
    old_input = INPUT.read_text()
    new_input = resolved_file(INPUT)

    validate_mod_table(old_mod, new_mod)
    validate_input_codes(old_input, new_input)

    MOD.write_text(new_mod)
    INPUT.write_text(new_input)
    update_ledger()

    print("Step 2 validation passed and files were updated.")


if __name__ == "__main__":
    main()
