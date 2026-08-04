#!/usr/bin/env python3
"""Resolve the exact Miru H.40 conflicts for OpenELA 4.14.352..4.14.356."""
from pathlib import Path
from typing import Callable
import subprocess

CONFLICTS = [
    "arch/arm64/include/asm/cputype.h",
    "drivers/mmc/core/mmc_test.c",
    "drivers/net/usb/usbnet.c",
    "drivers/usb/dwc3/core.c",
    "fs/f2fs/inode.c",
    "fs/f2fs/namei.c",
    "include/linux/clk.h",
    "net/qrtr/qrtr.c",
    "security/selinux/selinuxfs.c",
]

Resolver = Callable[[int, str, str, str], str]


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def resolve_diff3(path: str, expected: int, resolver: Resolver) -> None:
    run("git", "checkout", "--conflict=diff3", "--", path)
    p = Path(path)
    lines = p.read_text().splitlines(keepends=True)
    output: list[str] = []
    i = 0
    conflict = 0
    while i < len(lines):
        if not lines[i].startswith("<<<<<<< "):
            output.append(lines[i])
            i += 1
            continue
        i += 1
        ours: list[str] = []
        while i < len(lines) and not lines[i].startswith("||||||| "):
            ours.append(lines[i])
            i += 1
        if i >= len(lines):
            raise SystemExit(f"{path}: malformed diff3 conflict (missing base marker)")
        i += 1
        base: list[str] = []
        while i < len(lines) and not lines[i].startswith("======="):
            base.append(lines[i])
            i += 1
        if i >= len(lines):
            raise SystemExit(f"{path}: malformed diff3 conflict (missing separator)")
        i += 1
        theirs: list[str] = []
        while i < len(lines) and not lines[i].startswith(">>>>>>> "):
            theirs.append(lines[i])
            i += 1
        if i >= len(lines):
            raise SystemExit(f"{path}: malformed diff3 conflict (missing end marker)")
        i += 1
        output.append(resolver(conflict, "".join(ours), "".join(base), "".join(theirs)))
        conflict += 1
    if conflict != expected:
        raise SystemExit(f"{path}: expected {expected} conflict blocks, found {conflict}")
    p.write_text("".join(output))


def resolve_cputype(index: int, ours: str, base: str, theirs: str) -> str:
    if base.strip():
        raise SystemExit("cputype: expected additive conflicts against an empty base")
    if index == 0:
        if "ARM_CPU_PART_KRYO3S" not in ours or "ARM_CPU_PART_NEOVERSE_N3" not in theirs:
            raise SystemExit("cputype: unexpected CPU-part conflict")
        return theirs + ours
    if index == 1:
        if "MIDR_KRYO3S" not in ours or "MIDR_NEOVERSE_N3" not in theirs:
            raise SystemExit("cputype: unexpected MIDR conflict")
        return theirs + ours
    raise SystemExit("cputype: unexpected conflict index")


def resolve_dwc3(index: int, ours: str, base: str, theirs: str) -> str:
    if index == 0 and "u32 reg;" in ours and "work_to_dwc(work)" in theirs:
        return ours
    if index == 1 and "void dwc3_dis_sleep_mode" in ours and "DWC3_GUCTL3_SPLITDISABLE" in theirs:
        return ours
    raise SystemExit(f"dwc3: unexpected conflict block {index}")


def resolve_mmc(index: int, ours: str, base: str, theirs: str) -> str:
    if index != 0 or "free_test_buffer:" not in theirs or "if (test->highmem)" not in ours:
        raise SystemExit("mmc_test: unexpected highmem cleanup conflict")
    return theirs


def resolve_usbnet(index: int, ours: str, base: str, theirs: str) -> str:
    if index != 0 or "ipc_log_context_create" not in ours or "eth_random_addr(node_id);" not in ours:
        raise SystemExit("usbnet: unexpected module-init conflict")
    resolved = ours.replace("\teth_random_addr(node_id);\n", "", 1)
    if "eth_random_addr(node_id);" in resolved:
        raise SystemExit("usbnet: stale global random address initialization")
    return resolved


def resolve_inode(index: int, ours: str, base: str, theirs: str) -> str:
    if index != 0 or "FI_NEW_INODE" not in ours or "f2fs_readonly" not in theirs:
        raise SystemExit("f2fs inode: unexpected dirty-inode conflict")
    readonly = "\tif (f2fs_readonly(F2FS_I_SB(inode)->sb))\n\t\treturn;\n\n"
    if readonly in ours:
        raise SystemExit("f2fs inode: readonly gate already present in ours")
    return ours + readonly


def resolve_namei(index: int, ours: str, base: str, theirs: str) -> str:
    if index == 0:
        if "f2fs_may_encrypt(dir, inode)" not in ours or "FI_NEW_INODE" not in theirs:
            raise SystemExit("f2fs namei: unexpected encryption-order conflict")
        return ours
    if index == 1:
        if "f2fs_sb_has_extra_attr(sbi)" not in ours or "f2fs_sb_has_extra_attr(sbi->sb)" not in theirs:
            raise SystemExit("f2fs namei: unexpected extra-attribute API conflict")
        return ours
    raise SystemExit("f2fs namei: unexpected conflict index")


