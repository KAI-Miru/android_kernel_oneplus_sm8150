from pathlib import Path

path = Path('scripts/miru/lts241_targeted_integration.sh')
text = path.read_text()

old_batch = (
    "selinux\tlts: resolve SELinux AVC conflict for 4.14.241\t"
    "security/selinux/avc.c\tsecurity/selinux/avc.o\t"
    "Retain the already-present __GFP_NOWARN allocation semantics using the target formatting."
)
new_batch = (
    "selinux\tlts: resolve SELinux AVC conflict for 4.14.241\t"
    "security/selinux/avc.c security/selinux/include/security.h\t"
    "security/selinux/avc.o\t"
    "Retain the already-present __GFP_NOWARN allocation semantics, and remove the clean-merge duplicate android_netlink_getneigh field while preserving both Android netlink policy capabilities."
)
if text.count(old_batch) != 1:
    raise SystemExit('missing SELinux batch declaration')
text = text.replace(old_batch, new_batch, 1)

old_loop = '''  for path in "${path_arr[@]}"; do
    if [[ "${path}" == fs/incfs/pseudo_files.c ]]; then
      rm -f "${KERNEL_WORKTREE}/${path}"
    else
      mkdir -p "${KERNEL_WORKTREE}/$(dirname "${path}")"
      cp "${RESOLVE_ROOT}/${path}" "${KERNEL_WORKTREE}/${path}"
    fi
  done
'''
new_loop = '''  for path in "${path_arr[@]}"; do
    if [[ "${path}" == fs/incfs/pseudo_files.c ]]; then
      rm -f "${KERNEL_WORKTREE}/${path}"
    elif [[ "${path}" == security/selinux/include/security.h ]]; then
      python3 - "${KERNEL_WORKTREE}/${path}" <<'PYSELINUX'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
duplicate = "\tbool android_netlink_getneigh;\n\tbool android_netlink_route;\n\tbool android_netlink_getneigh;\n"
resolved = "\tbool android_netlink_getneigh;\n\tbool android_netlink_route;\n"
if text.count(duplicate) != 1:
    raise SystemExit('SELinux clean-merge capability collision not found exactly once')
path.write_text(text.replace(duplicate, resolved, 1))
PYSELINUX
    else
      mkdir -p "${KERNEL_WORKTREE}/$(dirname "${path}")"
      cp "${RESOLVE_ROOT}/${path}" "${KERNEL_WORKTREE}/${path}"
    fi
  done
'''
if text.count(old_loop) != 1:
    raise SystemExit('missing post-preparation resolution loop')
text = text.replace(old_loop, new_loop, 1)
path.write_text(text)
