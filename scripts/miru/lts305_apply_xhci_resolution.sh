#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_COMMON_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
SCAFFOLD_PARENT1=b125a425ef1559871b1d6cd662806c8afc53e934
PREVIOUS_VALIDATED_HEAD=47ad9bf07920aaac24dc502d3221edb28bee88c4
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
OWNED_C=drivers/usb/host/xhci.c
OWNED_H=drivers/usb/host/xhci.h
HUB_PATH=drivers/usb/host/xhci-hub.c
# xhci-hcd.o is a composite Kbuild object and is not a direct top-level
# make target in this 4.14 tree.  Build its containing directory so Kbuild
# compiles the real consumers and links the composite object.
TARGET_DIRECTORY=drivers/usb/host/
TARGET_OBJECT=drivers/usb/host/xhci-hcd.o
VENDOR_SHA=125ff7d0153cbb3aaa8f9fd618c33b7f728d7798
EXPECTED_PREVIOUS_C_BLOB=98fbf396c10ec16cebc0ee6e3997f5bc0788bd15
EXPECTED_PREVIOUS_H_BLOB=300506de0c7a1eeda350478273deddcd2396d135
EXPECTED_SCAFFOLD_C_BLOB=0bcf825fe895b4a4eac13bd1e45d610876e6bae4
EXPECTED_SCAFFOLD_H_BLOB=4e3554115e1b0aa804d0d36d14b8121d537f5570
EXPECTED_TARGET_C_BLOB=0f2b67f38d2ea64ada356269e63c28e28f8e0bac
EXPECTED_TARGET_H_BLOB=7611fc893a0e14498bd033c5b0d77e89405d4f19
EXPECTED_SCAFFOLD_HUB_BLOB=2b9befbf41160f297ec06952130c2209fe6c4d99
DIAG=lts305-xhci-resolution

rm -rf "$DIAG"
mkdir -p "$DIAG"
trap 'rc=$?; { printf "exit=%s\\n" "$rc"; printf "line=%s\\n" "${BASH_LINENO[0]:-$LINENO}"; printf "command=%q\\n" "$BASH_COMMAND"; } > "$DIAG/failure.txt"; exit "$rc"' ERR
START_HEAD="$(git rev-parse HEAD)"
REMOTE_PRODUCTION="$(git ls-remote origin "refs/heads/$PRODUCTION_BRANCH" | awk '{print $1}')"
REMOTE_INTEGRATION="$(git ls-remote origin "refs/heads/$INTEGRATION_BRANCH" | awk '{print $1}')"
test "$REMOTE_PRODUCTION" = "$PRODUCTION_SHA"
test "$REMOTE_INTEGRATION" = "$START_HEAD"
git merge-base --is-ancestor "$PRODUCTION_SHA" "$START_HEAD"
git merge-base --is-ancestor "$TARGET_COMMIT" "$START_HEAD"
git merge-base --is-ancestor "$SCAFFOLD" "$START_HEAD"
git merge-base --is-ancestor "$PREVIOUS_VALIDATED_HEAD" "$START_HEAD"
git merge-base --is-ancestor "$PREVIOUS_COMMON_TARGET" "$TARGET_COMMIT"
test "$(git rev-parse "$SCAFFOLD^1")" = "$SCAFFOLD_PARENT1"
test "$(git rev-parse "$SCAFFOLD^2")" = "$TARGET_COMMIT"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305

git log --format='%H%x09%s' "$PREVIOUS_COMMON_TARGET..$TARGET_COMMIT" \
  -- "$OWNED_C" "$OWNED_H" > "$DIAG/target-history.tsv"

find_target_commit() {
  local path="$1" marker="$2" sha
  while IFS= read -r sha; do
    if git show --format= --unified=0 "$sha" -- "$path" | grep -Fq -- "$marker"; then
      printf '%s\n' "$sha"
      return 0
    fi
  done < <(git log --format='%H' "$PREVIOUS_COMMON_TARGET..$TARGET_COMMIT" -- "$path")
  return 1
}

TARGET_RESET_COMMIT="$(find_target_commit "$OWNED_H" 'XHCI_RESET_LONG_USEC')"
TARGET_GRACE_COMMIT="$(find_target_commit "$OWNED_C" 'run_graceperiod = jiffies + msecs_to_jiffies(500);')"
TARGET_SHUTDOWN_COMMIT="$(find_target_commit "$OWNED_C" "Don't poll the roothubs after shutdown.")"
TARGET_RESUME_COMMIT="$(find_target_commit "$OWNED_C" $'+\t\tretval = xhci_reset(xhci);')"
TARGET_WARNING_COMMIT="$(find_target_commit "$OWNED_C" 'if (!xhci->broken_suspend)')"
TARGET_XHCI_COMMITS=(
  "$TARGET_RESET_COMMIT" "$TARGET_GRACE_COMMIT" "$TARGET_SHUTDOWN_COMMIT"
  "$TARGET_RESUME_COMMIT" "$TARGET_WARNING_COMMIT" "$PREVIOUS_COMMON_TARGET"
)
for sha in "${TARGET_XHCI_COMMITS[@]}"; do
  git merge-base --is-ancestor "$sha" "$TARGET_COMMIT"
done
git show -s --format=%B "$TARGET_RESET_COMMIT" |
  grep -Fq 'xhci: make xhci_handshake timeout for xhci_reset() adjustable'
{
  printf 'reset-timeout\t%s\n' "$TARGET_RESET_COMMIT"
  printf 'startup-grace\t%s\n' "$TARGET_GRACE_COMMIT"
  printf 'shutdown-polling\t%s\n' "$TARGET_SHUTDOWN_COMMIT"
  printf 'resume-reset-failure\t%s\n' "$TARGET_RESUME_COMMIT"
  printf 'broken-suspend-warning\t%s\n' "$TARGET_WARNING_COMMIT"
  printf 'usb2-lpm-baseline\t%s\n' "$PREVIOUS_COMMON_TARGET"
  printf 'suspend-timeout-baseline\t%s\n' "$PREVIOUS_COMMON_TARGET"
  printf 'halt-timeout-baseline\t%s\n' "$PREVIOUS_COMMON_TARGET"
} > "$DIAG/target-xhci-provenance.tsv"
while IFS=$'\t' read -r label sha; do
  git show -s --format=fuller "$sha" > "$DIAG/target-$label-commit.txt"
