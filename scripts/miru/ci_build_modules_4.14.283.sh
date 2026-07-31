#!/usr/bin/env bash
set -Eeuo pipefail

# Execute the already-reviewed module-only implementation while replacing only
# its invalid post-modpost Module.symvers comparison. Individual module targets
# rewrite Module.symvers, so the exact full-kernel ABI file must be restored
# before external modules are built.
BASE_SCRIPT_COMMIT=96f00c1339b5f4731f610f1dcde5b8f6639c3fb2
SCRIPT_PATH=scripts/miru/ci_build_modules_4.14.283.sh
PATCHED_SCRIPT="${RUNNER_TEMP:?RUNNER_TEMP is required}/ci_build_modules_4.14.283.patched.sh"

git show "${BASE_SCRIPT_COMMIT}:${SCRIPT_PATH}" > "${PATCHED_SCRIPT}"

python3 - "${PATCHED_SCRIPT}" <<'PY_PATCH'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
start_marker = '''python3 - "${REPORT_DIR}/Module.symvers.kernel-abi" "${OUT_DIR}/Module.symvers" \\
  "${REPORT_DIR}/Module.symvers-extension-report.txt" <<'PY'\n'''
end_marker = '''\n\n"${KERNEL_DIR}/scripts/diffconfig"'''

start = text.index(start_marker)
end = text.index(end_marker, start)
replacement = r'''# Building selected module targets causes modpost to rewrite Module.symvers.
# Those six modules have no exports in the saved full-kernel ABI file, so keep
# their .ko outputs but restore the exact verified ABI before vendor DLKMs.
cp "${PRIOR_SYMVERS}" "${OUT_DIR}/Module.symvers"
printf '%s  %s\n' "${EXPECTED_SYMVERS_SHA}" "${OUT_DIR}/Module.symvers" | sha256sum -c -

cat > "${REPORT_DIR}/expected-in-tree-modules.txt" <<'EOF'
drivers/char/rdbg.ko
drivers/media/platform/msm/broadcast/tspp.ko
drivers/media/platform/msm/dvb/adapter/mpq-adapter.ko
drivers/media/platform/msm/dvb/demux/mpq-dmx-hw-plugin.ko
drivers/net/wireless/ath/wil6210/wil6210.ko
drivers/platform/msm/msm_11ad/msm_11ad_proxy.ko
EOF
find "${OUT_DIR}" -type f -name '*.ko' -printf '%P\n' | sort -u \
  > "${REPORT_DIR}/actual-in-tree-modules.txt"
cmp -s "${REPORT_DIR}/expected-in-tree-modules.txt" \
  "${REPORT_DIR}/actual-in-tree-modules.txt"

{
  echo "kernel_abi_sha256=${EXPECTED_SYMVERS_SHA}"
  echo post_module_symvers_restored=yes
  echo selected_in_tree_modules=6
  echo unexpected_in_tree_modules=0
  echo result=PASS
} > "${REPORT_DIR}/Module.symvers-extension-report.txt"
'''

patched = text[:start] + replacement + text[end:]
if patched == text:
    raise SystemExit('audit replacement did not change the script')
path.write_text(patched)
PY_PATCH

bash -n "${PATCHED_SCRIPT}"
exec bash "${PATCHED_SCRIPT}"
