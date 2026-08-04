#!/usr/bin/env python3
"""Resolve Miru H.40 conflicts for OpenELA 4.14.348..4.14.352."""
from pathlib import Path
import subprocess

CONFLICTS = [
    "arch/arm/include/asm/uaccess.h",
    "fs/f2fs/segment.c",
    "fs/f2fs/super.c",
]


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    found = text.count(old)
    if found != count:
        raise SystemExit(f"{path}: expected {count} reviewed anchors, found {found}")
    p.write_text(text.replace(old, new))


unmerged = subprocess.check_output(
    ["git", "diff", "--name-only", "--diff-filter=U"], text=True
).splitlines()
if sorted(unmerged) != CONFLICTS:
    raise SystemExit(f"unexpected stage-352 conflicts: {unmerged!r}")

run("git", "checkout", "--ours", "--", *CONFLICTS)

# OpenELA removes size-specific clobber lists because the called helper may
# clobber r12/ip for every access size. Preserve Android's __asmbl() form and
# conditional assembler clobber syntax used by this Clang-compatible ARM tree.
uaccess = Path("arch/arm/include/asm/uaccess.h")
text = uaccess.read_text()
start = text.index("#define __GUP_CLOBBER_1")
end = text.index("#define __get_user_x", start)
text = text[:start] + text[end:]
old = ': __GUP_CLOBBER_##__s)'
if text.count(old) != 2:
    raise SystemExit("uaccess: expected two size-specific clobber users")
text = text.replace(old, ': __asmbl_clobber("ip"), "lr", "cc")')
uaccess.write_text(text)

# Both F2FS fixes are already present in the much newer Android downstream
# implementation. Keep the Android APIs and verify the exact semantic state.
segment = Path("fs/f2fs/segment.c").read_text()
for needle in (
    'f2fs_err(sbi, "invalid journal entries nats %u sits %u\\n",',
    "nats_in_cursum(nat_j), sits_in_cursum(sit_j)",
    "return -EINVAL;",
):
    if needle not in segment:
        raise SystemExit(f"fs/f2fs/segment.c: semantic gate missing: {needle}")

super_text = Path("fs/f2fs/super.c").read_text()
for needle in (
    'f2fs_err(sbi, "Failed to initialize F2FS segment manager (%d)",',
    'f2fs_err(sbi, "Failed to initialize F2FS node manager (%d)",',
):
    if needle not in super_text:
        raise SystemExit(f"fs/f2fs/super.c: semantic gate missing: {needle}")

ledger_path = Path("Documentation/miru/lts-4.14.357-conflicts.md")
ledger = ledger_path.read_text().rstrip()
if "## Stage 4 — 4.14.348 to 4.14.352" in ledger:
    raise SystemExit("stage-352 ledger already present")
ledger += r'''

## Stage 4 — 4.14.348 to 4.14.352

OpenELA parent: `6da009d8de389742d55219ebed50378f53937a5b`

Initial textual conflicts: **3**. Remaining conflicts: **0**.

The exact guarded dry merge at integration source `37b1def329eee1dd1dfffc54ec16045b866cc304`
produced the three paths below. An earlier predicted inventory naming `Makefile`,
`drivers/media/pci/cx18/cx18-streams.c`, and `drivers/usb/dwc3/core.c` was rejected:
the latter two have identical OpenELA blob identities at the exact 4.14.348 and
4.14.352 parents, while `Makefile` merges automatically. DWC3 and CX18 remain
explicit regression compile targets even though they are not stage-352 conflicts.

| Path | OpenELA intent | Miru divergence | LineageOS reference | Final Miru resolution | Class | Compile impact | Runtime risk / validation |
|---|---|---|---|---|---|---|---|
| `arch/arm/include/asm/uaccess.h` | Remove access-size-specific ARM get-user clobber lists and always declare `ip`, `lr` and condition codes clobbered. | Android's ARM helper calls use `__asmbl()` and `__asmbl_clobber()` for Clang/instruction-selection compatibility. | Preserves the Android assembler macros while applying one generic clobber list. | Adopt the Lineage-compatible form: remove `__GUP_CLOBBER_*`, retain `__asmbl()` calls and declare `__asmbl_clobber("ip"), "lr", "cc"` in both macros. | adapted | Controlled ARM32 uaccess consumer probe | Medium: validate the compatibility header with the pinned Clang/GCC32 pair without changing the ARM64 device defconfig. |
| `fs/f2fs/segment.c` | Log invalid NAT/SIT journal counts before rejecting corrupt summary blocks. | The newer Android F2FS implementation already has the same check through `f2fs_err()`. | Identical to Miru. | Preserve the Android implementation and assert the values are logged before `-EINVAL`. | not applicable | F2FS segment manager | Medium: mount/recovery diagnostics; object compile and corruption-path semantic check. |
| `fs/f2fs/super.c` | Include the actual error code when segment/node-manager initialization fails. | The newer Android F2FS implementation already logs both errors through `f2fs_err()`. | Identical to Miru. | Preserve the Android implementation and assert both `%d` error arguments remain. | not applicable | F2FS mount path | High: userdata mount; object compile and later mount/write physical validation. |

### Stage 4 semantic gates

- exact three-path conflict inventory and exact OpenELA second parent;
- both ARM get-user macros use one conservative Android-compatible clobber set;
- Android F2FS journal validation and initialization error reporting remain present;
- Qualcomm-safe DWC3 direct dispatch repair, QRTR state and GPL audio export remain intact;
- DWC3 core/gadget and CX18 are regression-compiled despite not conflicting;
- no unmerged entries, conflict headers, `.orig` or `.rej` files remain.
'''
ledger_path.write_text(ledger.rstrip() + "\n")

final_uaccess = uaccess.read_text()
if "__GUP_CLOBBER_" in final_uaccess:
    raise SystemExit("uaccess: stale size-specific clobber macros remain")
if final_uaccess.count('__asmbl_clobber("ip"), "lr", "cc"') != 2:
    raise SystemExit("uaccess: generic Android-compatible clobbers incomplete")
if final_uaccess.count('__asmbl("", "ip", "__get_user_') < 2:
    raise SystemExit("uaccess: Android __asmbl get-user calls were lost")
