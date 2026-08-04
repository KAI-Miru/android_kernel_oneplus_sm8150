#!/usr/bin/env bash
set -Eeuo pipefail

source_script="scripts/miru/lts357/compile_checkpoint_340_344.sh"
patched="${RUNNER_TEMP}/compile-checkpoint-348.sh"
python3 - "${source_script}" "${patched}" <<'PY'
from pathlib import Path
import sys
src, dst = map(Path, sys.argv[1:])
text = src.read_text()

old_inputs = '''STAGE340=e714dcc91781cc51118b3761d5be1b74645cd9af
STAGE344=4ca04340dfd5abd1b7e4d9b72c3f9223331cd118
OPENELA340=9b7ef2749ffa187d86acd0033327338c0fc299bf
OPENELA344=7a22fc46cc7a72d72b6dfdcbbc46e18c9f2caab0
'''
new_inputs = '''STAGE348=2be978e53f5bddc97eb1ebc2a8da987b1c762b1f
OPENELA348=ef4cb0aa8addc73e6257039a17061cb1766b7477
'''
if text.count(old_inputs) != 1:
    raise SystemExit("checkpoint input block missing or duplicated")
text = text.replace(old_inputs, new_inputs, 1)

compiler_anchor = '''    "REAL_CC=${CLANG_DIR}/bin/clang" CLANG_TRIPLE=aarch64-linux-gnu-
    "PYTHON=${AOSP_BUILD_TOOLS}/bin/py2-cmd" HOSTCC=gcc HOSTCXX=g++ LOCALVERSION=+
'''
compiler_replacement = '''    "REAL_CC=${CLANG_DIR}/bin/clang" CLANG_TRIPLE=aarch64-linux-gnu-
    "PYTHON=${AOSP_BUILD_TOOLS}/bin/py2-cmd"
    "CC=${AOSP_BUILD_TOOLS}/bin/py2-cmd ${kernel_dir}/scripts/gcc-wrapper.py ${CLANG_DIR}/bin/clang"
    HOSTCC=gcc HOSTCXX=g++ LOCALVERSION=+ V=1
'''
if text.count(compiler_anchor) != 1:
    raise SystemExit("compiler argument anchor missing or duplicated")
text = text.replace(compiler_anchor, compiler_replacement, 1)

old_topology = '''git merge-base --is-ancestor "${PRODUCTION}" "${STAGE340}"
git merge-base --is-ancestor "${STAGE340}" "${STAGE344}"
test "$(git rev-list --parents -n1 "${STAGE340}")" = "${STAGE340} $(git rev-list --parents -n1 "${STAGE340}" | awk '{print $2}') ${OPENELA340}"
test "$(git rev-list --parents -n1 "${STAGE344}")" = "${STAGE344} $(git rev-list --parents -n1 "${STAGE344}" | awk '{print $2}') ${OPENELA344}"
'''
new_topology = '''git merge-base --is-ancestor "${PRODUCTION}" "${STAGE348}"
test "$(git rev-list --parents -n1 "${STAGE348}")" = "${STAGE348} $(git rev-list --parents -n1 "${STAGE348}" | awk '{print $2}') ${OPENELA348}"
'''
if text.count(old_topology) != 1:
    raise SystemExit("checkpoint topology block missing or duplicated")
text = text.replace(old_topology, new_topology, 1)

