#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
from pathlib import Path

path = Path('scripts/miru/diag29_build.sh')
text = path.read_text()

merge_header = """# Merge the complete Linux 4.14.292 endpoint. Only the ARM64 FDT transition is
# allowed to conflict; all other conflicts are rejected instead of guessed.
set +e
git merge --no-ff --no-commit \"${STABLE_292_SHA}\"
merge_rc=$?
set -e
"""
merge_fixed = """# Merge the complete Linux 4.14.292 endpoint. Only the ARM64 FDT transition is
# allowed to conflict; all other conflicts are rejected instead of guessed.
git config user.name github-actions[bot]
git config user.email 41898282+github-actions[bot]@users.noreply.github.com
trap - ERR
set +e
git merge --no-ff --no-commit \"${STABLE_292_SHA}\"
merge_rc=$?
set -e
trap 'on_error ${LINENO}' ERR
"""
if text.count(merge_header) != 1:
    raise SystemExit('diag29 merge control-flow block changed unexpectedly')
text = text.replace(merge_header, merge_fixed, 1)

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

old_zip = '(cd "${COMPACT_DIR}" && zip -9 -q "${ROOT}/${COMPACT_ZIP}" ./*)'
new_zip = '(cd "${COMPACT_DIR}" && zip -9 -q "${COMPACT_ZIP}" ./*)'
if text.count(old_zip) != 1:
    raise SystemExit('diag29 compact ZIP command changed unexpectedly')
text = text.replace(old_zip, new_zip, 1)

# The new local merge commit is the object that must have stable 4.14.292 as
# its second parent. The old 4.14.291 source scaffold remains the diff baseline.
marker = '\nbash -n scripts/miru/ci_build_4.14.190.sh\n'
insertion = """
python3 - <<'DRIVERPY'
from pathlib import Path
p = Path('scripts/miru/ci_build_4.14.190.sh')
s = p.read_text()
old = 'git cat-file -p "${SCAFFOLD_SHA}" > "${DIAG_DIR}/merge-scaffold.txt"'
new = 'git cat-file -p HEAD > "${DIAG_DIR}/merge-scaffold.txt"'
if s.count(old) != 1:
    raise SystemExit('stale build-driver scaffold command changed unexpectedly')
p.write_text(s.replace(old, new, 1))
DRIVERPY

bash -n scripts/miru/ci_build_4.14.190.sh
"""
if text.count(marker) != 1:
    raise SystemExit('build-driver syntax-check marker changed unexpectedly')
text = text.replace(marker, '\n' + insertion, 1)

path.write_text(text)
PY

bash -n scripts/miru/diag29_build.sh
grep -Fq 'git cat-file -p HEAD > "${DIAG_DIR}/merge-scaffold.txt"' scripts/miru/diag29_build.sh
grep -Fq 'trap - ERR' scripts/miru/diag29_build.sh
grep -Fq 'zip -9 -q "${COMPACT_ZIP}" ./*' scripts/miru/diag29_build.sh

exec bash scripts/miru/diag29_build.sh