done < "$DIAG/target-xhci-provenance.tsv"
git show --format= --unified=0 "$TARGET_RESET_COMMIT" -- "$OWNED_C" "$OWNED_H" \
  > "$DIAG/target-reset-timeout.patch"
git show --format= --unified=0 "$TARGET_GRACE_COMMIT" -- "$OWNED_C" "$OWNED_H" \
  > "$DIAG/target-startup-grace.patch"
git show --format= --unified=0 "$TARGET_SHUTDOWN_COMMIT" -- "$OWNED_C" \
  > "$DIAG/target-shutdown-polling.patch"
git show --format= --unified=0 "$TARGET_RESUME_COMMIT" -- "$OWNED_C" \
  > "$DIAG/target-resume-reset-failure.patch"
git show "$PREVIOUS_COMMON_TARGET:$OWNED_H" > "$DIAG/previous-common-xhci.h"
git show "$PREVIOUS_COMMON_TARGET:$OWNED_C" > "$DIAG/previous-common-xhci.c"
grep -Fq 'XHCI_L1_TIMEOUT' "$DIAG/previous-common-xhci.h"
grep -Fq '512' "$DIAG/previous-common-xhci.h"
grep -Fq 'STS_HALT, STS_HALT, XHCI_MAX_HALT_USEC);' \
  "$DIAG/previous-common-xhci.c"

if ! git diff --quiet "$SCAFFOLD" -- "$OWNED_C" "$OWNED_H"; then
  grep -Fq -- '- Semantically resolved conflicts: **28**' "$LEDGER"
  grep -Fq -- '- Remaining semantic conflicts: **5**' "$LEDGER"
  grep -Fq '### xHCI lifecycle and LPM safety union' "$LEDGER"
  {
    echo 'status=already-resolved'
    echo "head=$START_HEAD"
    echo "production=$PRODUCTION_SHA"
  } | tee "$DIAG/already-resolved.txt"
  find "$DIAG" -type f -print0 | sort -z | xargs -0 sha256sum > "$DIAG/SHA256SUMS"
  exit 0
fi

grep -Fq -- '- Semantically resolved conflicts: **26**' "$LEDGER"
grep -Fq -- '- Remaining semantic conflicts: **7**' "$LEDGER"
git diff --quiet "$SCAFFOLD" -- "$OWNED_C" "$OWNED_H"
git diff --quiet "$SCAFFOLD" -- "$HUB_PATH"
test "$(git rev-parse "$PREVIOUS_COMMON_TARGET:$OWNED_C")" = "$EXPECTED_PREVIOUS_C_BLOB"
test "$(git rev-parse "$PREVIOUS_COMMON_TARGET:$OWNED_H")" = "$EXPECTED_PREVIOUS_H_BLOB"
test "$(git rev-parse "$SCAFFOLD:$OWNED_C")" = "$EXPECTED_SCAFFOLD_C_BLOB"
test "$(git rev-parse "$SCAFFOLD:$OWNED_H")" = "$EXPECTED_SCAFFOLD_H_BLOB"
test "$(git rev-parse "HEAD:$OWNED_C")" = "$EXPECTED_SCAFFOLD_C_BLOB"
test "$(git rev-parse "HEAD:$OWNED_H")" = "$EXPECTED_SCAFFOLD_H_BLOB"
test "$(git rev-parse "$SCAFFOLD:$HUB_PATH")" = "$EXPECTED_SCAFFOLD_HUB_BLOB"
test "$(git rev-parse "HEAD:$HUB_PATH")" = "$EXPECTED_SCAFFOLD_HUB_BLOB"
test "$(git rev-parse "$TARGET_COMMIT:$OWNED_C")" = "$EXPECTED_TARGET_C_BLOB"
test "$(git rev-parse "$TARGET_COMMIT:$OWNED_H")" = "$EXPECTED_TARGET_H_BLOB"
git show "$TARGET_COMMIT:$OWNED_C" > "$DIAG/target-xhci.c"
git show "$TARGET_COMMIT:$OWNED_H" > "$DIAG/target-xhci.h"

# Resolver, compilation, reversal, ledger update, and guarded push follow.
git config user.name 'Miru LTS Integration Bot'
git config user.email 'miru-lts-integration@users.noreply.github.com'
export OWNED_C OWNED_H HUB_PATH TARGET_COMMIT
python3 - <<'PY' | tee "$DIAG/resolver.txt"
from pathlib import Path
import hashlib
import os
import subprocess

t = "\t"
nl = "\n"
c_path = Path(os.environ["OWNED_C"])
h_path = Path(os.environ["OWNED_H"])
hub_path = Path(os.environ["HUB_PATH"])
c = c_path.read_text()
h = h_path.read_text()
hub = hub_path.read_text()
target_c = subprocess.check_output(
    ["git", "show", f"{os.environ['TARGET_COMMIT']}:{os.environ['OWNED_C']}"],
    text=True,
)
target_h = subprocess.check_output(
    ["git", "show", f"{os.environ['TARGET_COMMIT']}:{os.environ['OWNED_H']}"],
    text=True,
)

def count(text, needle, expected, label):
    actual = text.count(needle)
    if actual != expected:
        raise SystemExit(f"{label}: expected {expected}, found {actual}")

def replace_once(text, old, new, label, history):
    count(text, old, 1, f"scaffold {label}")
    history.append((old, new, label))
    return text.replace(old, new, 1)

def reverse(text, history, scope):
    for old, new, label in reversed(history):
        count(text, new, 1, f"reverse {scope} {label}")
        text = text.replace(new, old, 1)
    return text

