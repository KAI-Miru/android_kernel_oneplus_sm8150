#!/usr/bin/env bash
set -Eeuo pipefail

TMP_DRIVER="$(mktemp)"
trap 'rm -f "${TMP_DRIVER}"' EXIT

python3 - "${TMP_DRIVER}" <<'PY'
from pathlib import Path
import sys

source = Path('scripts/miru/lts305_apply_mailbox_resolution.sh').read_text()
old_show = '''git show --format= -- "${TARGET_FIX}" -- "${OWNED_PATH}" "${HEADER_PATH}" \\
  > "${DIAG}/target-fix.patch"'''
new_show = '''git show --format= "${TARGET_FIX}" -- "${OWNED_PATH}" "${HEADER_PATH}" \\
  > "${DIAG}/target-fix.patch"'''
old_gate = '''git merge-base --is-ancestor "${TARGET_FIX}" "${TARGET_COMMIT}"
git show --format=fuller --stat "${TARGET_FIX}" > "${DIAG}/target-fix.txt"'''
new_gate = '''git merge-base --is-ancestor "${TARGET_FIX}" "${TARGET_COMMIT}"
git show -s --format=%B "${TARGET_FIX}" | grep -Fq "${UPSTREAM_FIX}"
git show --format=fuller --stat "${TARGET_FIX}" > "${DIAG}/target-fix.txt"'''

if source.count(old_show) != 1:
    raise SystemExit('missing unique mailbox target-patch command')
if source.count(old_gate) != 1:
    raise SystemExit('missing unique mailbox target-history gate')
source = source.replace(old_show, new_show, 1)
source = source.replace(old_gate, new_gate, 1)
Path(sys.argv[1]).write_text(source)
PY

bash -n "${TMP_DRIVER}"
bash "${TMP_DRIVER}"
