#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
from pathlib import Path

path = Path('scripts/miru/diag29_build.sh')
text = path.read_text()

# Configure the local merge identity before git merge --no-commit. Git prepares
# MERGE_MSG and validates committer identity even though the commit is delayed.
merge_anchor = """# Merge the complete Linux 4.14.292 endpoint. Only the ARM64 FDT transition is
# allowed to conflict; all other conflicts are rejected instead of guessed.
set +e
git merge --no-ff --no-commit \"${STABLE_292_SHA}\"
"""
merge_fixed = """# Merge the complete Linux 4.14.292 endpoint. Only the ARM64 FDT transition is
# allowed to conflict; all other conflicts are rejected instead of guessed.
git config user.name github-actions[bot]
git config user.email 41898282+github-actions[bot]@users.noreply.github.com
set +e
git merge --no-ff --no-commit \"${STABLE_292_SHA}\"
"""
if text.count(merge_anchor) != 1:
    raise SystemExit('diag29 merge anchor changed unexpectedly')
text = text.replace(merge_anchor, merge_fixed, 1)

# Accept both valid helper-normalization states after taking the downstream side
# of the two proven conflicts.
old_count = """if count != 1:
    raise SystemExit(f'unexpected one-argument FDT wrapper count: {count}')
needle = 'void *__init fixmap_remap_fdt(phys_addr_t dt_phys, int *size, pgprot_t prot)'
if s.count(needle) != 1 or '__fixmap_remap_fdt' in s:
    raise SystemExit('unexpected low-level FDT helper state')
"""
new_count = """if count == 0 and 'void *__init fixmap_remap_fdt(phys_addr_t dt_phys)\\n' in s:
    raise SystemExit('one-argument FDT wrapper remained after normalization')
needle = 'void *__init fixmap_remap_fdt(phys_addr_t dt_phys, int *size, pgprot_t prot)'
if (s.count(needle) != 1 or '__fixmap_remap_fdt' in s or
        'void *__init fixmap_remap_fdt(phys_addr_t dt_phys)\\n' in s):
    raise SystemExit('unexpected low-level FDT helper state')
"""
if text.count(old_count) != 1:
    raise SystemExit('diag29 FDT normalization gate changed unexpectedly')
text = text.replace(old_count, new_count, 1)

# COMPACT_ZIP is already absolute.
old_zip = '(cd "${COMPACT_DIR}" && zip -9 -q "${ROOT}/${COMPACT_ZIP}" ./*)'
new_zip = '(cd "${COMPACT_DIR}" && zip -9 -q "${COMPACT_ZIP}" ./*)'
if text.count(old_zip) != 1:
    raise SystemExit('diag29 compact ZIP command changed unexpectedly')
text = text.replace(old_zip, new_zip, 1)

path.write_text(text)
PY

bash -n scripts/miru/diag29_build.sh
grep -Fq 'git config user.name github-actions[bot]' scripts/miru/diag29_build.sh
grep -Fq 'git config user.email 41898282+github-actions[bot]@users.noreply.github.com' scripts/miru/diag29_build.sh
grep -Fq 'zip -9 -q "${COMPACT_ZIP}" ./*' scripts/miru/diag29_build.sh
! grep -Fq 'zip -9 -q "${ROOT}/${COMPACT_ZIP}"' scripts/miru/diag29_build.sh

exec bash scripts/miru/diag29_build.sh
