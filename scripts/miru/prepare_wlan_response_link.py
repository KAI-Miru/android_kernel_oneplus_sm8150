#!/usr/bin/env python3

from pathlib import Path

SCRIPT = Path("scripts/miru/build_external_modules_4.14.190.sh")
text = SCRIPT.read_text()

anchor = '''# Qualcomm qcacld WLAN was already proven buildable directly with Kbuild in the
# source-completeness audit.  Rebuild it against the 4.14.190 output.
WLAN_ROOT="${WLAN_PARENT}/qcacld-3.0"
'''

injected = '''# Qualcomm qcacld contains several thousand objects.  Expanding all paths on
# the final ld command exceeds Linux ARG_MAX, so patch only the detached build
# worktree to write the composite object list with GNU make's file function and
# feed it to GNU ld through a response file.  The same response file is reused
# when recording the module's constituent objects.
python3 - "${KERNEL_DIR}/scripts/Makefile.build" \
  "${REPORT_DIR}/WLAN-RESPONSE-LINK.txt" <<'PY'
from pathlib import Path
import subprocess
import sys

path = Path(sys.argv[1])
report = Path(sys.argv[2])
expected = "74ce588c69513197a354ef0032c2145e91ee0641"
actual = subprocess.check_output(["git", "hash-object", str(path)], text=True).strip()
if actual != expected:
    raise SystemExit(f"Makefile.build changed: expected {expected}, found {actual}")

text = path.read_text()
old_link = "cmd_link_multi-link = $(LD) $(ld_flags) -r -o $@ $(link_multi_deps) $(cmd_secanalysis)"
new_link = "cmd_link_multi-link = $(file >$@.rsp,$(link_multi_deps)) $(LD) $(ld_flags) -r -o $@ @$@.rsp $(cmd_secanalysis)"
if text.count(old_link) != 1:
    raise SystemExit("composite link command missing or duplicated")
text = text.replace(old_link, new_link, 1)

old_meta = """$(multi-used-m): FORCE
\t$(call if_changed,link_multi-m)
\t@{ echo $(@:.o=.ko); echo $(link_multi_deps); \\
\t   $(cmd_undef_syms); } > $(MODVERDIR)/$(@F:.o=.mod)
"""
new_meta = """$(multi-used-m): FORCE
\t$(call if_changed,link_multi-m)
\t@{ echo $(@:.o=.ko); cat $@.rsp; \\
\t   $(cmd_undef_syms); } > $(MODVERDIR)/$(@F:.o=.mod)
"""
if text.count(old_meta) != 1:
    raise SystemExit("composite module metadata rule missing or duplicated")
text = text.replace(old_meta, new_meta, 1)
path.write_text(text)

report.write_text(
    "WLAN composite link response-file patch applied.\\n"
    f"original_blob={expected}\\n"
    f"patched_blob={subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()}\\n"
)
PY

# Qualcomm qcacld WLAN was already proven buildable directly with Kbuild in the
# source-completeness audit.  Rebuild it against the 4.14.190 output.
WLAN_ROOT="${WLAN_PARENT}/qcacld-3.0"
'''

if text.count(anchor) != 1:
    raise SystemExit("WLAN build insertion anchor missing or duplicated")
SCRIPT.write_text(text.replace(anchor, injected, 1))
print("WLAN response-file link preparation added to external-module builder.")
