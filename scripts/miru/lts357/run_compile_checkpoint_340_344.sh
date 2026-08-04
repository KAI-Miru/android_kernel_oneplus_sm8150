#!/usr/bin/env bash
set -Eeuo pipefail

source_script="scripts/miru/lts357/compile_checkpoint_340_344.sh"
patched="${RUNNER_TEMP}/compile-checkpoint-340-344.sh"
python3 - "${source_script}" "${patched}" <<'PY'
from pathlib import Path
import sys
src, dst = map(Path, sys.argv[1:])
text = src.read_text()
old = '''compile_stage stage340 "${STAGE340}" 340 miru-h40-lts340-stage1 \\
  drivers/android/binder_alloc.o \\
  fs/aio.o fs/f2fs/namei.o mm/memory-failure.o mm/swap.o \\
  drivers/usb/dwc3/gadget.o net/qrtr/qrtr.o
'''
new = '''compile_stage stage340 "${STAGE340}" 340 miru-h40-lts340-stage1 \\
  drivers/android/binder_alloc.o \\
  drivers/infiniband/ulp/srpt/ib_srpt.o \\
  fs/aio.o fs/f2fs/namei.o kernel/power/swap.o mm/memory-failure.o \\
  drivers/usb/dwc3/gadget.o net/qrtr/qrtr.o
'''
if text.count(old) != 1:
    raise SystemExit("stage340 target block missing or duplicated")
dst.write_text(text.replace(old, new, 1))
PY
chmod +x "${patched}"
bash -n "${patched}"
exec bash "${patched}"