for needle, label in [
    ("#define XHCI_RESET_LONG_USEC", "long reset macro"),
    ("#define XHCI_RESET_SHORT_USEC", "short reset macro"),
    ("#define XHCI_L1_TIMEOUT" + t + t + "512", "USB2 LPM default"),
    ("unsigned long" + t + t + "run_graceperiod;", "startup grace field"),
    ("int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, u64 timeout_us);", "handshake prototype"),
    ("int xhci_reset(struct xhci_hcd *xhci, u64 timeout_us);", "reset prototype"),
]:
    count(target_h, needle, 1, f"target header {label}")
for needle, label in [
    ("int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, u64 timeout_us)", "handshake implementation"),
    ("int xhci_reset(struct xhci_hcd *xhci, u64 timeout_us)", "reset implementation"),
    ("xhci->run_graceperiod = jiffies + msecs_to_jiffies(500);", "startup grace assignment"),
    ("/* Don't poll the roothubs after shutdown. */", "shutdown polling"),
    ("if (!xhci->broken_suspend)", "broken suspend guard"),
]:
    count(target_c, needle, 1, f"target C {label}")
count(hub, "if (xhci->run_graceperiod)", 1, "clean companion grace condition")
count(hub, "Keep polling roothubs for a grace period after xHC start", 1,
      "clean companion grace documentation")

downstream_c = [
    t + "disable_irq(hcd->irq);",
    t + "enable_irq(hcd->irq);",
    "static phys_addr_t xhci_get_sec_event_ring_phys_addr",
    "static phys_addr_t xhci_get_xfer_ring_phys_addr",
    "int xhci_get_core_id(struct usb_hcd *hcd)",
    "static int  xhci_stop_endpoint",
    ".sec_event_ring_setup =" + t + t + "xhci_sec_event_ring_setup,",
    ".get_sec_event_ring_phys_addr =" + t + "xhci_get_sec_event_ring_phys_addr,",
    ".stop_endpoint =" + t + t + "xhci_stop_endpoint,",
]
downstream_h = [
    t + "/* secondary interrupter */",
    t + "struct" + t + "xhci_intr_reg __iomem **sec_ir_set;",
    t + "int" + t + t + "core_id;",
    t + "struct xhci_ring" + t + "**sec_event_ring;",
    t + "struct xhci_erst" + t + "*sec_erst;",
    "int xhci_sec_event_ring_setup(struct usb_hcd *hcd, unsigned int intr_num);",
    "int xhci_sec_event_ring_cleanup(struct usb_hcd *hcd, unsigned int intr_num);",
    "int xhci_get_core_id(struct usb_hcd *hcd);",
]
for marker in downstream_c:
    count(c, marker, 1, f"downstream C marker {marker}")
for marker in downstream_h:
    count(h, marker, 1, f"downstream header marker {marker}")

c_history = []
h_history = []
c = replace_once(
    c,
    "int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, int usec)",
    "int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, u64 timeout_us)",
    "handshake timeout type", c_history,
)
c = replace_once(c, t * 5 + "1, usec);", t * 5 + "1, timeout_us);",
                 "handshake timeout use", c_history)
c = replace_once(
    c,
    t * 2 + "void __iomem *ptr, u32 mask, u32 done, int usec)",
    t * 2 + "void __iomem *ptr, u32 mask, u32 done, u64 timeout_us)",
    "removal-aware helper type", c_history,
)
c = replace_once(c, t * 2 + "usec--;", t * 2 + "timeout_us--;",
                 "removal-aware helper decrement", c_history)
c = replace_once(c, t + "} while (usec > 0);", t + "} while (timeout_us > 0);",
                 "removal-aware helper condition", c_history)
c = replace_once(c, t * 3 + "STS_HALT, STS_HALT, 2 * XHCI_MAX_HALT_USEC);",
                 t * 3 + "STS_HALT, STS_HALT, XHCI_MAX_HALT_USEC);",
                 "halt timeout", c_history)

start_old = (
    t + "if (!ret)" + nl +
    t * 2 + "/* clear state flags. Including dying, halted or removing */" + nl +
    t * 2 + "xhci->xhc_state = 0;" + nl
)
start_new = (
    t + "if (!ret) {" + nl +
    t * 2 + "/* clear state flags. Including dying, halted or removing */" + nl +
    t * 2 + "xhci->xhc_state = 0;" + nl +
    t * 2 + "xhci->run_graceperiod = jiffies + msecs_to_jiffies(500);" + nl +
    t + "}" + nl
)
c = replace_once(c, start_old, start_new, "startup grace", c_history)
c = replace_once(
    c,
    "int xhci_reset(struct xhci_hcd *xhci)",
    "int xhci_reset(struct xhci_hcd *xhci, u64 timeout_us)",
    "reset signature", c_history,
)
reset_command_old = (
    t + "ret = xhci_handshake_check_state(xhci, &xhci->op_regs->command," + nl +
    t * 3 + "CMD_RESET, 0, 10 * 1000 * 1000);" + nl
)
reset_command_new = reset_command_old.replace("10 * 1000 * 1000", "timeout_us")
c = replace_once(c, reset_command_old, reset_command_new,
                 "reset command timeout", c_history)
reset_cnr_old = (
    t + "ret = xhci_handshake(&xhci->op_regs->status," + nl +
    t * 3 + "STS_CNR, 0, 10 * 1000 * 1000);" + nl
)
reset_cnr_new = reset_cnr_old.replace("10 * 1000 * 1000", "timeout_us")
c = replace_once(c, reset_cnr_old, reset_cnr_new,
                 "controller ready timeout", c_history)

stop_old = (
    t + "spin_lock_irq(&xhci->lock);" + nl +
    t + "xhci->xhc_state |= XHCI_STATE_HALTED;" + nl +
    t + "xhci->cmd_ring_state = CMD_RING_STATE_STOPPED;" + nl +
    t + "xhci_halt(xhci);" + nl +
    t + "xhci_reset(xhci);" + nl +
    t + "spin_unlock_irq(&xhci->lock);" + nl
)
stop_new = stop_old.replace("xhci_reset(xhci);",
                            "xhci_reset(xhci, XHCI_RESET_SHORT_USEC);")
