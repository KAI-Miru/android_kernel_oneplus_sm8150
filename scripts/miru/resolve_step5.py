#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import subprocess

KCONFIG = pathlib.Path("drivers/mmc/core/Kconfig")
BLOCK = pathlib.Path("drivers/mmc/core/block.c")
SDHCI = pathlib.Path("drivers/mmc/host/sdhci-msm.c")
HOST = pathlib.Path("include/linux/mmc/host.h")
LEDGER = pathlib.Path("Documentation/miru/lts-4.14.190-conflicts.md")

EXPECTED_HASHES = {
    KCONFIG: "4e4c9f1695d32b458d0f88a7e6263bbaa0350bf9",
    BLOCK: "87703ba162c4fee3fdbc161d23c9b036fe76ea57",
    SDHCI: "29a87b31b6de51b81bcb83684b220610b7c6a04d",
    HOST: "56b6af9403bcdd9c3f83b847162d52be650035cb",
    LEDGER: "7dd6657778b41d5c234b12d2ea6f1ef84a064342",
}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def replace_exact(text: str, old: str, new: str, count: int = 1) -> str:
    actual = text.count(old)
    if actual != count:
        raise SystemExit(
            f"replacement guard failed: expected {count}, found {actual}: {old!r}"
        )
    return text.replace(old, new, count)


def verify_hashes() -> None:
    for path, expected in EXPECTED_HASHES.items():
        actual = git("hash-object", str(path)).strip()
        if actual != expected:
            raise SystemExit(f"{path}: expected blob {expected}, found {actual}")


def resolve_kconfig() -> None:
    text = KCONFIG.read_text()
    addition = """

config MMC_CRYPTO
\tbool "MMC Crypto Engine Support"
\tdepends on BLK_INLINE_ENCRYPTION
\thelp
\t  Enable Crypto Engine Support in MMC.
\t  Enabling this makes it possible for the kernel to use the crypto
\t  capabilities of the MMC device (if present) to perform crypto
\t  operations on data being transferred to/from the device.
"""
    if "config MMC_CRYPTO" in text:
        raise SystemExit("MMC_CRYPTO already exists unexpectedly")
    if not text.endswith("\t  If unsure, say N here.\n"):
        raise SystemExit("MMC Kconfig tail changed unexpectedly")
    text += addition

    for token in (
        "config MMC_RING_BUFFER",
        "config MMC_BLOCK_DEFERRED_RESUME",
        "config MMC_CLKGATE",
        "config MMC_SIMULATE_MAX_SPEED",
        "config MMC_CRYPTO",
        "depends on BLK_INLINE_ENCRYPTION",
    ):
        if token not in text:
            raise SystemExit(f"MMC Kconfig lost required option: {token}")
    KCONFIG.write_text(text)


def resolve_block() -> None:
    text = BLOCK.read_text()
    text = replace_exact(
        text,
        '#include "card.h"\n#include "host.h"\n',
        '#include "card.h"\n#include "crypto.h"\n#include "host.h"\n',
    )
    text = replace_exact(
        text,
        "\tmemset(brq, 0, sizeof(struct mmc_blk_request));\n\n\tbrq->mrq.data = &brq->data;\n",
        "\tmemset(brq, 0, sizeof(struct mmc_blk_request));\n\n\tmmc_crypto_prepare_req(mqrq);\n\n\tbrq->mrq.data = &brq->data;\n",
    )

    required = (
        '#include "crypto.h"',
        "mmc_crypto_prepare_req(mqrq);",
        "#define MMC_ABNORMAL_TIMEOUT",
        "#define MMC_ABNORMAL_COUNT",
        "static bool mmc_blk_timeout_check(",
        "card->host->card_stuck_in_programing_status = true;",
        "mmc_card_set_removed(card);",
        "#ifndef VENDOR_EDIT",
        "char *capacity_string(struct mmc_card *card)",
        "static int mmc_blk_cmdq_switch(",
        "static int mmc_blk_ioctl_rpmb_cmd(",
        "static enum blk_eh_timer_return mmc_blk_cmdq_req_timed_out(",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"MMC block lost H.40 or stable behavior: {token}")
    if text.count("mmc_crypto_prepare_req(mqrq);") != 1:
        raise SystemExit("MMC crypto request preparation missing or duplicated")
    BLOCK.write_text(text)


