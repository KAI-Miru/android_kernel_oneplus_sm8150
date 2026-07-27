#!/usr/bin/env python3
"""Resolve the seven authentic ARM64 conflicts for Miru H.40 LTS 4.14.305.

The script regenerates Git's original diff3 merge from the immutable scaffold
parents, applies the reviewed semantic resolutions, and refuses to continue if
the resulting source delta differs from the audited patch identity.
"""

from __future__ import annotations

import hashlib
import re
import subprocess
import tempfile
from pathlib import Path

SCAFFOLD = "b92a77e96dd54fd30f8f39c7eef23e76f211c515"
PREPARATION_PARENT = "b125a425ef1559871b1d6cd662806c8afc53e934"
TARGET = "4415bf5e08942aee6487946a3e0a50956ef68f1e"
EXPECTED_PATCH_SHA256 = "220fa976b3bbef9230ea690244b2900795516923398389bff5b8a0cf2fa06038"

PATHS = [
    "Documentation/arm64/silicon-errata.txt",
    "arch/arm64/Kconfig",
    "arch/arm64/include/asm/cpucaps.h",
    "arch/arm64/include/asm/cputype.h",
    "arch/arm64/kernel/cpu_errata.c",
    "arch/arm64/kernel/setup.c",
    "arch/arm64/mm/mmu.c",
]


def run(*args: str, input_data: bytes | None = None) -> bytes:
    return subprocess.check_output(list(args), input=input_data)


def git_show(commit: str, path: str) -> bytes:
    return run("git", "show", f"{commit}:{path}")


