#!/usr/bin/env bash
set -Eeuo pipefail

source_script=scripts/miru/lts357/run_compile_checkpoint_356.sh
patched_script="${RUNNER_TEMP}/run_compile_checkpoint_356_v2.sh"

python3 - "${source_script}" "${patched_script}" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = """inode = Path('fs/f2fs/inode.c').read_text()
new = inode.index('if (is_inode_flag_set(inode, FI_NEW_INODE))')
ro = inode.index('if (f2fs_readonly(F2FS_I_SB(inode)->sb))', new)
dirty = inode.index('if (!is_inode_flag_set(inode, FI_DIRTY_INODE))', ro)
assert new < ro < dirty
"""
new = """inode = Path('fs/f2fs/inode.c').read_text()
start = inode.index('void f2fs_mark_inode_dirty_sync')
new_inode = inode.index('if (is_inode_flag_set(inode, FI_NEW_INODE))', start)
readonly = inode.index('if (f2fs_readonly(F2FS_I_SB(inode)->sb))', new_inode)
dirtied = inode.index('if (f2fs_inode_dirtied(inode, sync))', readonly)
mark_dirty = inode.index('mark_inode_dirty_sync(inode);', dirtied)
assert start < new_inode < readonly < dirtied < mark_dirty
"""
if source.count(old) != 1:
    raise SystemExit(f"checkpoint semantic-gate anchor count: {source.count(old)}")
Path(sys.argv[2]).write_text(source.replace(old, new))
PY

bash -n "${patched_script}"
exec bash "${patched_script}"