def resolve_sdhci() -> None:
    text = SDHCI.read_text()
    text = replace_exact(
        text,
        """\tif (host->clock <= CORE_FREQ_100MHZ ||
\t\t!((ios.timing == MMC_TIMING_MMC_HS400) ||
\t\t(ios.timing == MMC_TIMING_MMC_HS200) ||
\t\t(ios.timing == MMC_TIMING_UHS_SDR104)))
\t\treturn 0;

\t/*
\t * Don't allow re-tuning for CRC errors observed for any commands
""",
        """\tif (host->clock <= CORE_FREQ_100MHZ ||
\t\t!((ios.timing == MMC_TIMING_MMC_HS400) ||
\t\t(ios.timing == MMC_TIMING_MMC_HS200) ||
\t\t(ios.timing == MMC_TIMING_UHS_SDR104)))
\t\treturn 0;

\t/*
\t * Clear tuning_done before tuning so the vendor-specific HS400
\t * settings are reapplied after controller re-initialization.
\t */
\tmsm_host->tuning_done = false;

\t/*
\t * Don't allow re-tuning for CRC errors observed for any commands
""",
    )
    text = replace_exact(
        text,
        """\thost->quirks |= SDHCI_QUIRK_BROKEN_CARD_DETECTION;
\thost->quirks |= SDHCI_QUIRK_SINGLE_POWER_WRITE;
\thost->quirks |= SDHCI_QUIRK_CAP_CLOCK_BASE_BROKEN;
\thost->quirks |= SDHCI_QUIRK_NO_ENDATTR_IN_NOPDESC;
""",
        """\thost->quirks |= SDHCI_QUIRK_BROKEN_CARD_DETECTION;
\thost->quirks |= SDHCI_QUIRK_SINGLE_POWER_WRITE;
\thost->quirks |= SDHCI_QUIRK_CAP_CLOCK_BASE_BROKEN;
\thost->quirks |= SDHCI_QUIRK_MULTIBLOCK_READ_ACMD12;
\thost->quirks |= SDHCI_QUIRK_NO_ENDATTR_IN_NOPDESC;
""",
    )

    required = (
        '#include "cmdq_hci.h"',
        '#include "cmdq_hci-crypto-qti.h"',
        "msm_host->tuning_done = false;",
        "SDHCI_QUIRK_MULTIBLOCK_READ_ACMD12",
        "sdhci_msm_cmdq_init",
        "sdhci_msm_bus_register",
        "sdhci_msm_pm_qos_parse",
        "sdhci_msm_registers_save",
        "sdhci_msm_registers_restore",
        "SDHCI_QUIRK2_USE_RESET_WORKAROUND",
        "MMC_CAP2_CMD_QUEUE",
        "MMC_CAP2_CLK_SCALE",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"SDHCI-MSM lost required behavior: {token}")
    if text.count("msm_host->tuning_done = false;") != 1:
        raise SystemExit("HS400 tuning reset missing or duplicated")
    if text.count("SDHCI_QUIRK_MULTIBLOCK_READ_ACMD12") != 1:
        raise SystemExit("ACMD12 quirk missing or duplicated")
    SDHCI.write_text(text)


def resolve_host() -> None:
    text = HOST.read_text()
    text = replace_exact(
        text,
        "#define MMC_CAP2_BOOTPART_NOACC (1 << 0)        /* Boot partition no access */\n"
        "#define MMC_CAP2_FULL_PWR_CYCLE (1 << 2)        /* Can do full power cycle */\n",
        "#define MMC_CAP2_BOOTPART_NOACC (1 << 0)        /* Boot partition no access */\n"
        "#define MMC_CAP2_CRYPTO\t\t(1 << 1)\t/* Host supports inline encryption */\n"
        "#define MMC_CAP2_FULL_PWR_CYCLE (1 << 2)        /* Can do full power cycle */\n",
    )
    text = replace_exact(
        text,
        """\tint\t\t\tcqe_qdepth;
\tbool\t\t\tcqe_enabled;
\tbool\t\t\tcqe_on;

#ifdef CONFIG_MMC_EMBEDDED_SDIO
""",
        """\tint\t\t\tcqe_qdepth;
\tbool\t\t\tcqe_enabled;
\tbool\t\t\tcqe_on;
#ifdef CONFIG_MMC_CRYPTO
\tstruct keyslot_manager\t*ksm;
\tvoid\t\t\t*crypto_DO_NOT_USE[7];
#endif /* CONFIG_MMC_CRYPTO */

#ifdef CONFIG_MMC_EMBEDDED_SDIO
""",
    )

    required = (
        "#define MAX_MULTIREAD_TIMEOUT_ERR_CNT 10",
        "#define MMC_MULTIREAD_CNT_WINDOW_S",
        "#define MAX_MULTIWRITE_TIMEOUT_ERR_CNT 10",
        "#define MMC_MULTIWRITE_CNT_WINDOW_S",
        "int detect_change_retry;",
        "bool                    card_stuck_in_programing_status;",
        "card_multiread_timeout_err_cnt",
        "card_multiwrite_timeout_err_cnt",
        "struct mmc_cmdq_host_ops",
        "cqe_crypto_update_queue",
        "void *cmdq_private;",
        "bool inlinecrypt_support;",
        "bool inlinecrypt_reset_needed;",
        "#define MMC_CAP2_CRYPTO",
        "struct keyslot_manager\t*ksm;",
        "crypto_DO_NOT_USE[7]",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"MMC host ABI lost required field or flag: {token}")
    if text.count("MMC_CAP2_CRYPTO") != 1:
        raise SystemExit("MMC_CAP2_CRYPTO missing or duplicated")
    if text.count("crypto_DO_NOT_USE[7]") != 1:
        raise SystemExit("generic MMC crypto ABI padding missing or duplicated")
    HOST.write_text(text)