def merge_preview(base: str, path: str) -> str:
    with tempfile.TemporaryDirectory(prefix="lts305-arm64-") as tmp:
        tmpdir = Path(tmp)
        ours = tmpdir / "ours"
        ancestor = tmpdir / "base"
        theirs = tmpdir / "theirs"
        ours.write_bytes(git_show(PREPARATION_PARENT, path))
        ancestor.write_bytes(git_show(base, path))
        theirs.write_bytes(git_show(TARGET, path))
        proc = subprocess.run(
            ["git", "merge-file", "-p", "--diff3", str(ours), str(ancestor), str(theirs)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        # git merge-file returns the number of conflict hunks (capped at 127),
        # not merely a boolean conflict status.
        if proc.returncode < 0 or proc.returncode > 127:
            raise SystemExit(
                f"git merge-file failed for {path}: {proc.returncode}: "
                f"{proc.stderr.decode(errors='replace')}"
            )
        return proc.stdout.decode()


def replace_conflicts(text: str, replacements: list[str], path: str) -> str:
    pattern = re.compile(r"^<<<<<<<.*?^>>>>>>>.*?\n", re.MULTILINE | re.DOTALL)
    found = list(pattern.finditer(text))
    if len(found) != len(replacements):
        raise SystemExit(
            f"unexpected conflict count for {path}: got {len(found)}, "
            f"expected {len(replacements)}"
        )
    pieces: list[str] = []
    position = 0
    for match, replacement in zip(found, replacements):
        pieces.append(text[position : match.start()])
        pieces.append(replacement)
        position = match.end()
    pieces.append(text[position:])
    return "".join(pieces)


REPLACEMENTS: dict[str, list[str]] = {
    PATHS[0]: [
        """| ARM            | Cortex-A76      | #1286807        | ARM64_ERRATUM_1286807       |\n| ARM            | Cortex-A76      | #1188873        | ARM64_ERRATUM_1188873       |\n"""
    ],
    PATHS[1]: [
        """config ARM64_ERRATUM_1286807
\tbool "Cortex-A76: Modification of the translation table for a virtual address might lead to read-after-read ordering violation"
\tdefault n
\tselect ARM64_WORKAROUND_REPEAT_TLBI
\thelp
\t  This option adds workaround for ARM Cortex-A76 erratum 1286807

\t  On the affected Cortex-A76 cores (r0p0 to r3p0), if a virtual
\t  address for a cacheable mapping of a location is being
\t  accessed by a core while another core is remapping the virtual
\t  address to a new physical page using the recommended
\t  break-before-make sequence, then under very rare circumstances
\t  TLBI+DSB completes before a read using the translation being
\t  invalidated has been observed by other observers. The
\t  workaround repeats the TLBI+DSB operation.

config ARM64_ERRATUM_1188873
\tbool "Cortex-A76: MRC read following MRRC read of specific Generic Timer in AArch32 might give incorrect result"
\tdefault y
\tdepends on COMPAT
\tselect ARM_ARCH_TIMER_OOL_WORKAROUND
\thelp
\t  This option adds work arounds for ARM Cortex-A76 erratum 1188873

\t  Affected Cortex-A76 cores (r0p0, r1p0, r2p0) could cause
\t  register corruption when accessing the timer registers from
\t  AArch32 userspace.

\t  If unsure, say Y.

config ARM64_ERRATUM_1742098
\tbool "Cortex-A57/A72: 1742098: ELR recorded incorrectly on interrupt taken between cryptographic instructions in a sequence"
\tdepends on COMPAT
\tdefault y
\thelp
\t  This option removes the AES hwcap for aarch32 user-space to
\t  workaround erratum 1742098 on Cortex-A57 and Cortex-A72.

\t  Affected parts may corrupt the AES state if an interrupt is
\t  taken between a pair of AES instructions. These instructions
\t  are only present if the cryptography extensions are present.
\t  All software should have a fallback implementation for CPUs
\t  that don't implement the cryptography extensions.

\t  If unsure, say Y.

"""
    ],
    PATHS[2]: [
        """#define ARM64_HW_DBM\t\t\t\t28
#define ARM64_WORKAROUND_1188873\t\t29
#define ARM64_SPECTRE_BHB\t\t\t30
#define ARM64_WORKAROUND_1742098\t\t31
""",
        """#define ARM64_NCAPS\t\t\t\t32
""",
    ],
    PATHS[3]: [
        """#define ARM_CPU_PART_CORTEX_A76\t\t0xD0B
#define ARM_CPU_PART_NEOVERSE_N1\t0xD0C
#define ARM_CPU_PART_CORTEX_A77\t\t0xD0D
#define ARM_CPU_PART_NEOVERSE_V1\t0xD40
#define ARM_CPU_PART_CORTEX_A78\t\t0xD41
#define ARM_CPU_PART_CORTEX_X1\t\t0xD44
#define ARM_CPU_PART_CORTEX_A710\t0xD47
#define ARM_CPU_PART_CORTEX_X2\t\t0xD48
#define ARM_CPU_PART_NEOVERSE_N2\t0xD49
#define ARM_CPU_PART_CORTEX_A78C\t0xD4B
#define ARM_CPU_PART_KRYO3S\t\t0x803
#define ARM_CPU_PART_KRYO4S\t\t0x803
#define ARM_CPU_PART_KRYO4G\t\t0x804
#define ARM_CPU_PART_KRYO2XX_GOLD\t0x800
#define ARM_CPU_PART_KRYO2XX_SILVER\t0x801
""",
        """#define MIDR_CORTEX_A76\tMIDR_CPU_MODEL(ARM_CPU_IMP_ARM, ARM_CPU_PART_CORTEX_A76)
#define MIDR_NEOVERSE_N1 MIDR_CPU_MODEL(ARM_CPU_IMP_ARM, ARM_CPU_PART_NEOVERSE_N1)
#define MIDR_CORTEX_A77\tMIDR_CPU_MODEL(ARM_CPU_IMP_ARM, ARM_CPU_PART_CORTEX_A77)
#define MIDR_NEOVERSE_V1\tMIDR_CPU_MODEL(ARM_CPU_IMP_ARM, ARM_CPU_PART_NEOVERSE_V1)
#define MIDR_CORTEX_A78\tMIDR_CPU_MODEL(ARM_CPU_IMP_ARM, ARM_CPU_PART_CORTEX_A78)
#define MIDR_CORTEX_X1\tMIDR_CPU_MODEL(ARM_CPU_IMP_ARM, ARM_CPU_PART_CORTEX_X1)
#define MIDR_CORTEX_A710 MIDR_CPU_MODEL(ARM_CPU_IMP_ARM, ARM_CPU_PART_CORTEX_A710)
#define MIDR_CORTEX_X2 MIDR_CPU_MODEL(ARM_CPU_IMP_ARM, ARM_CPU_PART_CORTEX_X2)
#define MIDR_NEOVERSE_N2 MIDR_CPU_MODEL(ARM_CPU_IMP_ARM, ARM_CPU_PART_NEOVERSE_N2)
#define MIDR_CORTEX_A78C\tMIDR_CPU_MODEL(ARM_CPU_IMP_ARM, ARM_CPU_PART_CORTEX_A78C)
#define MIDR_KRYO3S\tMIDR_CPU_MODEL(ARM_CPU_IMP_QCOM, ARM_CPU_PART_KRYO3S)
#define MIDR_KRYO4S\tMIDR_CPU_MODEL(ARM_CPU_IMP_QCOM, ARM_CPU_PART_KRYO4S)
#define MIDR_KRYO4G\tMIDR_CPU_MODEL(ARM_CPU_IMP_QCOM, ARM_CPU_PART_KRYO4G)
""",
    ],
    PATHS[4]: [
        """#ifdef CONFIG_ARM64_ERRATUM_1188873
\t{
\t\t/* Cortex-A76 r0p0 to r2p0 */
\t\t.desc = "ARM erratum 1188873",
\t\t.capability = ARM64_WORKAROUND_1188873,
\t\tERRATA_MIDR_RANGE(MIDR_CORTEX_A76, 0, 0, 2, 0),
\t},
\t{
\t\t/* Kryo-4G r15p14 through r15p15 */
\t\t.desc = "ARM erratum 1188873",
\t\t.capability = ARM64_WORKAROUND_1188873,
\t\tERRATA_MIDR_RANGE(MIDR_KRYO4G, 15, 14, 15, 15),
\t},
#endif
\t{
\t\t.desc = "Spectre-BHB",
\t\t.capability = ARM64_SPECTRE_BHB,
\t\t.type = ARM64_CPUCAP_LOCAL_CPU_ERRATUM,
\t\t.matches = is_spectre_bhb_affected,
\t\t.cpu_enable = spectre_bhb_enable_mitigation,
\t},
#ifdef CONFIG_ARM64_ERRATUM_1742098
\t{
\t\t.desc = "ARM erratum 1742098",
\t\t.capability = ARM64_WORKAROUND_1742098,
\t\tCAP_MIDR_RANGE_LIST(broken_aarch32_aes),
\t\t.type = ARM64_CPUCAP_LOCAL_CPU_ERRATUM,
\t},
#endif
"""
    ],
    PATHS[5]: [
        """\tint size;
\tvoid *dt_virt = fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL);
\tconst char *machine_name;
""",
        """\t/* Early fixups are done, map the FDT as read-only now. */
\tfixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL_RO);

\tmachine_name = arch_read_machine_name();
\tif (!machine_name)
""",
    ],
    PATHS[6]: [""],
}


def main() -> None:
    current = run("git", "rev-parse", "HEAD").decode().strip()
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", SCAFFOLD, current], check=False
    ).returncode:
        raise SystemExit(f"{SCAFFOLD} is not an ancestor of {current}")

    for path in PATHS:
        if subprocess.run(
            ["git", "diff", "--quiet", SCAFFOLD, "--", path], check=False
        ).returncode:
            raise SystemExit(f"owned path drifted after scaffold: {path}")

    base = run("git", "merge-base", PREPARATION_PARENT, TARGET).decode().strip()
    for path in PATHS:
        text = merge_preview(base, path)
        text = replace_conflicts(text, REPLACEMENTS[path], path)
        if path == "arch/arm64/kernel/setup.c":
            text = text.replace(
                "extern void *__init __fixmap_remap_fdt(phys_addr_t dt_phys, int *size,\n"
                "\t\t\t\t       pgprot_t prot);",
                "extern void *__init fixmap_remap_fdt(phys_addr_t dt_phys, int *size,\n"
                "\t\t\t\t     pgprot_t prot);",
            )
            text = text.replace(
                "__fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL)",
                "fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL)",
            )
            text = text.replace(
                "\tif (dt_virt)\n\t\tmemblock_reserve(dt_phys, size);",
                "\tif (dt_virt) {\n"
                "\t\tmemblock_reserve(dt_phys, size);\n"
                "\t\tpr_info(\"memblock_reserve: 0x%x %pS\\n\", size - 1,\n"
                "\t\t\t(void *)_RET_IP_);\n"
                "\t}",
            )
        if any(marker in text for marker in ("<<<<<<<", "|||||||", ">>>>>>>")):
            raise SystemExit(f"unresolved merge marker remains in {path}")
        destination = Path(path)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text)

    cpucaps = Path("arch/arm64/include/asm/cpucaps.h").read_text()
    caps = re.findall(r"^#define\s+(ARM64_[A-Z0-9_]+)\s+(\d+)\s*$", cpucaps, re.MULTILINE)
    values: dict[int, list[str]] = {}
    for name, value in caps:
        values.setdefault(int(value), []).append(name)
    duplicates = {value: names for value, names in values.items() if len(names) > 1}
    if duplicates:
        raise SystemExit(f"duplicate ARM64 capability values: {duplicates}")
    if "#define ARM64_NCAPS\t\t\t\t32" not in cpucaps:
        raise SystemExit("ARM64_NCAPS is not 32")

    patch = run("git", "diff", "--binary", SCAFFOLD, "--", *PATHS)
    digest = hashlib.sha256(patch).hexdigest()
    if digest != EXPECTED_PATCH_SHA256:
        raise SystemExit(
            f"audited ARM64 patch identity mismatch: got {digest}, "
            f"expected {EXPECTED_PATCH_SHA256}"
        )
    Path("lts305-arm64-resolution.patch").write_bytes(patch)
    print(f"resolved_paths={len(PATHS)}")
    print(f"merge_base={base}")
    print(f"patch_sha256={digest}")


if __name__ == "__main__":
    try:
        main()
    except BaseException as exc:
        diagnostic = Path("lts305-arm64-resolution")
        diagnostic.mkdir(parents=True, exist_ok=True)
        (diagnostic / "resolver-error.txt").write_text(f"{type(exc).__name__}: {exc}\n")
        raise
