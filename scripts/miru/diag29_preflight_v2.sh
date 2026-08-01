#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
from pathlib import Path

path = Path('scripts/miru/diag29_build.sh')
text = path.read_text()

# Make the exact source/prebuild path visible in the PR-readable job log.
if text.count('set -Eeuo pipefail') != 1:
    raise SystemExit('unexpected shell option header')
text = text.replace('set -Eeuo pipefail', 'set -Eeuxo pipefail', 1)

# git merge validates committer identity even with --no-commit.
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

# After taking the downstream side of the two known conflicts, normalize the
# helper whether the obsolete wrapper remains or the merge removed it cleanly.
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

# Stop after every merge, semantic-resolution, source-validation and build-driver
# transformation gate has passed, immediately before actual compilation.
compile_block = """trap - ERR
set +e
export GITHUB_WORKSPACE=\"${ROOT}\"
bash scripts/miru/ci_build_4.14.190.sh
COMPILE_EXIT=$?
set -e
trap 'on_error ${LINENO}' ERR
"""
prebuild_pass = """{
  echo result=PREBUILD_PASS
  echo failure_stage=none
  echo local_source_commit=${SOURCE_COMMIT}
  echo kernel_version=4.14.292
  echo merge_conflicts=$(paste -sd, merge-conflicts.txt)
} | tee \"${RESULT}/SUMMARY.txt\" \"${FULL}/validation/SUMMARY.txt\"
echo PREBUILD_PASS > \"${RESULT}/RESULT\"
exit 0
"""
if text.count(compile_block) != 1:
    raise SystemExit('diag29 compile boundary changed unexpectedly')
text = text.replace(compile_block, prebuild_pass, 1)

path.write_text(text)
PY

mkdir -p diagnostic-result full-artifact/validation
bash -n scripts/miru/diag29_build.sh
set +e
bash scripts/miru/diag29_build.sh
wrapper_rc=$?
set -e
printf 'wrapper_exit=%s\n' "${wrapper_rc}" | tee diagnostic-result/PREFLIGHT-WRAPPER.txt
result="$(cat diagnostic-result/RESULT 2>/dev/null || echo FAILURE)"
echo "preflight_result=${result}"
cat diagnostic-result/SUMMARY.txt 2>/dev/null || true
exit 0