anchor = '''  make -C "${kernel_dir}" "${make_args[@]}" olddefconfig prepare modules_prepare

  for target in "$@"; do
'''
replacement = '''  compiler_probe="${RUNNER_TEMP}/${label}-stackprotector.o"
  "${AOSP_BUILD_TOOLS}/bin/py2-cmd" \
    "${kernel_dir}/scripts/gcc-wrapper.py" \
    "${CLANG_DIR}/bin/clang" \
    -Werror -fstack-protector-strong -c -x c /dev/null \
    -o "${compiler_probe}"
  test -s "${compiler_probe}"
  rm -f "${compiler_probe}"
  printf 'checkpoint_compiler label=%s cc=%s wrapper=%s\\n' \
    "${label}" "${CLANG_DIR}/bin/clang" "${kernel_dir}/scripts/gcc-wrapper.py"

  make -C "${kernel_dir}" "${make_args[@]}" olddefconfig prepare modules_prepare

  grep -Fq '# CONFIG_MEMORY_FAILURE is not set' "${out_dir}/.config" || {
    echo 'stage348: CONFIG_MEMORY_FAILURE boundary mismatch' >&2
    exit 1
  }
  grep -Fq 'try_to_unmap(hpage, ttu, NULL)' "${kernel_dir}/mm/memory-failure.c" || {
    echo 'stage348: huge-page-head unmap fix missing' >&2
    exit 1
  }
  if grep -Fq 'try_to_unmap(p, ttu, NULL)' "${kernel_dir}/mm/memory-failure.c"; then
    echo 'stage348: poisoned-tail unmap remains' >&2
    exit 1
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

  version="$(sed -n 's/^VERSION = //p' "${kernel_dir}/Makefile" | head -n1)"
  patchlevel="$(sed -n 's/^PATCHLEVEL = //p' "${kernel_dir}/Makefile" | head -n1)"
  makefile_sublevel="$(sed -n 's/^SUBLEVEL = //p' "${kernel_dir}/Makefile" | head -n1)"
  extraversion="$(sed -n 's/^EXTRAVERSION = //p' "${kernel_dir}/Makefile" | head -n1)"
  config_localversion="$(sed -n 's/^CONFIG_LOCALVERSION=//p' "${out_dir}/.config" | head -n1 | tr -d '\"')"
  expected_localversion="-${localversion}"
  expected_release="${version}.${patchlevel}.${makefile_sublevel}${extraversion}${expected_localversion}+"
  release_file="$(cat "${out_dir}/include/config/kernel.release")"
  release_make="$(make -s -C "${kernel_dir}" "${make_args[@]}" kernelrelease)"
  printf 'checkpoint_release label=%s config=%s file=%s make=%s expected=%s\\n' \
    "${label}" "${config_localversion}" "${release_file}" "${release_make}" "${expected_release}"
  if [[ "${makefile_sublevel}" != "${sublevel}" ]]; then
    echo "checkpoint_makefile_sublevel_mismatch=${label}:${makefile_sublevel}:${sublevel}" >&2
    exit 1
  fi
  if [[ "${config_localversion}" != "${expected_localversion}" ]]; then
    echo "checkpoint_config_localversion_mismatch=${label}:${config_localversion}:${expected_localversion}" >&2
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

old_tail = '''compile_stage stage340 "${STAGE340}" 340 miru-h40-lts340-stage1 \\
  drivers/android/binder_alloc.o \\
  fs/aio.o fs/f2fs/namei.o mm/memory-failure.o mm/swap.o \\
  drivers/usb/dwc3/gadget.o net/qrtr/qrtr.o

compile_stage stage344 "${STAGE344}" 344 miru-h40-lts344-stage2 \\
  drivers/android/binder.o fs/select.o net/ipv4/sysctl_net_ipv4.o \\
  net/ipv4/tcp_ipv4.o net/netfilter/xt_owner.o sound/usb/stream.o \\
  drivers/usb/dwc3/gadget.o net/qrtr/qrtr.o

{
  echo result=PASS
  echo stage340=${STAGE340}
  echo stage344=${STAGE344}
  echo modules_sha=${MODULES_SHA}
  echo clang_commit=252aba16f513a857bc923172f67b0e55e23de35f
  echo production_write=NONE
} | tee "${REPORT_ROOT}/SUMMARY.txt"
'''
new_tail = '''compile_stage stage348 "${STAGE348}" 348 miru-h40-lts348-stage3 \\
  fs/aio.o mm/page_alloc.o net/core/filter.o \\
  drivers/usb/dwc3/gadget.o net/qrtr/qrtr.o

{
  echo result=PASS
  echo stage348=${STAGE348}
  echo modules_sha=${MODULES_SHA}
  echo clang_commit=252aba16f513a857bc923172f67b0e55e23de35f
  echo production_write=NONE
} | tee "${REPORT_ROOT}/SUMMARY.txt"
'''
if text.count(old_tail) != 1:
    raise SystemExit("checkpoint invocation tail missing or duplicated")
text = text.replace(old_tail, new_tail, 1)
text = text.replace(
    'REPORT_ROOT="${GITHUB_WORKSPACE}/integration-evidence/compile-checkpoints-340-344"',
    'REPORT_ROOT="${GITHUB_WORKSPACE}/integration-evidence/compile-checkpoint-348"',
    1,
)
dst.write_text(text)
PY
chmod +x "${patched}"
bash -n "${patched}"
exec bash "${patched}"
