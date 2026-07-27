#!/usr/bin/env bash
set -Eeuo pipefail

TMP_DRIVER="$(mktemp)"
trap 'rm -f "${TMP_DRIVER}"' EXIT

python3 - "${TMP_DRIVER}" <<'PY'
from pathlib import Path
import sys

source = Path('scripts/miru/lts305_validate_pixel_clock_parity.sh').read_text()
old_tree = '''test "$(git -C "${REVERT_WORKTREE}" rev-parse "${REVERT_COMMIT}^{tree}")" = \\
     "$(git rev-parse "${SCAFFOLD}^{tree}")"'''
new_tree = '''test "$(git -C "${REVERT_WORKTREE}" rev-parse "${REVERT_COMMIT}^{tree}")" = \\
     "$(git rev-parse "${START_HEAD}^{tree}")"'''
old_record = '- Clean reversal: **PASS**; reverting the empty semantic commit in a disposable worktree preserved the owned path and restored the exact scaffold tree `{os.environ[\'SCAFFOLD\']}`.'
new_record = '- Clean reversal: **PASS**; reverting the empty semantic commit in a disposable worktree preserved the complete integration tree, while the owned path remained byte-identical to scaffold `{os.environ[\'SCAFFOLD\']}`.'

if source.count(old_tree) != 1:
    raise SystemExit('missing unique pixel-clock reversal tree gate')
if source.count(old_record) != 1:
    raise SystemExit('missing unique pixel-clock reversal ledger text')
source = source.replace(old_tree, new_tree, 1)
source = source.replace(old_record, new_record, 1)
Path(sys.argv[1]).write_text(source)
PY

bash "${TMP_DRIVER}"