c = replace_once(c, stop_old, stop_new, "short stop reset", c_history)

shutdown_old = (
    t + "if (xhci->quirks & XHCI_SPURIOUS_REBOOT)" + nl +
    t * 2 + "usb_disable_xhci_ports(to_pci_dev(hcd->self.sysdev));" + nl + nl +
    t + "spin_lock_irq(&xhci->lock);" + nl +
    t + "xhci_halt(xhci);" + nl +
    t + "/* Workaround for spurious wakeups at shutdown with HSW */" + nl +
    t + "if (xhci->quirks & XHCI_SPURIOUS_WAKEUP)" + nl +
    t * 2 + "xhci_reset(xhci);" + nl +
    t + "spin_unlock_irq(&xhci->lock);" + nl
)
shutdown_new = (
    t + "if (xhci->quirks & XHCI_SPURIOUS_REBOOT)" + nl +
    t * 2 + "usb_disable_xhci_ports(to_pci_dev(hcd->self.sysdev));" + nl + nl +
    t + "/* Don't poll the roothubs after shutdown. */" + nl +
    t + 'xhci_dbg(xhci, "%s: stopping usb%d port polling.\\n",' + nl +
    t * 3 + "__func__, hcd->self.busnum);" + nl +
    t + "clear_bit(HCD_FLAG_POLL_RH, &hcd->flags);" + nl +
    t + "del_timer_sync(&hcd->rh_timer);" + nl + nl +
    t + "if (xhci->shared_hcd) {" + nl +
    t * 2 + "clear_bit(HCD_FLAG_POLL_RH, &xhci->shared_hcd->flags);" + nl +
    t * 2 + "del_timer_sync(&xhci->shared_hcd->rh_timer);" + nl +
    t + "}" + nl + nl +
    t + "spin_lock_irq(&xhci->lock);" + nl +
    t + "xhci_halt(xhci);" + nl +
    t + "/* Workaround for spurious wakeups at shutdown with HSW */" + nl +
    t + "if (xhci->quirks & XHCI_SPURIOUS_WAKEUP)" + nl +
    t * 2 + "xhci_reset(xhci, XHCI_RESET_SHORT_USEC);" + nl +
    t + "spin_unlock_irq(&xhci->lock);" + nl
)
c = replace_once(c, shutdown_old, shutdown_new, "shutdown polling and short reset",
                 c_history)

suspend_old = (
    t + "if (xhci_handshake(&xhci->op_regs->status," + nl +
    t * 2 + "      STS_HALT, STS_HALT, delay)) {" + nl +
    t * 2 + 'xhci_warn(xhci, "WARN: xHC CMD_RUN timeout\\n");' + nl +
    t * 2 + "/* Set the HW_ACCESSIBLE so that any pending interrupts are" + nl +
    t * 2 + " * served." + nl +
    t * 2 + " */" + nl +
    t * 2 + "set_bit(HCD_FLAG_HW_ACCESSIBLE, &hcd->flags);" + nl +
    t * 2 + "set_bit(HCD_FLAG_HW_ACCESSIBLE, &xhci->shared_hcd->flags);" + nl +
    t * 2 + "xhci_hc_died(xhci);" + nl +
    t * 2 + "spin_unlock_irq(&xhci->lock);" + nl +
    t * 2 + "return -ETIMEDOUT;" + nl +
    t + "}" + nl
)
suspend_new = (
    t + "if (xhci_handshake(&xhci->op_regs->status," + nl +
    t * 2 + "      STS_HALT, STS_HALT, delay)) {" + nl +
    t * 2 + 'xhci_warn(xhci, "WARN: xHC CMD_RUN timeout\\n");' + nl +
    t * 2 + "spin_unlock_irq(&xhci->lock);" + nl +
    t * 2 + "return -ETIMEDOUT;" + nl +
    t + "}" + nl
)
c = replace_once(c, suspend_old, suspend_new, "suspend timeout state", c_history)

warning_old = t * 2 + 'xhci_warn(xhci, "xHC error in resume, USBSTS 0x%x, Reinit\\n", temp);' + nl
warning_new = (
    t * 2 + "if (!xhci->broken_suspend)" + nl +
    t * 3 + 'xhci_warn(xhci, "xHC error in resume, USBSTS 0x%x, Reinit\\n", temp);' + nl
)
c = replace_once(c, warning_old, warning_new, "broken suspend warning", c_history)

resume_old = (
    t * 2 + 'xhci_dbg(xhci, "Stop HCD\\n");' + nl +
    t * 2 + "xhci_halt(xhci);" + nl +
    t * 2 + "xhci_reset(xhci);" + nl +
    t * 2 + "spin_unlock_irq(&xhci->lock);" + nl +
    t * 2 + "xhci_cleanup_msix(xhci);" + nl
)
resume_new = (
    t * 2 + 'xhci_dbg(xhci, "Stop HCD\\n");' + nl +
    t * 2 + "xhci_halt(xhci);" + nl +
    t * 2 + "retval = xhci_reset(xhci, XHCI_RESET_LONG_USEC);" + nl +
    t * 2 + "spin_unlock_irq(&xhci->lock);" + nl +
    t * 2 + "if (retval)" + nl +
    t * 3 + "return retval;" + nl +
    t * 2 + "xhci_cleanup_msix(xhci);" + nl
)
c = replace_once(c, resume_old, resume_new, "long resume reset", c_history)
probe_old = (
    t + "/* Reset the internal HC memory state and registers. */" + nl +
    t + "retval = xhci_reset(xhci);" + nl +
    t + "if (retval)" + nl
)
probe_new = probe_old.replace("xhci_reset(xhci);",
                              "xhci_reset(xhci, XHCI_RESET_LONG_USEC);")
c = replace_once(c, probe_old, probe_new, "long probe reset", c_history)

