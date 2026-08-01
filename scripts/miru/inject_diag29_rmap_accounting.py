#!/usr/bin/env python3
from pathlib import Path

path = Path("scripts/miru/diag29_build.sh")
text = path.read_text()
marker = "git add drivers/char/random.c\n"
if text.count(marker) != 1:
    raise SystemExit("diag29 RNG staging marker changed unexpectedly")

injected = r'''python3 - <<'INNER_RMAP_PY'
from pathlib import Path

path = Path('mm/rmap.c')
text = path.read_text()

old_condition = "\t\tif (!dst->anon_vma && anon_vma != src->anon_vma &&\n\t\t\t\tanon_vma->degree < 2)\n\t\t\tdst->anon_vma = anon_vma;"
new_condition = "\t\tif (!dst->anon_vma &&\n\t\t    anon_vma->num_children < 2 &&\n\t\t    anon_vma->num_active_vmas == 0)\n\t\t\tdst->anon_vma = anon_vma;"
if text.count(old_condition) != 1:
    raise SystemExit(f'unexpected Oplus degree condition count: {text.count(old_condition)}')
text = text.replace(old_condition, new_condition, 1)

old_increment = '\t\tdst->anon_vma->degree++;'
new_increment = '\t\tdst->anon_vma->num_active_vmas++;'
if text.count(old_increment) != 1:
    raise SystemExit(f'unexpected Oplus degree increment count: {text.count(old_increment)}')
text = text.replace(old_increment, new_increment, 1)

if 'anon_vma->degree' in text:
    raise SystemExit('stale anon_vma degree access remains')
if text.count('anon_vma->num_children < 2') != 2:
    raise SystemExit('standard and Oplus num_children reuse checks are not aligned')
if text.count('anon_vma->num_active_vmas == 0') != 2:
    raise SystemExit('standard and Oplus active-VMA reuse checks are not aligned')
if text.count('dst->anon_vma->num_active_vmas++;') != 2:
    raise SystemExit('standard and Oplus active-VMA increments are not aligned')

path.write_text(text)
INNER_RMAP_PY

grep -Fq 'anon_vma->num_children < 2' mm/rmap.c
grep -Fq 'anon_vma->num_active_vmas == 0' mm/rmap.c
test "$(grep -Fc 'dst->anon_vma->num_active_vmas++;' mm/rmap.c)" = 2
! grep -Fq 'anon_vma->degree' mm/rmap.c
git add drivers/char/random.c mm/rmap.c
'''

path.write_text(text.replace(marker, injected, 1))
