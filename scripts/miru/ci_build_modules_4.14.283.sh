#!/usr/bin/env bash
set -Eeuo pipefail

# Keep the already-reviewed module-only implementation immutable, then apply the
# narrowly-scoped audit correction in the CI worktree before executing it.
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
replacement = r'''python3 - "${REPORT_DIR}/Module.symvers.kernel-abi" "${OUT_DIR}/Module.symvers" \
  "${REPORT_DIR}/Module.symvers-extension-report.txt" <<'PY'
from pathlib import Path
import hashlib
import sys

prior_path, current_path, report_path = map(Path, sys.argv[1:])
prior = prior_path.read_text().splitlines()
current = current_path.read_text().splitlines()
missing = sorted(set(prior) - set(current))
extra_count = len(set(current) - set(prior))
if missing:
    report_path.write_text(
        f'prior_entries={len(prior)}\ncurrent_entries={len(current)}\n'
        f'missing_entries={len(missing)}\nextra_entries={extra_count}\n'
        + '\n[MISSING]\n' + '\n'.join(missing) + '\n'
    )
    raise SystemExit('original kernel ABI entries were removed or changed')
report_path.write_text(
    f'kernel_abi_sha256={hashlib.sha256(prior_path.read_bytes()).hexdigest()}\n'
    f'extended_symvers_sha256={hashlib.sha256(current_path.read_bytes()).hexdigest()}\n'
    f'prior_entries={len(prior)}\ncurrent_entries={len(current)}\n'
    f'missing_entries=0\nextra_entries={extra_count}\n'
    'result=PASS\n'
)
PY

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
'''

patched = text[:start] + replacement + text[end:]
if patched == text:
    raise SystemExit('audit replacement did not change the script')
path.write_text(patched)
PY_PATCH

bash -n "${PATCHED_SCRIPT}"
exec bash "${PATCHED_SCRIPT}"