def validate_dependencies() -> None:
    makefile = pathlib.Path("drivers/mmc/core/Makefile").read_text()
    crypto_h = pathlib.Path("drivers/mmc/core/crypto.h").read_text()
    crypto_c = pathlib.Path("drivers/mmc/core/crypto.c").read_text()
    core_h = pathlib.Path("include/linux/mmc/core.h").read_text()

    for token, text in (
        ("mmc_core-$(CONFIG_MMC_CRYPTO)\t+= crypto.o", makefile),
        ("void mmc_crypto_prepare_req(struct mmc_queue_req *mqrq);", crypto_h),
        ("void mmc_crypto_setup_queue(struct mmc_host *host", crypto_h),
        ("void mmc_crypto_free_host(struct mmc_host *host);", crypto_h),
        ("mrq->crypto_key_slot = bc->bc_keyslot;", crypto_c),
        ("q->ksm = host->ksm;", crypto_c),
        ("#ifdef CONFIG_MMC_CRYPTO", core_h),
        ("int crypto_key_slot;", core_h),
        ("u64 data_unit_num;", core_h),
    ):
        if token not in text:
            raise SystemExit(f"generic MMC crypto dependency missing: {token}")

    grep = git("grep", "-n", "mmc_crypto_setup_queue", "--", "drivers/mmc/core")
    if "drivers/mmc/core/queue.c:" not in grep:
        raise SystemExit("MMC queue does not install generic crypto keyslot manager")

    grep = git("grep", "-n", "mmc_crypto_free_host", "--", "drivers/mmc/core")
    if "drivers/mmc/core/host.c:" not in grep:
        raise SystemExit("MMC host teardown does not free generic crypto state")

    grep = git("grep", "-n", "CONFIG_MMC_CRYPTO=y", "--", "arch/arm64/configs", "h40-repro/config")
    target_lines = [line for line in grep.splitlines() if "cuttlefish_defconfig" not in line]
    if target_lines:
        raise SystemExit(
            "CONFIG_MMC_CRYPTO unexpectedly enabled outside cuttlefish: "
            + " | ".join(target_lines)
        )


def update_ledger() -> None:
    text = LEDGER.read_text()
    replacements = {
        "- Resolved conflicts: 15": "- Resolved conflicts: 19",
        "- Remaining conflicts: 13": "- Remaining conflicts: 9",
        "drivers/mmc/core/Kconfig\n": "",
        "drivers/mmc/core/block.c\n": "",
        "drivers/mmc/host/sdhci-msm.c\n": "",
        "include/linux/mmc/host.h\n": "",
    }
    for old, new in replacements.items():
        text = replace_exact(text, old, new)

    marker = "## Remaining deferred conflicts\n"
    if text.count(marker) != 1:
        raise SystemExit("remaining-conflicts marker missing or duplicated")

    section = """## Resolved in Step 5

The MMC core, MMC block path, host ABI and Qualcomm SDHCI driver were resolved
as one request/host compatibility unit:

```text
drivers/mmc/core/Kconfig
drivers/mmc/core/block.c
drivers/mmc/host/sdhci-msm.c
include/linux/mmc/host.h
```

`Kconfig` adds the Android stable generic `MMC_CRYPTO` option while preserving
H.40's ring-buffer, deferred-resume, clock-gating and speed-simulation options.
The H.40 target configuration does not enable this generic option, so its
shipping structure layout and legacy Qualcomm CMDQ/ICE path remain unchanged.

`block.c` adds generic `mmc_crypto_prepare_req()` request metadata preparation.
All H.40 legacy CMDQ, RPMB, timeout-abnormality detection, stuck-program-state,
capacity reporting and vendor command-class compatibility behavior is retained.

`host.h` adds the unused bit-1 `MMC_CAP2_CRYPTO` capability and the generic
keyslot-manager fields under `CONFIG_MMC_CRYPTO`. H.40's vendor timeout tracking,
card-detection retry, programming-state, devfreq, CMDQ and inline-crypto fields
remain in place.

`sdhci-msm.c` applies the stable HS400 re-initialization fix by clearing
`tuning_done` before re-tuning, and enables the controller's supported automatic
CMD12 handling for multiblock reads. Qualcomm bus voting, PM QoS, register
save/restore, reset workarounds and QTI CMDQ crypto integration are preserved.

Resolution commit:

```text
lts: resolve MMC core and SDHCI-MSM conflicts
```

"""
    LEDGER.write_text(text.replace(marker, section + marker, 1))


def main() -> None:
    verify_hashes()
    resolve_kconfig()
    resolve_block()
    resolve_sdhci()
    resolve_host()
    validate_dependencies()
    update_ledger()
    print("Step 5 guarded MMC/SDHCI resolution completed.")


if __name__ == "__main__":
    main()
