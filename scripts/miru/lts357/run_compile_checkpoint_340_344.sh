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
    # Verify their reviewed stage-340 source semantics and configuration
    # boundaries instead of forcing objects with intentionally absent APIs.
    grep -Fq '# CONFIG_HIBERNATION is not set' "${out_dir}/.config" || {
      echo 'stage340: CONFIG_HIBERNATION boundary mismatch' >&2
      exit 1
    }
    grep -Fq '#define PAGES_FOR_IO' "${kernel_dir}/kernel/power/power.h" || {
      echo 'stage340: PAGES_FOR_IO definition missing' >&2
      exit 1
    }
    grep -Fq 'required = PAGES_FOR_IO + nr_pages;' "${kernel_dir}/kernel/power/swap.c" || {
      echo 'stage340: enough_swap accounting fix missing' >&2
      exit 1
    }

    grep -Fq '# CONFIG_MEMORY_FAILURE is not set' "${out_dir}/.config" || {
      echo 'stage340: CONFIG_MEMORY_FAILURE boundary mismatch' >&2
      exit 1
    }
    # OpenELA 4.14.340 intentionally still unmaps the poisoned subpage p.
    # The huge-page-head correction belongs to the later 4.14.348 stage.
    grep -Fq 'try_to_unmap(p, ttu, NULL)' "${kernel_dir}/mm/memory-failure.c" || {
      echo 'stage340: expected poisoned-subpage unmap is missing' >&2
      exit 1
    }
    if grep -Fq 'try_to_unmap(hpage, ttu, NULL)' "${kernel_dir}/mm/memory-failure.c"; then
      echo 'stage340: future 4.14.348 memory-failure semantic appeared too early' >&2
      exit 1
    fi
  fi

  for target in "$@"; do
'''
if text.count(anchor) != 1:
    raise SystemExit("compile-stage configuration anchor missing or duplicated")
text = text.replace(anchor, replacement, 1)

old_checks = '''  for target in "$@"; do
    make -C "${kernel_dir}" -j4 "${make_args[@]}" "${target}"
    test -s "${out_dir}/${target}"
  done

  release="$(make -s -C "${kernel_dir}" "${make_args[@]}" kernelrelease)"
  test "${release}" = "4.14.${sublevel}-${localversion}+"
'''
new_checks = '''  for target in "$@"; do
    echo "checkpoint_target_start=${label}:${target}"
    make -C "${kernel_dir}" -j4 "${make_args[@]}" "${target}"
    if [[ ! -s "${out_dir}/${target}" ]]; then
      echo "checkpoint_target_missing=${label}:${out_dir}/${target}" >&2
      exit 1
    fi
    echo "checkpoint_target_pass=${label}:${target}"
  done

  expected_release="4.14.${sublevel}-${localversion}+"
  config_release="$(sed -n 's/^CONFIG_LOCALVERSION=//p' "${out_dir}/.config" | head -n1)"
  release_file="$(cat "${out_dir}/include/config/kernel.release")"
  release_make="$(make -s -C "${kernel_dir}" "${make_args[@]}" kernelrelease)"
  printf 'checkpoint_release label=%s config=%s file=%s make=%s expected=%s\\n' \\
    "${label}" "${config_release}" "${release_file}" "${release_make}" "${expected_release}"
  if [[ "${config_release}" != "\"-${localversion}\"" ]]; then
    echo "checkpoint_config_localversion_mismatch=${label}" >&2
    exit 1
  fi
  if [[ "${release_file}" != "${expected_release}" || \
        "${release_make}" != "${expected_release}" ]]; then
    echo "checkpoint_kernel_release_mismatch=${label}" >&2
    exit 1
  fi
  release="${release_file}"
'''
if text.count(old_checks) != 1:
    raise SystemExit("compile-stage target/release block missing or duplicated")
text = text.replace(old_checks, new_checks, 1)
dst.write_text(text)
PY
chmod +x "${patched}"
bash -n "${patched}"
exec bash "${patched}"