def resolve_clk(index: int, ours: str, base: str, theirs: str) -> str:
    if index != 0 or ours.strip() != "#if defined(CONFIG_OF)":
        raise SystemExit("clk: unexpected OF guard conflict")
    marker = "#if defined(CONFIG_OF) && defined(CONFIG_COMMON_CLK)\n"
    if marker not in theirs or "clk_get_optional" not in theirs:
        raise SystemExit("clk: optional-clock helper missing from OpenELA side")
    return theirs.replace(marker, ours, 1)


def resolve_qrtr(index: int, ours: str, base: str, theirs: str) -> str:
    if index != 0 or "qrtr_all_epts" not in ours or "skb_clone" not in ours or "pskb_copy" not in theirs:
        raise SystemExit("qrtr: unexpected broadcast-copy conflict")
    return ours.replace("skb_clone(skb, GFP_KERNEL)", "pskb_copy(skb, GFP_KERNEL)", 1)


def resolve_selinux(index: int, ours: str, base: str, theirs: str) -> str:
    if index != 0 or ours.strip() != "mutex_lock(&fsi->mutex);" or "no partial writes" not in theirs:
        raise SystemExit("selinuxfs: unexpected policy-load conflict")
    validation = """\t/* no partial writes */
\tif (*ppos)
\t\treturn -EINVAL;
\t/* no empty policies */
\tif (!count)
\t\treturn -EINVAL;

\tif (count > 64 * 1024 * 1024)
\t\treturn -EFBIG;

"""
    return validation + ours


unmerged = subprocess.check_output(
    ["git", "diff", "--name-only", "--diff-filter=U"], text=True
).splitlines()
if sorted(unmerged) != CONFLICTS:
    raise SystemExit(f"unexpected stage-356 conflicts: {unmerged!r}")

resolve_diff3("arch/arm64/include/asm/cputype.h", 2, resolve_cputype)
resolve_diff3("drivers/mmc/core/mmc_test.c", 1, resolve_mmc)
resolve_diff3("drivers/net/usb/usbnet.c", 1, resolve_usbnet)
resolve_diff3("drivers/usb/dwc3/core.c", 2, resolve_dwc3)
resolve_diff3("fs/f2fs/inode.c", 1, resolve_inode)
resolve_diff3("fs/f2fs/namei.c", 2, resolve_namei)
resolve_diff3("include/linux/clk.h", 1, resolve_clk)
resolve_diff3("net/qrtr/qrtr.c", 1, resolve_qrtr)
resolve_diff3("security/selinux/selinuxfs.c", 1, resolve_selinux)

ledger_path = Path("Documentation/miru/lts-4.14.357-conflicts.md")
ledger = ledger_path.read_text().rstrip()
if "## Stage 5 — 4.14.352 to 4.14.356" in ledger:
    raise SystemExit("stage-356 ledger already present")
