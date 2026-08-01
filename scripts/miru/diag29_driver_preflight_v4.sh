#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
from pathlib import Path

path = Path('scripts/miru/diag29_build.sh')
text = path.read_text()

if text.count('set -Eeuo pipefail') != 1:
    raise SystemExit('unexpected shell option header')
text = text.replace('set -Eeuo pipefail', 'set -Eeuxo pipefail', 1)

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

# Patch the generated build driver immediately after its normal transformation.
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

# Run the generated driver through the full source sanity gate only.
compile_block = """trap - ERR
set +e
export GITHUB_WORKSPACE=\"${ROOT}\"
bash scripts/miru/ci_build_4.14.190.sh
COMPILE_EXIT=$?
set -e
trap 'on_error ${LINENO}' ERR
"""
driver_preflight = """python3 - <<'DRIVERSTOP'
from pathlib import Path
p = Path('scripts/miru/ci_build_4.14.190.sh')
s = p.read_text()
anchor = \"# GitHub's Ubuntu image contains most dependencies already; install the\\n\"
stop = 'echo \"DRIVER_SANITY_PASS\" | tee \"${DIAG_DIR}/driver-preflight-result.txt\"\\nexit 0\\n\\n'
if s.count(anchor) != 1:
    raise SystemExit('driver sanity-boundary anchor changed unexpectedly')
p.write_text(s.replace(anchor, stop + anchor, 1))
DRIVERSTOP

trap - ERR
set +e
export GITHUB_WORKSPACE=\"${ROOT}\"
bash scripts/miru/ci_build_4.14.190.sh
DRIVER_EXIT=$?
set -e
trap 'on_error ${LINENO}' ERR
test \"${DRIVER_EXIT}\" = 0
grep -Fq 'Sanity gate: PASS' build-diagnostics/sanity-summary.txt
grep -Fq 'DRIVER_SANITY_PASS' build-diagnostics/driver-preflight-result.txt
{
  echo result=DRIVER_PREFLIGHT_PASS
  echo failure_stage=none
  echo local_source_commit=${SOURCE_COMMIT}
  echo kernel_version=4.14.292
  echo merge_conflicts=$(paste -sd, merge-conflicts.txt)
} | tee \"${RESULT}/SUMMARY.txt\" \"${FULL}/validation/SUMMARY.txt\"
echo DRIVER_PREFLIGHT_PASS > \"${RESULT}/RESULT\"
exit 0
"""
if text.count(compile_block) != 1:
    raise SystemExit('diag29 compile launch block changed unexpectedly')
text = text.replace(compile_block, driver_preflight, 1)

path.write_text(text)
PY

mkdir -p diagnostic-result full-artifact/validation
bash -n scripts/miru/diag29_build.sh
set +e
bash scripts/miru/diag29_build.sh
wrapper_rc=$?
set -e
printf 'wrapper_exit=%s\n' "${wrapper_rc}" | tee diagnostic-result/DRIVER-PREFLIGHT-WRAPPER.txt
result="$(cat diagnostic-result/RESULT 2>/dev/null || echo FAILURE)"
echo "driver_preflight_result=${result}"
cat diagnostic-result/SUMMARY.txt 2>/dev/null || true
exit 0