h_reset_old = (
    "#define CMD_ETE" + t + t + "(1 << 14)" + nl +
    "/* bits 15:31 are reserved (and should be preserved on writes). */" + nl + nl +
    "/* IMAN - Interrupt Management Register */" + nl
)
h_reset_new = (
    "#define CMD_ETE" + t + t + "(1 << 14)" + nl +
    "/* bits 15:31 are reserved (and should be preserved on writes). */" + nl + nl +
    "#define XHCI_RESET_LONG_USEC" + t + t + "(10 * 1000 * 1000)" + nl +
    "#define XHCI_RESET_SHORT_USEC" + t + t + "(250 * 1000)" + nl + nl +
    "/* IMAN - Interrupt Management Register */" + nl
)
h = replace_once(h, h_reset_old, h_reset_new, "reset constants", h_history)
h_lpm_old = (
    "/* use 128 microseconds as USB2 LPM L1 default timeout. */" + nl +
    "#define XHCI_L1_TIMEOUT" + t + t + "128" + nl
)
h_lpm_new = (
    "/* use 512 microseconds as USB2 LPM L1 default timeout. */" + nl +
    "#define XHCI_L1_TIMEOUT" + t + t + "512" + nl
)
h = replace_once(h, h_lpm_old, h_lpm_new, "USB2 LPM default", h_history)
h_state_old = (
    t + "/* Host controller watchdog timer structures */" + nl +
    t + "unsigned int" + t + t + "xhc_state;" + nl + nl +
    t + "u32" + t + t + t + "command;" + nl
)
h_state_new = (
    t + "/* Host controller watchdog timer structures */" + nl +
    t + "unsigned int" + t + t + "xhc_state;" + nl +
    t + "unsigned long" + t + t + "run_graceperiod;" + nl + nl +
    t + "u32" + t + t + t + "command;" + nl
)
h = replace_once(h, h_state_old, h_state_new, "startup grace field", h_history)
h_proto_old = (
    "int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, int usec);" + nl +
    "int xhci_handshake_check_state(struct xhci_hcd *xhci," + nl +
    t * 2 + "void __iomem *ptr, u32 mask, u32 done, int usec);" + nl +
    "void xhci_quiesce(struct xhci_hcd *xhci);" + nl +
    "int xhci_halt(struct xhci_hcd *xhci);" + nl +
    "int xhci_start(struct xhci_hcd *xhci);" + nl +
    "int xhci_reset(struct xhci_hcd *xhci);" + nl
)
h_proto_new = (
    "int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, u64 timeout_us);" + nl +
    "int xhci_handshake_check_state(struct xhci_hcd *xhci," + nl +
    t * 2 + "void __iomem *ptr, u32 mask, u32 done, u64 timeout_us);" + nl +
    "void xhci_quiesce(struct xhci_hcd *xhci);" + nl +
    "int xhci_halt(struct xhci_hcd *xhci);" + nl +
    "int xhci_start(struct xhci_hcd *xhci);" + nl +
    "int xhci_reset(struct xhci_hcd *xhci, u64 timeout_us);" + nl
)
h = replace_once(h, h_proto_old, h_proto_new, "timeout prototypes", h_history)

if reverse(c, c_history, "C") != c_path.read_text():
    raise SystemExit("C resolver does not exactly reverse to scaffold")
if reverse(h, h_history, "header") != h_path.read_text():
    raise SystemExit("header resolver does not exactly reverse to scaffold")
for marker in downstream_c:
    count(c, marker, 1, f"resolved downstream C marker {marker}")
for marker in downstream_h:
    count(h, marker, 1, f"resolved downstream header marker {marker}")

for needle, expected, label in [
    ("int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, u64 timeout_us)", 1, "u64 handshake"),
    ("int xhci_handshake_check_state(struct xhci_hcd *xhci,", 1, "removal-aware helper retained"),
    ("int xhci_handshake_check_state(struct xhci_hcd *xhci," + nl +
     t * 2 + "void __iomem *ptr, u32 mask, u32 done, u64 timeout_us)",
     1, "removal-aware helper type"),
    ("int xhci_reset(struct xhci_hcd *xhci, u64 timeout_us)", 1, "u64 reset"),
    ("xhci_reset(xhci, XHCI_RESET_SHORT_USEC);", 2, "short reset call sites"),
    ("xhci_reset(xhci, XHCI_RESET_LONG_USEC);", 2, "long reset call sites"),
    ("xhci->run_graceperiod = jiffies + msecs_to_jiffies(500);", 1, "grace assignment"),
    ("/* Don't poll the roothubs after shutdown. */", 1, "shutdown polling guard"),
    ("if (!xhci->broken_suspend)", 1, "broken suspend warning guard"),
]:
    count(c, needle, expected, f"resolved C {label}")
for needle, expected, label in [
    ("#define XHCI_RESET_LONG_USEC", 1, "long reset macro"),
    ("#define XHCI_RESET_SHORT_USEC", 1, "short reset macro"),
    ("#define XHCI_L1_TIMEOUT" + t + t + "512", 1, "USB2 LPM default"),
    ("unsigned long" + t + t + "run_graceperiod;", 1, "grace field"),
    ("int xhci_handshake(void __iomem *ptr, u32 mask, u32 done, u64 timeout_us);", 1, "handshake prototype"),
    ("int xhci_reset(struct xhci_hcd *xhci, u64 timeout_us);", 1, "reset prototype"),
]:
    count(h, needle, expected, f"resolved header {label}")

reset_start = c.index("int xhci_reset(struct xhci_hcd *xhci, u64 timeout_us)")
reset_end = c.index(nl + nl + "#ifdef CONFIG_USB_PCI", reset_start)
reset_body = c[reset_start:reset_end]
if "xhci_handshake_check_state(xhci, &xhci->op_regs->command," not in reset_body:
    raise SystemExit("reset lost Miru removal-aware command polling")
if reset_body.count("timeout_us") != 3:
    raise SystemExit("reset timeout must drive both target polls")
suspend_start = c.index("int xhci_suspend(")
suspend_end = c.index(nl + "int xhci_resume(", suspend_start)
suspend_body = c[suspend_start:suspend_end]
if "xhci_hc_died(xhci);" in suspend_body or "set_bit(HCD_FLAG_HW_ACCESSIBLE" in suspend_body:
    raise SystemExit("suspend timeout still promotes inaccessible hardware")