ledger += r'''

## Stage 5 — 4.14.352 to 4.14.356

OpenELA parent: `a76b6a6556353484f6f29572989cd37b6cff90cc`

Initial textual conflicts: **9**. Metadata conflicts: **0**. Remaining conflicts: **0**.

The exact read-only merge audit at integration source
`8d50d842d343c0af619e5774cab891c505e983bd` established the inventory below.
The resolver preserves the newer Qualcomm/Android structures and ports each
independent OpenELA fix into the matching downstream call flow.

| Path | OpenELA intent | Miru divergence | Final Miru resolution | Class | Runtime risk / validation |
|---|---|---|---|---|---|
| `arch/arm64/include/asm/cputype.h` | Add Arm Neoverse N3 part and MIDR definitions. | Miru adds Qualcomm Kryo part/MIDR definitions at the same anchors. | Keep both definition sets, grouped by implementer. | combined | Low; compile an ARM64 CPU-info consumer and retain all Kryo identifiers. |
| `drivers/mmc/core/mmc_test.c` | Return `-ENOMEM` when the optional highmem test allocation fails and use a shared cleanup label. | Miru only made the final free conditional. | Adopt the OpenELA allocation check and cleanup label; a successful allocation is always freed exactly once. | upstream | Low; compile the MMC test object. |
| `drivers/net/usb/usbnet.c` | Stop using one module-global random MAC and let each invalid device address be randomized independently. | Miru initializes downstream IPC logging in the same module-init block. | Remove only `eth_random_addr(node_id)` while retaining the IPC-log initialization; keep the automatically merged per-device MAC handling. | combined | Medium; compile usbnet and verify global `node_id` use is absent. |
| `drivers/usb/dwc3/core.c` | Add a Hisilicon-only split-boundary-disable quirk to the generic role-switch path. | Qualcomm's core replaced that generic role-switch worker with downstream sleep/role handling. | Preserve Qualcomm's role implementation. Keep the automatically merged property, register definitions and resume-complete hook; the quirk remains dormant without `snps,dis-split-quirk`. | adapted | High; compile DWC3 core/gadget and retain the proven direct pending-event dispatch repair. |
| `fs/f2fs/inode.c` | Avoid dirtying an inode on a read-only F2FS mount. | Newer Android already skips newly allocated inodes first. | Keep the Android new-inode gate, then add the OpenELA read-only gate before dirty tracking. | combined | High; userdata filesystem path, object compile and later physical mount/write validation. |
| `fs/f2fs/namei.c` | Set `FI_NEW_INODE` before encryption setup. | Newer Android already does so and uses the newer `f2fs_may_encrypt(dir, inode)` API. | Preserve the newer Android implementation. | not applicable | High; F2FS create path, object compile and later physical validation. |
| `include/linux/clk.h` | Add `clk_get_optional()`. | Qualcomm exposes OF clock-provider helpers even without `CONFIG_COMMON_CLK`. | Add the optional-clock helper and retain Qualcomm's `CONFIG_OF` provider guard. | combined | Medium; compile clock consumers and preserve downstream provider visibility. |
| `net/qrtr/qrtr.c` | Use `pskb_copy()` so every broadcast endpoint gets an independent mutable header. | Miru uses an rwsem, downstream endpoint list, automatic-NID filtering and extra enqueue arguments. | Preserve the downstream traversal and replace only `skb_clone()` with `pskb_copy()`. | adapted | High; modem/IPC path, compile QRTR and physically validate radio/audio services later. |
| `security/selinux/selinuxfs.c` | Reject partial, empty and oversized policy writes before loading. | Android wraps SELinux filesystem state and uses `fsi->mutex` instead of the legacy global mutex. | Apply all three validation gates before taking `fsi->mutex`. | adapted | High; boot-critical policy load, compile SELinuxFS and later physical boot validation. |

### Stage 5 semantic gates

- exact nine-path conflict inventory and exact OpenELA second parent;
- Neoverse N3 and Qualcomm Kryo identifiers coexist;
- MMC highmem allocation failure, per-device usbnet MAC handling and IPC logging coexist;
- Qualcomm DWC3 role handling and direct gadget-event dispatch remain intact;
- F2FS read-only/new-inode ordering is explicit;
- `clk_get_optional()` is present without narrowing Qualcomm's OF provider API;
- QRTR broadcasts use independent headers while retaining downstream endpoint filtering;
- SELinux policy write bounds are checked under the wrapped Android state model;
- no unmerged entries, conflict headers, `.orig`, `.rej` or `.pyc` files remain.
'''
ledger_path.write_text(ledger.rstrip() + "\n")

# Final semantic assertions before the executor stages any resolution.
checks = {
    "arch/arm64/include/asm/cputype.h": (
        "ARM_CPU_PART_NEOVERSE_N3", "MIDR_NEOVERSE_N3",
        "ARM_CPU_PART_KRYO4G", "MIDR_KRYO4G",
    ),
    "drivers/mmc/core/mmc_test.c": ("goto free_test_buffer;", "free_test_buffer:"),
    "drivers/net/usb/usbnet.c": ("ipc_log_context_create", "eth_hw_addr_random(net)"),
    "drivers/usb/dwc3/core.c": ("void dwc3_en_sleep_mode", "void dwc3_dis_sleep_mode", "snps,dis-split-quirk"),
    "fs/f2fs/inode.c": ("f2fs_readonly(F2FS_I_SB(inode)->sb)",),
    "fs/f2fs/namei.c": ("set_inode_flag(inode, FI_NEW_INODE);", "f2fs_may_encrypt(dir, inode)"),
    "include/linux/clk.h": ("clk_get_optional", "#if defined(CONFIG_OF)"),
    "net/qrtr/qrtr.c": ("qrtr_all_epts", "pskb_copy(skb, GFP_KERNEL)"),
    "security/selinux/selinuxfs.c": ("count > 64 * 1024 * 1024", "mutex_lock(&fsi->mutex)"),
}
for path, needles in checks.items():
    text = Path(path).read_text()
    if any(marker in text for marker in ("<<<<<<<", "|||||||", "=======", ">>>>>>>")):
        raise SystemExit(f"{path}: conflict marker remains")
    for needle in needles:
        if needle not in text:
            raise SystemExit(f"{path}: semantic gate missing: {needle}")

usbnet = Path("drivers/net/usb/usbnet.c").read_text()
for stale in ("static u8\tnode_id", "eth_random_addr(node_id)", "memcpy (net->dev_addr, node_id"):
    if stale in usbnet:
        raise SystemExit(f"usbnet: stale global MAC path remains: {stale}")

qrtr = Path("net/qrtr/qrtr.c").read_text()
if "list_for_each_entry(node, &qrtr_all_epts, item)" not in qrtr or "down_read(&qrtr_node_lock)" not in qrtr:
    raise SystemExit("qrtr: downstream endpoint traversal was lost")

selinux = Path("security/selinux/selinuxfs.c").read_text()
validation_pos = selinux.index("/* no partial writes */", selinux.index("static ssize_t sel_write_load"))
lock_pos = selinux.index("mutex_lock(&fsi->mutex)", validation_pos)
if validation_pos > lock_pos:
    raise SystemExit("selinuxfs: policy bounds must precede the wrapped-state lock")
