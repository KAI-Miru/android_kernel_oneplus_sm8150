#!/usr/bin/env bash
set -Eeuo pipefail

source_script=scripts/miru/lts357/run_compile_checkpoint_356.sh
patched_script="${RUNNER_TEMP}/run_compile_checkpoint_357_generated.sh"

python3 - "${source_script}" "${patched_script}" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()

replacements = {
    "OPENELA356=a76b6a6556353484f6f29572989cd37b6cff90cc":
        "OPENELA357=1e6347375d088ecc896aabb067131d0f9e3c0575",
    'STAGE356_MERGE="${STAGE356_MERGE:?STAGE356_MERGE is required}"':
        'STAGE357_MERGE="${STAGE357_MERGE:?STAGE357_MERGE is required}"',
    "compile-checkpoint-356": "compile-checkpoint-357",
    "miru-toolchains-356": "miru-toolchains-357",
    "miru-vendor-source-356": "miru-vendor-source-357",
    "android-stage356": "android-stage357",
    "4.14.356-openela-miru-h40-lts356-stage5+":
        "4.14.357-openela-miru-h40-lts357-stage6+",
    "-miru-h40-lts356-stage5": "-miru-h40-lts357-stage6",
    'test "$(sed -n \'s/^SUBLEVEL = //p\' Makefile | head -n1)" = 356':
        'test "$(sed -n \'s/^SUBLEVEL = //p\' Makefile | head -n1)" = 357',
}
for old, new in replacements.items():
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"stage357 replacement anchor count for {old!r}: {count}")
    source = source.replace(old, new)

source = source.replace("STAGE356_MERGE", "STAGE357_MERGE")
source = source.replace("OPENELA356", "OPENELA357")
source = source.replace("stage356_merge", "stage357_merge")

old_f2fs = '''inode = Path('fs/f2fs/inode.c').read_text()
new = inode.index('if (is_inode_flag_set(inode, FI_NEW_INODE))')
ro = inode.index('if (f2fs_readonly(F2FS_I_SB(inode)->sb))', new)
dirty = inode.index('if (!is_inode_flag_set(inode, FI_DIRTY_INODE))', ro)
assert new < ro < dirty
'''
new_f2fs = '''inode = Path('fs/f2fs/inode.c').read_text()
start = inode.index('void f2fs_mark_inode_dirty_sync')
new_inode = inode.index('if (is_inode_flag_set(inode, FI_NEW_INODE))', start)
readonly = inode.index('if (f2fs_readonly(F2FS_I_SB(inode)->sb))', new_inode)
dirtied = inode.index('if (f2fs_inode_dirtied(inode, sync))', readonly)
mark_dirty = inode.index('mark_inode_dirty_sync(inode);', dirtied)
assert start < new_inode < readonly < dirtied < mark_dirty
'''
if source.count(old_f2fs) != 1:
    raise SystemExit("stage357 F2FS semantic-gate anchor missing")
source = source.replace(old_f2fs, new_f2fs)

anchor = 'STAGE352_MERGE=f5ebecc06992d60f50c21ebf9e9dc0538fa7b1c3\n'
insert = anchor + 'VALIDATED_STAGE356_MERGE=921ac6a9195cdb3192cddaebb3fe2b4597e11f9c\n'
if source.count(anchor) != 1:
    raise SystemExit("stage357 validated-stage356 variable anchor missing")
source = source.replace(anchor, insert)

anchor = 'ARM_OUT="${ANDROID_ROOT}/out/arm-uaccess"\n'
insert = anchor + 'IMA_OUT="${ANDROID_ROOT}/out/ima-probe"\n'
if source.count(anchor) != 1:
    raise SystemExit("stage357 IMA output anchor missing")
source = source.replace(anchor, insert)

anchor = 'git merge-base --is-ancestor "${STAGE352_MERGE}" "${STAGE357_MERGE}"\n'
insert = anchor + 'git merge-base --is-ancestor "${VALIDATED_STAGE356_MERGE}" "${STAGE357_MERGE}"\n'
if source.count(anchor) != 1:
    raise SystemExit("stage357 ancestry anchor missing")
source = source.replace(anchor, insert)

anchor = 'mkdir -p "${ANDROID_ROOT}/kernel" "${ANDROID_ROOT}/vendor" "${OUT_DIR}" "${ARM_OUT}"\n'
insert = anchor + 'mkdir -p "${IMA_OUT}"\n'
if source.count(anchor) != 1:
    raise SystemExit("stage357 IMA directory anchor missing")
source = source.replace(anchor, insert)