c_path.write_text(c)
h_path.write_text(h)
print("status=resolved")
print("android_safety_sequences=7")
print("downstream_irq_and_secondary_event_paths_retained=yes")
print("target_reset_sequence_sha256=" + hashlib.sha256(reset_cnr_new.encode()).hexdigest())
print("target_shutdown_sequence_sha256=" + hashlib.sha256(shutdown_new.encode()).hexdigest())
PY

git diff --binary --full-index > "$DIAG/source.patch"
test -s "$DIAG/source.patch"
PATCH_SHA="$(sha256sum "$DIAG/source.patch" | awk '{print $1}')"
git diff --check
if git grep -nE '^(<<<<<<< .+|>>>>>>> .+|\|\|\|\|\|\|\| .+)$' -- "$OWNED_C" "$OWNED_H" \
  > "$DIAG/conflict-markers.txt"; then
  cat "$DIAG/conflict-markers.txt"
  exit 1
else
  : > "$DIAG/conflict-markers.txt"
fi
python3 - "$OWNED_C" "$OWNED_H" "$HUB_PATH" <<'PY' | tee "$DIAG/source-behavior.txt"
from pathlib import Path
import sys

t = "\t"
c, h, hub = (Path(p).read_text() for p in sys.argv[1:])
assert c.count("xhci_reset(xhci, XHCI_RESET_SHORT_USEC);") == 2
assert c.count("xhci_reset(xhci, XHCI_RESET_LONG_USEC);") == 2
assert c.count("xhci->run_graceperiod = jiffies + msecs_to_jiffies(500);") == 1
assert h.count("#define XHCI_L1_TIMEOUT" + t + t + "512") == 1
assert hub.count("if (xhci->run_graceperiod)") == 1
assert c.count(t + "disable_irq(hcd->irq);") == 1
assert c.count(t + "enable_irq(hcd->irq);") == 1
assert h.count(t + "struct xhci_ring" + t + "**sec_event_ring;") == 1
print("source_behavior_gates=PASS")
PY

git add -- "$OWNED_C" "$OWNED_H"
test "$(git diff --cached --name-only)" = $'drivers/usb/host/xhci.c\ndrivers/usb/host/xhci.h'
git commit -m 'lts: resolve xHCI lifecycle safety for 4.14.305'
SOURCE_COMMIT="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "$START_HEAD"
test "$(git diff-tree --no-commit-id --name-only -r "$SOURCE_COMMIT")" = \
  $'drivers/usb/host/xhci.c\ndrivers/usb/host/xhci.h'

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential bison flex libssl-dev libelf-dev cpio kmod rsync \
  zlib1g-dev libncurses-dev xz-utils file

ANDROID_ROOT="$RUNNER_TEMP/android-root"
KERNEL_WORKTREE="$ANDROID_ROOT/kernel/msm-4.14"
VENDOR_SOURCE="$RUNNER_TEMP/oneplus-sm8150-vendor-source"
OUT_DIR="$ANDROID_ROOT/out/h40-xhci-targeted"
TOOLCHAIN_ROOT="$RUNNER_TEMP/miru-toolchains"
rm -rf "$ANDROID_ROOT" "$VENDOR_SOURCE" "$TOOLCHAIN_ROOT"
mkdir -p "$ANDROID_ROOT/kernel" "$ANDROID_ROOT/out" "$TOOLCHAIN_ROOT"
git worktree prune
git worktree add --detach "$KERNEL_WORKTREE" "$SOURCE_COMMIT"

git init -q "$VENDOR_SOURCE"
git -C "$VENDOR_SOURCE" remote add origin \
  https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git
git -C "$VENDOR_SOURCE" fetch -q --depth=1 --filter=blob:none origin "$VENDOR_SHA"
git -C "$VENDOR_SOURCE" checkout -q --detach FETCH_HEAD
test "$(git -C "$VENDOR_SOURCE" rev-parse HEAD)" = "$VENDOR_SHA"
mkdir -p "$ANDROID_ROOT/vendor"
rsync -a "$VENDOR_SOURCE/vendor/" "$ANDROID_ROOT/vendor/"
test -f "$KERNEL_WORKTREE/block/oplus_foreground_io_opt/Kconfig"

fetch_root() {
  local url="$1" commit="$2" dest="$3"
  git init -q "$dest"
  git -C "$dest" remote add origin "$url"
  git -C "$dest" fetch -q --depth=1 --filter=blob:none origin "$commit"
  git -C "$dest" checkout -q --detach FETCH_HEAD
  test "$(git -C "$dest" rev-parse HEAD)" = "$commit"
}
fetch_sparse() {
  local url="$1" commit="$2" dest="$3" sparse_path="$4"
  git init -q "$dest"
  git -C "$dest" remote add origin "$url"
  git -C "$dest" sparse-checkout init --cone
  git -C "$dest" sparse-checkout set "$sparse_path"
  git -C "$dest" fetch -q --depth=1 --filter=blob:none origin "$commit"
  git -C "$dest" checkout -q --detach FETCH_HEAD
  test "$(git -C "$dest" rev-parse HEAD)" = "$commit"
}
fetch_sparse \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
  252aba16f513a857bc923172f67b0e55e23de35f \
  "$TOOLCHAIN_ROOT/clang-repo" clang-r377782c
fetch_root \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 \
  606f80986096476912e04e5c2913685a8f2c3b65 "$TOOLCHAIN_ROOT/gcc64"
fetch_root \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 \
  b0c6a654327ca8796bed1e61dffcf523d04dceaa "$TOOLCHAIN_ROOT/gcc32"
fetch_sparse \
  https://android.googlesource.com/platform/prebuilts/build-tools \
  7322db1e1e4715fe217a27f721613e6be8438676 \
  "$TOOLCHAIN_ROOT/build-tools" linux-x86

