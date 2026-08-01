#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE="scripts/miru/diag29_build_v5.sh"
TMP_SCRIPT="${RUNNER_TEMP:-/tmp}/diag29-build-v7-inner.sh"

last_line="$(tail -n 1 "${SOURCE}")"
test "${last_line}" = 'exec bash scripts/miru/diag29_build.sh'
sed '$d' "${SOURCE}" > "${TMP_SCRIPT}"
cat >> "${TMP_SCRIPT}" <<'EOF'
python3 scripts/miru/inject_diag29_rmap_accounting.py
python3 scripts/miru/inject_diag29_fdt_private_helper.py
bash -n scripts/miru/diag29_build.sh
grep -Fq "old_increment = '\t\tdst->anon_vma->degree++;'" scripts/miru/diag29_build.sh
grep -Fq 'Preserve the downstream private helper used by parse_logical_bootcpu()' scripts/miru/diag29_build.sh
grep -Fq 'return __fixmap_remap_fdt(dt_phys, size, prot);' scripts/miru/diag29_build.sh
exec bash scripts/miru/diag29_build.sh
EOF

bash -n "${TMP_SCRIPT}"
exec bash "${TMP_SCRIPT}"