anchor = '  drivers/clk/clk-devres.o\n'
extra_targets = '''  drivers/clk/clk-devres.o
  fs/ocfs2/quota_global.o
  fs/ocfs2/quota_local.o
  net/core/sock.o
  net/ipv4/inet_fragment.o
  net/ipv4/ip_fragment.o
  net/ipv6/netfilter/nf_conntrack_reasm.o
'''
if source.count(anchor) != 1:
    raise SystemExit("stage357 target-list anchor missing")
source = source.replace(anchor, extra_targets)

anchor = 'checkpoint_step install-host-dependencies\n'
semantic = r'''checkpoint_step verify-stage357-clean-merge-semantics
test "$(sed -n 's/^version: //p' .elts/config.yaml)" = 4.14.357
grep -Fq 'static inline bool is_skb_wmem' net/core/sock_destructor.h
grep -Fq 'clk_get_optional' drivers/clk/clk-devres.c
grep -Fq 'inet_frag' net/ipv4/inet_fragment.c
grep -Fq 'ip_defrag' net/ipv4/ip_fragment.c
grep -Fq 'nf_ct_frag6' net/ipv6/netfilter/nf_conntrack_reasm.c
grep -Fq 'CONFIG_IMA_MEASURE_PCR_IDX' security/integrity/ima/ima_api.c
grep -Fq 'ima_' security/integrity/ima/ima_template_lib.c

checkpoint_step install-host-dependencies
'''
if source.count(anchor) != 1:
    raise SystemExit("stage357 semantic-gate insertion anchor missing")
source = source.replace(anchor, semantic)

anchor = 'checkpoint_step compile-controlled-arm32-uaccess-probe\n'
ima_probe = r'''checkpoint_step compile-controlled-ima-probe
grep -qx '# CONFIG_IMA is not set' "${OUT_DIR}/.config"
cp "${OUT_DIR}/.config" "${IMA_OUT}/.config"
ima_make_args=("${make_args[@]}")
ima_make_args[0]="O=${IMA_OUT}"
"${KERNEL_DIR}/scripts/config" --file "${IMA_OUT}/.config" --enable IMA
"${KERNEL_DIR}/scripts/config" --file "${IMA_OUT}/.config" --set-val IMA_MEASURE_PCR_IDX 10
make -C "${KERNEL_DIR}" "${ima_make_args[@]}" olddefconfig prepare modules_prepare
grep -qx 'CONFIG_IMA=y' "${IMA_OUT}/.config"
grep -qx 'CONFIG_IMA_MEASURE_PCR_IDX=10' "${IMA_OUT}/.config"
ima_probe_targets=(
  security/integrity/ima/ima_api.o
  security/integrity/ima/ima_template_lib.o
)
for target in "${ima_probe_targets[@]}"; do
  echo "ima_probe_target_start=${target}"
  make -C "${KERNEL_DIR}" -j4 "${ima_make_args[@]}" "${target}"
  test -s "${IMA_OUT}/${target}"
  echo "ima_probe_target_pass=${target}"
done

checkpoint_step compile-controlled-arm32-uaccess-probe
'''
if source.count(anchor) != 1:
    raise SystemExit("stage357 IMA probe insertion anchor missing")
source = source.replace(anchor, ima_probe)

anchor = '  echo "arm_probe=${arm_probe}"\n  printf \'built_target=%s\\n\' "${built_targets[@]}"\n'
insert = '  echo "arm_probe=${arm_probe}"\n  printf \'ima_probe_target=%s\\n\' "${ima_probe_targets[@]}"\n  printf \'built_target=%s\\n\' "${built_targets[@]}"\n'
if source.count(anchor) != 1:
    raise SystemExit("stage357 summary IMA probe anchor missing")
source = source.replace(anchor, insert)

anchor = '  "${OUT_DIR}/include/config/kernel.release" \\\n  "${ARM_OUT}/arch/arm/lib/uaccess_with_memcpy.o" \\\n'
insert = '  "${OUT_DIR}/include/config/kernel.release" \\\n  "${IMA_OUT}/.config" \\\n  "${IMA_OUT}/security/integrity/ima/ima_api.o" \\\n  "${IMA_OUT}/security/integrity/ima/ima_template_lib.o" \\\n  "${ARM_OUT}/arch/arm/lib/uaccess_with_memcpy.o" \\\n'
if source.count(anchor) != 1:
    raise SystemExit("stage357 checksum IMA probe anchor missing")
source = source.replace(anchor, insert)

for stale in (
    "OPENELA356", '${STAGE356_MERGE}', "stage356_merge",
    "compile-checkpoint-356", "android-stage356", "lts356-stage5",
):
    if stale in source:
        raise SystemExit(f"stale stage356 identifier remains: {stale}")

Path(sys.argv[2]).write_text(source)
PY

bash -n "${patched_script}"
if [[ "${STAGE357_GENERATE_ONLY:-0}" == 1 ]]; then
  exit 0
fi
exec bash "${patched_script}"