CLANG_DIR="$TOOLCHAIN_ROOT/clang-repo/clang-r377782c"
GCC64_DIR="$TOOLCHAIN_ROOT/gcc64"
GCC32_DIR="$TOOLCHAIN_ROOT/gcc32"
AOSP_BUILD_TOOLS="$TOOLCHAIN_ROOT/build-tools/linux-x86"
printf '%s  %s\n' \
  6618ecab73b79a70b79263d2f477f669e564d81ca802112d2e5f93c74c6b22ca \
  "$CLANG_DIR/bin/clang" | sha256sum -c -
printf '%s  %s\n' \
  2a663de4ce3d702fe3f2a0de48cac366be676f850c2f5732d9cc2e4acb9335e2 \
  "$GCC64_DIR/bin/aarch64-linux-android-ld" | sha256sum -c -
printf '%s  %s\n' \
  2f78058a8549bc5c099dbea16d9f3dc571e072b1ade906c3539e419787b502dd \
  "$GCC32_DIR/bin/arm-linux-androideabi-as" | sha256sum -c -
printf '%s  %s\n' \
  5630a485d7c597d137fa462626213007e8865cf549677e1f727d131695ec830c \
  "$AOSP_BUILD_TOOLS/bin/py2-cmd" | sha256sum -c -

mkdir -p "$OUT_DIR"
cp "$KERNEL_WORKTREE/h40-repro/config/GM1911_11_H.40.config" "$OUT_DIR/.config"
sed -i 's/\r$//' "$OUT_DIR/.config"
CLANG="$CLANG_DIR/bin/clang"
CROSS64="$GCC64_DIR/bin/aarch64-linux-android-"
CROSS32="$GCC32_DIR/bin/arm-linux-androideabi-"
PYTHON2="$AOSP_BUILD_TOOLS/bin/py2-cmd"
export PATH="$AOSP_BUILD_TOOLS/bin:$CLANG_DIR/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"
export ARCH=arm64 SUBARCH=arm64
make_args=(
  "O=$OUT_DIR" 'ARCH=arm64' 'TARGET_PRODUCT=msmnile'
  'BRAND_SHOW_FLAG=oneplus' 'TARGET_BUILD_VARIANT=user'
  "CROSS_COMPILE=$CROSS64" "CROSS_COMPILE_ARM32=$CROSS32"
  "REAL_CC=$CLANG" 'CLANG_TRIPLE=aarch64-linux-gnu-' "PYTHON=$PYTHON2"
  'HOSTCC=gcc' 'HOSTCXX=g++' 'LOCALVERSION=+'
)
make -C "$KERNEL_WORKTREE" "${make_args[@]}" olddefconfig \
  2>&1 | tee "$DIAG/olddefconfig.log"
grep -Fq 'CONFIG_MODVERSIONS=y' "$OUT_DIR/.config"
grep -Fq 'CONFIG_USB_XHCI_HCD=y' "$OUT_DIR/.config"
cp "$OUT_DIR/.config" "$DIAG/resolved.config"
make -C "$KERNEL_WORKTREE" -j4 V=0 "${make_args[@]}" "$TARGET_DIRECTORY" \
  2>&1 | tee "$DIAG/targeted-compile.log"
test -s "$OUT_DIR/$TARGET_OBJECT"
test -s "$OUT_DIR/drivers/usb/host/xhci.o"
test -s "$OUT_DIR/drivers/usb/host/xhci-hub.o"
if grep -nE '(^|[[:space:]])(warning|error):' \
  "$DIAG/olddefconfig.log" "$DIAG/targeted-compile.log" \
  > "$DIAG/targeted-diagnostics.txt"; then
  cat "$DIAG/targeted-diagnostics.txt"
  exit 1
else
  : > "$DIAG/targeted-diagnostics.txt"
fi
{
  echo 'result=PASS'
  echo "source_commit=$SOURCE_COMMIT"
  echo "target_directory=$TARGET_DIRECTORY"
  echo "target_object=$TARGET_OBJECT"
  echo 'xhci_enabled=yes'
  echo 'android_safety_sequences=7'
  echo 'downstream_irq_and_secondary_event_paths_retained=yes'
  echo "compiler=$("$CLANG" --version | head -n1)"
} | tee "$DIAG/targeted-compile-summary.txt"

REVERT_WORKTREE="$RUNNER_TEMP/lts305-xhci-revert"
rm -rf "$REVERT_WORKTREE"
git worktree add --detach "$REVERT_WORKTREE" "$SOURCE_COMMIT"
git -C "$REVERT_WORKTREE" config user.name 'Miru LTS Integration Bot'
git -C "$REVERT_WORKTREE" config user.email 'miru-lts-integration@users.noreply.github.com'
git -C "$REVERT_WORKTREE" revert --no-edit "$SOURCE_COMMIT" \
  > "$DIAG/revert.stdout" 2> "$DIAG/revert.stderr"
git -C "$REVERT_WORKTREE" diff --quiet "$SCAFFOLD" -- "$OWNED_C" "$OWNED_H"
test "$(git -C "$REVERT_WORKTREE" rev-parse "HEAD:$OWNED_C")" = "$EXPECTED_SCAFFOLD_C_BLOB"
test "$(git -C "$REVERT_WORKTREE" rev-parse "HEAD:$OWNED_H")" = "$EXPECTED_SCAFFOLD_H_BLOB"
test "$(git -C "$REVERT_WORKTREE" rev-parse 'HEAD^{tree}')" = \
  "$(git rev-parse "$START_HEAD^{tree}")"
{
  echo 'result=PASS'
  echo "owning_commit=$SOURCE_COMMIT"
  echo "revert_commit=$(git -C "$REVERT_WORKTREE" rev-parse HEAD)"
  echo "restored_scaffold=$SCAFFOLD"
  echo "restored_paths=$OWNED_C,$OWNED_H"
  echo "restored_start_tree=$(git rev-parse "$START_HEAD^{tree}")"
} | tee "$DIAG/reversal-summary.txt"

