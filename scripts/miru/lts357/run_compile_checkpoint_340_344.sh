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
  fs/aio.o fs/f2fs/namei.o \\
  drivers/usb/dwc3/gadget.o net/qrtr/qrtr.o
'''
if text.count(old) != 1:
    raise SystemExit("stage340 target block missing or duplicated")
text = text.replace(old, new, 1)

anchor = '''  make -C "${kernel_dir}" "${make_args[@]}" olddefconfig prepare modules_prepare

  for target in "$@"; do
'''
replacement = '''  make -C "${kernel_dir}" "${make_args[@]}" olddefconfig prepare modules_prepare

  if [[ "${label}" == stage340 ]]; then
    # The stock H.40 configuration excludes hibernation and hardware memory
    # failure. Those translation units are not production build targets.
    # Verify their reviewed source semantics and configuration boundaries
    # instead of forcing standalone objects with intentionally absent APIs.
    grep -Fq '# CONFIG_HIBERNATION is not set' "${out_dir}/.config"
    grep -Fq '#define PAGES_FOR_IO' "${kernel_dir}/kernel/power/power.h"
    grep -Fq 'required = PAGES_FOR_IO + nr_pages;' "${kernel_dir}/kernel/power/swap.c"

    grep -Fq '# CONFIG_MEMORY_FAILURE is not set' "${out_dir}/.config"
    grep -Fq 'try_to_unmap(hpage, ttu, NULL)' "${kernel_dir}/mm/memory-failure.c"
    if grep -Fq 'try_to_unmap(p, ttu, NULL)' "${kernel_dir}/mm/memory-failure.c"; then
      echo 'tail-page memory-failure unmap remains' >&2
      exit 1
    fi
  fi

  for target in "$@"; do
'''
if text.count(anchor) != 1:
    raise SystemExit("compile-stage configuration anchor missing or duplicated")
text = text.replace(anchor, replacement, 1)
dst.write_text(text)
PY
chmod +x "${patched}"
bash -n "${patched}"
exec bash "${patched}"
