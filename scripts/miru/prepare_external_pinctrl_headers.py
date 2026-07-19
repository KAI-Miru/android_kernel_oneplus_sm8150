#!/usr/bin/env python3

from pathlib import Path

SCRIPT = Path("scripts/miru/build_external_modules_4.14.190.sh")
text = SCRIPT.read_text()

anchor = '''  rsync -a --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \\
    --exclude='Module.symvers' --exclude='modules.order' \\
    "${source_dir}/" "${work}/"
  test -f "${kbuild}"
'''
replacement = '''  rsync -a --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \\
    --exclude='Module.symvers' --exclude='modules.order' \\
    "${source_dir}/" "${work}/"

  # pinctrl-wcd.c deliberately includes private pinctrl core headers by local
  # name. AndroidKernelModule.mk supplied the kernel source topology; recreate
  # only those two required headers in this isolated module workspace.
  if [[ "${source_rel}" == "soc" && "${target}" == "pinctrl_wcd_dlkm" ]]; then
    rm -f "${work}/core.h" "${work}/pinctrl-utils.h"
    cp -f "${KERNEL_DIR}/drivers/pinctrl/core.h" "${work}/core.h"
    cp -f "${KERNEL_DIR}/drivers/pinctrl/pinctrl-utils.h" "${work}/pinctrl-utils.h"
  fi

  test -f "${kbuild}"
'''

if text.count(anchor) != 1:
    raise SystemExit("isolated audio source-copy anchor missing or duplicated")
if "pinctrl-wcd.c deliberately includes private pinctrl core headers" in text:
    raise SystemExit("pinctrl header preparation already present")

SCRIPT.write_text(text.replace(anchor, replacement, 1))
print("External-module builder now supplies the two private pinctrl headers for audio_pinctrl_wcd.ko.")