TARGET_XHCI_COMMITS_CSV="$(awk -F $'\t' '{print $2}' "$DIAG/target-xhci-provenance.tsv" |
  awk '!seen[$0]++' | paste -sd, -)"
TARGET_XHCI_PROVENANCE="$(tr '\n' ';' < "$DIAG/target-xhci-provenance.tsv" | sed 's/;*$//')"
export SOURCE_COMMIT SCAFFOLD LEDGER PATCH_SHA TARGET_XHCI_COMMITS_CSV TARGET_XHCI_PROVENANCE TARGET_COMMIT \
  EXPECTED_SCAFFOLD_C_BLOB EXPECTED_SCAFFOLD_H_BLOB EXPECTED_TARGET_C_BLOB EXPECTED_TARGET_H_BLOB \
  EXPECTED_SCAFFOLD_HUB_BLOB
python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["LEDGER"])
text = path.read_text()
for old, new in {
    "- Semantically resolved conflicts: **26**": "- Semantically resolved conflicts: **28**",
    "- Remaining semantic conflicts: **7**": "- Remaining semantic conflicts: **5**",
}.items():
    if old not in text:
        raise SystemExit(f"missing ledger status: {old}")
    text = text.replace(old, new, 1)

source = os.environ["SOURCE_COMMIT"]
for row in (21, 22):
    pattern = re.compile(
        rf"^(\| {row} \| .*? \| .*? \| index-resolved in scaffold \| )unresolved( \| — \| — \| — \|)$",
        re.M,
    )
    match = pattern.search(text)
    if not match:
        raise SystemExit(f"missing unresolved xHCI manifest row {row}")
    replacement = match.group(1) + "resolved" + f" | {chr(96)}{source}{chr(96)} | xhci-hcd.o PASS | clean reversal PASS |"
    text = text[:match.start()] + replacement + text[match.end():]

bt = chr(96)
record = f"""
### xHCI lifecycle and LPM safety union

- Owning source commit: {bt}{source}{bt}.
- Owned paths: {bt}drivers/usb/host/xhci.c{bt} and {bt}drivers/usb/host/xhci.h{bt}.
- Relevant Android Common commits: {bt}{os.environ['TARGET_XHCI_COMMITS_CSV']}{bt}, all target-reachable from {bt}{os.environ['TARGET_COMMIT']}{bt}.
- Provenance verification: {os.environ['TARGET_XHCI_PROVENANCE']}; each target marker was checked in its own target-reachable diff.
- Android behavior imported: use a 10-second reset timeout only where reset completion is critical, retain 250 ms reset limits under shutdown/stop locks, use a 64-bit handshake timeout, add the xHC-start roothub grace period, stop roothub polling at shutdown, use the 512 us USB2 LPM default, and retain the target suspend/resume failure behavior.
- Downstream intent retained: Miru's IRQ flood guard, removal-aware handshake helper, secondary interrupter/event-ring APIs, physical-address helpers, core ID, and stop-endpoint hook remain present and are compiled together.
- Semantic decision: union Android's lifecycle and power-safety sequences with the downstream host-controller extensions. The reset command keeps Miru's removal-aware poll while adopting Android's tunable timeout; the clean companion {bt}xhci-hub.c{bt} grace-period consumer remains untouched at scaffold blob {bt}{os.environ['EXPECTED_SCAFFOLD_HUB_BLOB']}{bt}.
- Scaffold blobs: {bt}{os.environ['EXPECTED_SCAFFOLD_C_BLOB']}{bt} and {bt}{os.environ['EXPECTED_SCAFFOLD_H_BLOB']}{bt}. Target blobs: {bt}{os.environ['EXPECTED_TARGET_C_BLOB']}{bt} and {bt}{os.environ['EXPECTED_TARGET_H_BLOB']}{bt}.
- Audited source patch SHA-256: {bt}{os.environ['PATCH_SHA']}{bt} using {bt}git diff --binary --full-index{bt}.
- Targeted compilation: **PASS** for {bt}drivers/usb/host/xhci-hcd.o{bt}, including the core and roothub objects, using the pinned H.40 toolchain and stock configuration. Diagnostics were clean.
- Android lifecycle, LPM, source-preservation, and clean-companion gates: **PASS**.
- Clean reversal: **PASS**; reverting {bt}{source}{bt} restored both owned paths exactly to scaffold {bt}{os.environ['SCAFFOLD']}{bt} and restored the complete pre-resolution integration tree.
- Validation workflow run: {bt}{os.environ.get('GITHUB_RUN_ID', 'unknown')}{bt}.
"""
if "### xHCI lifecycle and LPM safety union" in text:
    raise SystemExit("xHCI resolution record already exists")
path.write_text(text + record)
PY

git add -- "$LEDGER"
test "$(git diff --cached --name-only)" = "$LEDGER"
git commit -m 'docs: record xHCI validation [skip ci]'
DOC_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^)" = "$SOURCE_COMMIT"
{
  echo 'status=PASS'
  echo "start_head=$START_HEAD"
  echo "source_commit=$SOURCE_COMMIT"
  echo "documentation_head=$DOC_HEAD"
  echo "production_sha=$PRODUCTION_SHA"
  echo "scaffold=$SCAFFOLD"
  echo 'semantic_conflicts_resolved=28'
  echo 'semantic_conflicts_remaining=5'
} | tee "$DIAG/resolution-summary.txt"
git show --stat --oneline "$SOURCE_COMMIT" > "$DIAG/source-commit.txt"
git show --stat --oneline "$DOC_HEAD" > "$DIAG/documentation-commit.txt"
find "$DIAG" -type f -print0 | sort -z | xargs -0 sha256sum > "$DIAG/SHA256SUMS"

test "$(git ls-remote origin "refs/heads/$PRODUCTION_BRANCH" | awk '{print $1}')" = "$PRODUCTION_SHA"
test "$(git ls-remote origin "refs/heads/$INTEGRATION_BRANCH" | awk '{print $1}')" = "$START_HEAD"
git push origin "$DOC_HEAD:refs/heads/$INTEGRATION_BRANCH"
