#!/usr/bin/env python3
from pathlib import Path

path = Path("scripts/miru/diag29_build.sh")
text = path.read_text()

start_marker = "# Consolidate the low-level helper and remove the obsolete one-argument wrapper.\n"
if text.count(start_marker) != 1:
    raise SystemExit("diag29 FDT helper block marker changed unexpectedly")
start = text.index(start_marker)
end_marker = "p.write_text(s)\nPY\n\n"
end = text.find(end_marker, start)
if end < 0:
    raise SystemExit("diag29 FDT helper block end changed unexpectedly")
end += len("p.write_text(s)\n")

replacement = r'''# Preserve the downstream private helper used by parse_logical_bootcpu(), and
# convert only the obsolete one-argument public wrapper to the 4.14.292 API.
p = Path('arch/arm64/mm/mmu.c')
s = p.read_text()
private = 'void *__init __fixmap_remap_fdt(phys_addr_t dt_phys, int *size, pgprot_t prot)'
if s.count(private) != 1:
    raise SystemExit(f'unexpected private FDT helper count: {s.count(private)}')
pattern = re.compile(
    r'\nvoid \*__init fixmap_remap_fdt\(phys_addr_t dt_phys\)\n'
    r'\{\n.*?\n\}\n\n(?=int __init arch_ioremap_pud_supported)',
    re.S,
)
public_wrapper = (
    '\nvoid *__init fixmap_remap_fdt(phys_addr_t dt_phys, int *size, pgprot_t prot)\n'
    '{\n'
    '\treturn __fixmap_remap_fdt(dt_phys, size, prot);\n'
    '}\n\n'
)
s, count = pattern.subn(public_wrapper, s, count=1)
if count != 1:
    raise SystemExit(f'unexpected one-argument FDT wrapper count: {count}')
public = 'void *__init fixmap_remap_fdt(phys_addr_t dt_phys, int *size, pgprot_t prot)'
if s.count(private) != 1 or s.count(public) != 1:
    raise SystemExit('unexpected private/public FDT helper state')
if 'void *__init fixmap_remap_fdt(phys_addr_t dt_phys)\n' in s:
    raise SystemExit('obsolete one-argument FDT wrapper remains')
p.write_text(s)
'''
text = text[:start] + replacement + text[end:]

anchor = "grep -Fq 'machine_name = arch_read_machine_name();' arch/arm64/kernel/setup.c\n"
checks = anchor + (
    "grep -Fq 'fdt = __fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL);' arch/arm64/kernel/setup.c\n"
    "grep -Fq 'void *__init __fixmap_remap_fdt(phys_addr_t dt_phys, int *size, pgprot_t prot)' arch/arm64/mm/mmu.c\n"
    "grep -Fq 'return __fixmap_remap_fdt(dt_phys, size, prot);' arch/arm64/mm/mmu.c\n"
)
if text.count(anchor) != 1:
    raise SystemExit("diag29 post-merge FDT validation anchor changed unexpectedly")
text = text.replace(anchor, checks, 1)

path.write_text(text)
