#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
from pathlib import Path

path = Path('scripts/miru/diag29_build.sh')
text = path.read_text()

# Make every command visible in the PR-readable job log.
text = text.replace('set -Eeuo pipefail', 'set -Eeuxo pipefail', 1)

# Accept both valid states after taking the downstream side of the two known
# conflicts: the one-argument wrapper may exist and need removal, or the merge
# may already have removed it cleanly.
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
    raise SystemExit('FDT normalization gate changed unexpectedly')
text = text.replace(old_count, new_count, 1)

# Correct the already-absolute compact output path.
old_zip = '(cd "${COMPACT_DIR}" && zip -9 -q "${ROOT}/${COMPACT_ZIP}" ./*)'
new_zip = '(cd "${COMPACT_DIR}" && zip -9 -q "${COMPACT_ZIP}" ./*)'
if text.count(old_zip) != 1:
    raise SystemExit('compact ZIP command changed unexpectedly')
text = text.replace(old_zip, new_zip, 1)

# Stop only after all source merge, semantic resolution, commit validation,
# compatibility-script preparation, and build-driver transformation gates pass.
anchor = """trap - ERR
set +e
export GITHUB_WORKSPACE=\"${ROOT}\"
bash scripts/miru/ci_build_4.14.190.sh
COMPILE_EXIT=$?
set -e
trap 'on_error ${LINENO}' ERR
"""
replacement = """{
  echo result=PREBUILD_PASS
  echo failure_stage=none
  echo local_source_commit=${SOURCE_COMMIT}
  echo kernel_version=4.14.292
} | tee \"${RESULT}/SUMMARY.txt\" \"${FULL}/validation/SUMMARY.txt\"
echo PREBUILD_PASS > \"${RESULT}/RESULT\"
exit 0
"""
if text.count(anchor) != 1:
    raise SystemExit('compile launch anchor changed unexpectedly')
text = text.replace(anchor, replacement, 1)

path.write_text(text)
PY

mkdir -p diagnostic-result full-artifact/validation
bash -n scripts/miru/diag29_build.sh
set +e
bash scripts/miru/diag29_build.sh
rc=$?
set -e
printf 'wrapper_exit=%s\n' "${rc}" | tee diagnostic-result/PREFLIGHT-WRAPPER.txt
cat diagnostic-result/SUMMARY.txt 2>/dev/null || true
# The underlying diagnostic intentionally converts trapped failures into exit 0;
# the RESULT/SUMMARY files and full xtrace identify the exact failed gate.
exit 0
