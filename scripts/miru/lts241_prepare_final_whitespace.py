from pathlib import Path

path = Path('scripts/miru/lts241_targeted_integration.sh')
text = path.read_text()
marker = r'''printf '%s\n' "${RECORDS[@]}" > "${DIAG}/resolution-commits.txt"

export LEDGER_PATH="${KERNEL_WORKTREE}/Documentation/miru/lts-4.14.241-conflicts.md"
'''
replacement = r'''printf '%s\n' "${RECORDS[@]}" > "${DIAG}/resolution-commits.txt"

LPFC_PATH="drivers/scsi/lpfc/lpfc_mbox.c"
python3 - "${KERNEL_WORKTREE}/${LPFC_PATH}" <<'PYLPFC'
from pathlib import Path
import sys

path = Path(sys.argv[1])
data = path.read_bytes()
if not data.endswith(b'\n\n') or data.endswith(b'\n\n\n'):
    raise SystemExit('LPFC EOF whitespace collision not found exactly once')
path.write_bytes(data[:-1])
PYLPFC
git -C "${KERNEL_WORKTREE}" add -- "${LPFC_PATH}"
git -C "${KERNEL_WORKTREE}" diff --cached --check
git -C "${KERNEL_WORKTREE}" commit -m 'lts: clean up LPFC merge whitespace for 4.14.241'
LPFC_AUDIT_COMMIT="$(git -C "${KERNEL_WORKTREE}" rev-parse HEAD)"
LPFC_WT="${REVERSE_ROOT}/lpfc-clean"
git -C "${KERNEL_WORKTREE}" worktree add --detach "${LPFC_WT}" "${LPFC_AUDIT_COMMIT}"
git -C "${LPFC_WT}" revert --no-commit "${LPFC_AUDIT_COMMIT}"
git -C "${LPFC_WT}" diff --exit-code "${SCAFFOLD}" -- "${LPFC_PATH}" \
  > "${DIAG}/reversal-lpfc-clean.diff"
git -C "${LPFC_WT}" revert --abort 2>/dev/null || true
git -C "${KERNEL_WORKTREE}" worktree remove --force "${LPFC_WT}"
echo PASS > "${DIAG}/reversal-lpfc-clean.txt"
compile_targets lpfc-clean "drivers/scsi/lpfc/lpfc_mbox.o"
{
  echo
  echo '### Clean-merge audit: LPFC mailbox EOF whitespace'
  echo
  echo "- Owning commit: \`${LPFC_AUDIT_COMMIT}\`"
  echo '- Source: `drivers/scsi/lpfc/lpfc_mbox.c`'
  echo '- Decision: remove one Android Common-introduced blank line at EOF so the strict repository-wide `git diff --check` gate remains clean.'
  echo '- Targeted compilation: `drivers/scsi/lpfc/lpfc_mbox.o` PASS.'
  echo '- Clean reversal to scaffold state: PASS.'
} >> "${KERNEL_WORKTREE}/Documentation/miru/lts-4.14.241-conflicts.md"
echo "lpfc_clean_merge_commit=${LPFC_AUDIT_COMMIT}" > "${DIAG}/lpfc-clean-merge.txt"

export LEDGER_PATH="${KERNEL_WORKTREE}/Documentation/miru/lts-4.14.241-conflicts.md"
'''
if text.count(marker) != 1:
    raise SystemExit('missing post-resolution ledger marker')
updated = text.replace(marker, replacement, 1)
if updated.count('LPFC_PATH="drivers/scsi/lpfc/lpfc_mbox.c"') != 1:
    raise SystemExit('LPFC audit insertion did not occur exactly once')
path.write_text(updated)
