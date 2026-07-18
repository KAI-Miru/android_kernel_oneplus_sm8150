#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import re
import subprocess

UFS = pathlib.Path("drivers/scsi/ufs/ufs-qcom.c")
LEDGER = pathlib.Path("Documentation/miru/lts-4.14.190-conflicts.md")

EXPECTED_HASHES = {
    UFS: "4b76913104f7ba3c1e41f075d816c584ffaa5410",
    LEDGER: "1e93a1d0959e71228a03e90b223e643541f605a6",
}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def replace_exact(text: str, old: str, new: str, expected_count: int = 1) -> str:
    count = text.count(old)
    if count != expected_count:
        raise SystemExit(
            f"replacement guard failed: expected {expected_count}, found {count}: {old!r}"
        )
    return text.replace(old, new, expected_count)


def verify_hashes() -> None:
    for path, expected in EXPECTED_HASHES.items():
        actual = git("hash-object", str(path)).strip()
        if actual != expected:
            raise SystemExit(f"{path}: expected blob {expected}, found {actual}")


def resolve_ufs() -> None:
    text = UFS.read_text()

    old = """\t/* sleep a bit intermittently as we are dumping too much data */
\tusleep_range(1000, 1100);
\tufs_qcom_testbus_read(hba);
\tusleep_range(1000, 1100);
\tufs_qcom_print_unipro_testbus(hba);
\tusleep_range(1000, 1100);
\tufs_qcom_print_utp_hci_testbus(hba);
\tusleep_range(1000, 1100);
\tufs_qcom_phy_dbg_register_dump(phy);
\tusleep_range(1000, 1100);
"""
    new = """\t/* Busy-wait because this dump can be invoked from atomic context. */
\tudelay(1000);
\tufs_qcom_testbus_read(hba);
\tudelay(1000);
\tufs_qcom_print_unipro_testbus(hba);
\tudelay(1000);
\tufs_qcom_print_utp_hci_testbus(hba);
\tudelay(1000);
\tufs_qcom_phy_dbg_register_dump(phy);
\tudelay(1000);
"""
    text = replace_exact(text, old, new)

    required_h40 = (
        '#include <linux/clk/qcom.h>',
        '#include "ufs-qcom-debugfs.h"',
        '#include "ufshcd-crypto-qti.h"',
        'static void ufs_qcom_force_mem_config(struct ufs_hba *hba)',
        'static int ufs_qcom_full_reset(struct ufs_hba *hba)',
        'static int ufs_qcom_update_sec_cfg(struct ufs_hba *hba, bool restore_sec_cfg)',
        'static int ufs_qcom_pm_qos_init(struct ufs_qcom_host *host)',
        'static void ufs_qcom_pm_qos_suspend(struct ufs_qcom_host *host)',
        'static int ufs_qcom_set_bus_vote(struct ufs_hba *hba, bool on)',
        'static void ufs_qcom_save_host_ptr(struct ufs_hba *hba)',
        'static void ufs_qcom_parse_lpm(struct ufs_qcom_host *host)',
        'static int ufs_qcom_parse_reg_info(struct ufs_qcom_host *host, char *name,',
        'ufshcd_crypto_qti_set_vops(hba);',
        '.full_reset\t\t= ufs_qcom_full_reset,',
        '.update_sec_cfg\t\t= ufs_qcom_update_sec_cfg,',
        '.set_bus_vote\t\t= ufs_qcom_set_bus_vote,',
        '.pm_qos_vops\t= &ufs_hba_pm_qos_variant_ops,',
        'clk_set_flags(clki->clk, CLKFLAG_RETAIN_MEM);',
        'hba->is_sys_suspended = false;',
    )
    for token in required_h40:
        if token not in text:
            raise SystemExit(f"UFS lost required H.40 behavior: {token}")

    match = re.search(
        r"static void ufs_qcom_dump_dbg_regs\(.*?\n\}\n\n/\*\*",
        text,
        re.S,
    )
    if not match:
        raise SystemExit("could not isolate ufs_qcom_dump_dbg_regs")
    dump_fn = match.group(0)
    if "usleep_range(" in dump_fn:
        raise SystemExit("sleepable delay remains in atomic-capable UFS dump")
    if dump_fn.count("udelay(1000);") != 5:
        raise SystemExit("expected exactly five UFS debug dump busy-waits")

    UFS.write_text(text)


def update_ledger() -> None:
    text = LEDGER.read_text()
    replacements = {
        "- Resolved conflicts: 19": "- Resolved conflicts: 20",
        "- Remaining conflicts: 9": "- Remaining conflicts: 8",
        "drivers/scsi/ufs/ufs-qcom.c\n": "",
    }
    for old, new in replacements.items():
        text = replace_exact(text, old, new)

    marker = "## Remaining deferred conflicts\n"
    if text.count(marker) != 1:
        raise SystemExit("remaining-conflicts marker missing or duplicated")

    section = """## Resolved in Step 6

The Qualcomm UFS conflict was resolved as a minimal atomic-context safety
backport:

```text
drivers/scsi/ufs/ufs-qcom.c
```

The file retains the complete H.40 implementation, including QTI ICE setup,
secure-configuration restoration, retained ICE clock memory, bus voting,
per-CPU PM QoS, clock scaling, regulator control, PHY reset/calibration,
full-controller reset, debugfs and suspend/resume behavior.

Android stable commit `291ae253fb695258fbdf2d73f5f37b43f597e537`
(upstream `3be60b564de49875e47974c37fabced893cd0931`) is applied to
`ufs_qcom_dump_dbg_regs()`: five `usleep_range(1000, 1100)` calls are replaced
with `udelay(1000)` because this diagnostic path can be reached from interrupt
and other atomic contexts. No other UFS behavior is changed.

Resolution commit:

```text
lts: resolve Qualcomm UFS atomic dump conflict
```

"""
    LEDGER.write_text(text.replace(marker, section + marker, 1))


def main() -> None:
    verify_hashes()
    resolve_ufs()
    update_ledger()
    print("Step 6 guarded UFS resolution completed.")


if __name__ == "__main__":
    main()
