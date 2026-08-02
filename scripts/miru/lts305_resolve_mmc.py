#!/usr/bin/env python3
"""Resolve the authentic MMC conflict cluster for Miru H.40 Linux 4.14.305."""

from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

SCAFFOLD = "b92a77e96dd54fd30f8f39c7eef23e76f211c515"
PATHS = (
    Path("drivers/mmc/core/host.c"),
    Path("drivers/mmc/core/mmc_ops.c"),
    Path("drivers/mmc/host/sdhci.c"),
)
EXPECTED_SCAFFOLD_BLOBS = {
    PATHS[0]: "eef58c060bb1756cef44639839e5a7b3f74b7d2a",
    PATHS[1]: "40929a4301761ec6d78a781ba03c626c0869a2eb",
    PATHS[2]: "ecf99f3d9b2838dfcdc802743dd0f692164dd5a8",
}
HEADER = Path("drivers/mmc/host/sdhci.h")
EXPECTED_HEADER_BLOB = "b3f0fb715b05dd1147fd3f97018c938fc90139f0"


def run(*args: str) -> bytes:
    return subprocess.check_output(list(args))


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


def verify_baseline() -> None:
    head = run("git", "rev-parse", "HEAD").decode().strip()
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", SCAFFOLD, head], check=False
    ).returncode:
        raise SystemExit(f"scaffold {SCAFFOLD} is not an ancestor of {head}")

    for path, expected in EXPECTED_SCAFFOLD_BLOBS.items():
        actual = run("git", "rev-parse", f"{SCAFFOLD}:{path}").decode().strip()
        if actual != expected:
            raise SystemExit(f"unexpected scaffold blob for {path}: {actual}")
        if subprocess.run(
            ["git", "diff", "--quiet", SCAFFOLD, "--", str(path)], check=False
        ).returncode:
            raise SystemExit(f"owned path drifted after scaffold: {path}")

    header_blob = run("git", "rev-parse", f"{SCAFFOLD}:{HEADER}").decode().strip()
    if header_blob != EXPECTED_HEADER_BLOB:
        raise SystemExit(f"unexpected scaffold header blob: {header_blob}")
    if subprocess.run(
        ["git", "diff", "--quiet", SCAFFOLD, "--", str(HEADER)], check=False
    ).returncode:
        raise SystemExit(f"clean dependency drifted after scaffold: {HEADER}")

    header = HEADER.read_text()
    for needle in (
        "#define SDHCI_PRESET_DRV_MASK\t\tGENMASK(15, 14)",
        "#define SDHCI_PRESET_CLKGEN_SEL\t\tBIT(10)",
        "#define SDHCI_PRESET_SDCLK_FREQ_MASK\tGENMASK(9, 0)",
        "u8 drv_type;\t\t/* Current UHS-I driver type */",
        "bool reinit_uhs;\t/* Force UHS-related re-initialization */",
    ):
        if needle not in header:
            raise SystemExit(f"missing clean SDHCI dependency: {needle}")


def resolve_host() -> None:
    path = PATHS[0]
    text = path.read_text()
    text = replace_once(
        text,
        "EXPORT_SYMBOL(mmc_alloc_host);\n\nstatic ssize_t show_enable",
        "EXPORT_SYMBOL(mmc_alloc_host);\n\n"
        "static int mmc_validate_host_caps(struct mmc_host *host)\n"
        "{\n"
        "\tif (host->caps & MMC_CAP_SDIO_IRQ && !host->ops->enable_sdio_irq) {\n"
        "\t\tdev_warn(host->parent, \"missing ->enable_sdio_irq() ops\\n\");\n"
        "\t\treturn -EINVAL;\n"
        "\t}\n\n"
        "\treturn 0;\n"
        "}\n\n"
        "static ssize_t show_enable",
        "host capability validator",
    )
    text = replace_once(
        text,
        "\tWARN_ON((host->caps & MMC_CAP_SDIO_IRQ) &&\n"
        "\t\t!host->ops->enable_sdio_irq);\n\n",
        "\terr = mmc_validate_host_caps(host);\n"
        "\tif (err)\n"
        "\t\treturn err;\n\n",
        "host validation call",
    )
    path.write_text(text)


def resolve_mmc_ops() -> None:
    path = PATHS[1]
    text = path.read_text()
    text = replace_once(
        text,
        "#define MMC_OPS_TIMEOUT_MS\t(10 * 60 * 1000) /* 10 minute timeout */",
        "#define MMC_OPS_TIMEOUT_MS\t\t(10 * 60 * 1000) /* 10min */\n"
        "#define MMC_BKOPS_TIMEOUT_MS\t\t(120 * 1000) /* 120s */\n"
        "#define MMC_CACHE_FLUSH_TIMEOUT_MS\t(30 * 1000) /* 30s */",
        "MMC timeout definitions",
    )
    text = replace_once(
        text,
        "\t/* We have an unspecified cmd timeout, use the fallback value. */\n"
        "\tif (!timeout_ms)\n"
        "\t\ttimeout_ms = MMC_OPS_TIMEOUT_MS;\n\n",
        "",
        "poll fallback removal",
    )
    text = replace_once(
        text,
        "\tmmc_retune_hold(host);\n\n"
        "\t/*\n"
        "\t * If the cmd timeout and the max_busy_timeout of the host are both",
        "\tmmc_retune_hold(host);\n\n"
        "\tif (!timeout_ms) {\n"
        "\t\tpr_warn(\"%s: unspecified timeout for CMD6 - use generic\\n\",\n"
        "\t\t\tmmc_hostname(host));\n"
        "\t\ttimeout_ms = card->ext_csd.generic_cmd6_time;\n"
        "\t}\n\n"
        "\t/*\n"
        "\t * If the cmd timeout and the max_busy_timeout of the host are both",
        "generic CMD6 timeout",
    )
    text = replace_once(
        text,
        "\tif (timeout_ms && host->max_busy_timeout &&\n"
        "\t\t(timeout_ms > host->max_busy_timeout))",
        "\tif (host->max_busy_timeout &&\n"
        "\t    (timeout_ms > host->max_busy_timeout))",
        "host busy-timeout validation",
    )
    text = replace_once(
        text,
        "\t\ttimeout = MMC_OPS_TIMEOUT_MS;",
        "\t\ttimeout = MMC_BKOPS_TIMEOUT_MS;",
        "BKOPS timeout",
    )
    text = replace_once(
        text,
        "\t\terr = mmc_switch(card, EXT_CSD_CMD_SET_NORMAL,\n"
        "\t\t\t\tEXT_CSD_FLUSH_CACHE, 1, 0);",
        "\t\terr = mmc_switch(card, EXT_CSD_CMD_SET_NORMAL,\n"
        "\t\t\t\tEXT_CSD_FLUSH_CACHE, 1,\n"
        "\t\t\t\tMMC_CACHE_FLUSH_TIMEOUT_MS);",
        "cache-flush timeout",
    )
    path.write_text(text)


def resolve_sdhci() -> None:
    path = PATHS[2]
    text = path.read_text()
    text = replace_once(
        text,
        " */\n\n#include <linux/delay.h>",
        " */\n\n#include <linux/bitfield.h>\n#include <linux/delay.h>",
        "bitfield include",
    )
    text = replace_once(
        text,
        "\t\t/* force clock reconfiguration */\n"
        "\t\thost->clock = 0;\n"
        "\t\tmmc->ops->set_ios(mmc, &mmc->ios);",
        "\t\t/* force clock reconfiguration */\n"
        "\t\thost->clock = 0;\n"
        "\t\thost->reinit_uhs = true;\n"
        "\t\tmmc->ops->set_ios(mmc, &mmc->ios);",
        "soft-reset UHS reinitialization",
    )
    text = replace_once(
        text,
        "\t\t\tdiv = (pre_val & SDHCI_PRESET_SDCLK_FREQ_MASK)\n"
        "\t\t\t\t>> SDHCI_PRESET_SDCLK_FREQ_SHIFT;\n"
        "\t\t\tif (host->clk_mul &&\n"
        "\t\t\t\t(pre_val & SDHCI_PRESET_CLKGEN_SEL_MASK)) {",
        "\t\t\tdiv = FIELD_GET(SDHCI_PRESET_SDCLK_FREQ_MASK, pre_val);\n"
        "\t\t\tif (host->clk_mul &&\n"
        "\t\t\t\t(pre_val & SDHCI_PRESET_CLKGEN_SEL)) {",
        "preset clock fields",
    )

    helpers = """static bool sdhci_timing_has_preset(unsigned char timing)
{
\tswitch (timing) {
\tcase MMC_TIMING_UHS_SDR12:
\tcase MMC_TIMING_UHS_SDR25:
\tcase MMC_TIMING_UHS_SDR50:
\tcase MMC_TIMING_UHS_SDR104:
\tcase MMC_TIMING_UHS_DDR50:
\tcase MMC_TIMING_MMC_DDR52:
\t\treturn true;
\t}

\treturn false;
}

static bool sdhci_preset_needed(struct sdhci_host *host,
\t\t\t\tunsigned char timing)
{
\treturn !(host->quirks2 & SDHCI_QUIRK2_PRESET_VALUE_BROKEN) &&
\t       sdhci_timing_has_preset(timing);
}

static bool sdhci_presetable_values_change(struct sdhci_host *host,
\t\t\t\t\t   struct mmc_ios *ios)
{
\t/*
\t * Preset Values are: Driver Strength, Clock Generator and SDCLK/RCLK
\t * Frequency. Check if preset values need to be enabled, or the Driver
\t * Strength needs updating. Note, clock changes are handled separately.
\t */
\treturn !host->preset_enabled &&
\t       (sdhci_preset_needed(host, ios->timing) ||
\t\thost->drv_type != ios->drv_type);
}

"""
    text = replace_once(
        text,
        "void sdhci_set_ios(struct mmc_host *mmc, struct mmc_ios *ios)\n{",
        helpers + "void sdhci_set_ios(struct mmc_host *mmc, struct mmc_ios *ios)\n{",
        "preset helpers",
    )
    text = replace_once(
        text,
        "\tstruct sdhci_host *host = mmc_priv(mmc);\n"
        "\tunsigned long flags;\n"
        "\tu8 ctrl;\n"
        "\tint ret;\n\n"
        "\tif (ios->power_mode == MMC_POWER_UNDEFINED)",
        "\tstruct sdhci_host *host = mmc_priv(mmc);\n"
        "\tunsigned long flags;\n"
        "\tbool reinit_uhs = host->reinit_uhs;\n"
        "\tbool turning_on_clk = false;\n"
        "\tu8 ctrl;\n"
        "\tint ret;\n\n"
        "\thost->reinit_uhs = false;\n\n"
        "\tif (ios->power_mode == MMC_POWER_UNDEFINED)",
        "set_ios state tracking",
    )
    text = replace_once(
        text,
        "\tif (ios->clock &&\n"
        "\t    ((ios->clock != host->clock) || (ios->timing != host->timing))) {\n"
        "\t\tspin_unlock_irqrestore(&host->lock, flags);",
        "\tif (ios->clock &&\n"
        "\t    ((ios->clock != host->clock) || (ios->timing != host->timing))) {\n"
        "\t\tturning_on_clk = !host->clock;\n"
        "\t\tspin_unlock_irqrestore(&host->lock, flags);",
        "clock turn-on tracking",
    )
    text = replace_once(
        text,
        "\thost->ops->set_bus_width(host, ios->bus_width);\n\n"
        "\tctrl = sdhci_readb(host, SDHCI_HOST_CONTROL);",
        "\thost->ops->set_bus_width(host, ios->bus_width);\n\n"
        "\t/*\n"
        "\t * Avoid multiple clock changes during voltage switching when UHS and\n"
        "\t * preset values are already current.\n"
        "\t */\n"
        "\tif (!reinit_uhs &&\n"
        "\t    turning_on_clk &&\n"
        "\t    host->timing == ios->timing &&\n"
        "\t    host->version >= SDHCI_SPEC_300 &&\n"
        "\t    !sdhci_presetable_values_change(host, ios)) {\n"
        "\t\tspin_unlock_irqrestore(&host->lock, flags);\n"
        "\t\tgoto ios_done;\n"
        "\t}\n\n"
        "\tctrl = sdhci_readb(host, SDHCI_HOST_CONTROL);",
        "voltage-switch fast path",
    )
    text = replace_once(
        text,
        "\t\t\tsdhci_writew(host, ctrl_2, SDHCI_HOST_CONTROL2);\n"
        "\t\t} else {",
        "\t\t\tsdhci_writew(host, ctrl_2, SDHCI_HOST_CONTROL2);\n"
        "\t\t\thost->drv_type = ios->drv_type;\n"
        "\t\t} else {",
        "manual driver-strength tracking",
    )
    text = replace_once(
        text,
        "\t\tif (!(host->quirks2 & SDHCI_QUIRK2_PRESET_VALUE_BROKEN) &&\n"
        "\t\t\t\t((ios->timing == MMC_TIMING_UHS_SDR12) ||\n"
        "\t\t\t\t (ios->timing == MMC_TIMING_UHS_SDR25) ||\n"
        "\t\t\t\t (ios->timing == MMC_TIMING_UHS_SDR50) ||\n"
        "\t\t\t\t (ios->timing == MMC_TIMING_UHS_SDR104) ||\n"
        "\t\t\t\t (ios->timing == MMC_TIMING_UHS_DDR50) ||\n"
        "\t\t\t\t (ios->timing == MMC_TIMING_MMC_DDR52))) {",
        "\t\tif (sdhci_preset_needed(host, ios->timing)) {",
        "preset condition",
    )
    text = replace_once(
        text,
        "\t\t\tios->drv_type = (preset & SDHCI_PRESET_DRV_MASK)\n"
        "\t\t\t\t>> SDHCI_PRESET_DRV_SHIFT;\n",
        "\t\t\tios->drv_type = FIELD_GET(SDHCI_PRESET_DRV_MASK,\n"
        "\t\t\t\t\t\t  preset);\n"
        "\t\t\thost->drv_type = ios->drv_type;\n",
        "preset driver-strength field",
    )
    text = replace_once(
        text,
        "\tif (!ios->clock)\n"
        "\t\thost->ops->set_clock(host, ios->clock);\n\n"
        "\tspin_lock_irqsave(&host->lock, flags);",
        "\tif (!ios->clock)\n"
        "\t\thost->ops->set_clock(host, ios->clock);\n\n"
        "ios_done:\n"
        "\tspin_lock_irqsave(&host->lock, flags);",
        "downstream cleanup label",
    )
    text = replace_once(
        text,
        "\t\thost->pwr = 0;\n"
        "\t\thost->clock = 0;\n"
        "\t\tmmc->ops->set_ios(mmc, &mmc->ios);",
        "\t\thost->pwr = 0;\n"
        "\t\thost->clock = 0;\n"
        "\t\thost->reinit_uhs = true;\n"
        "\t\tmmc->ops->set_ios(mmc, &mmc->ios);",
        "system-resume UHS reinitialization",
    )
    text = replace_once(
        text,
        "\t\thost->pwr = 0;\n"
        "\t\thost->clock = 0;\n"
        "\t\tmmc->ops->start_signal_voltage_switch(mmc, &mmc->ios);",
        "\t\thost->pwr = 0;\n"
        "\t\thost->clock = 0;\n"
        "\t\thost->reinit_uhs = true;\n"
        "\t\tmmc->ops->start_signal_voltage_switch(mmc, &mmc->ios);",
        "runtime-resume UHS reinitialization",
    )
    path.write_text(text)


def validate_result() -> None:
    host = PATHS[0].read_text()
    mmc_ops = PATHS[1].read_text()
    sdhci = PATHS[2].read_text()

    host_gates = (
        "static int mmc_validate_host_caps(struct mmc_host *host)",
        'dev_warn(host->parent, "missing ->enable_sdio_irq() ops\\n")',
        "err = mmc_validate_host_caps(host);",
    )
    for needle in host_gates:
        if needle not in host:
            raise SystemExit(f"missing host behavior: {needle}")
    if "WARN_ON((host->caps & MMC_CAP_SDIO_IRQ)" in host:
        raise SystemExit("obsolete SDIO capability warning remains")

    mmc_gates = (
        "#define MMC_BKOPS_TIMEOUT_MS\t\t(120 * 1000)",
        "#define MMC_CACHE_FLUSH_TIMEOUT_MS\t(30 * 1000)",
        "timeout_ms = card->ext_csd.generic_cmd6_time;",
        "timeout = MMC_BKOPS_TIMEOUT_MS;",
        "MMC_CACHE_FLUSH_TIMEOUT_MS);",
        "int retries = 5;",
        "if (retries)",
    )
    for needle in mmc_gates:
        if needle not in mmc_ops:
            raise SystemExit(f"missing MMC timeout/retry behavior: {needle}")
    if "timeout_ms = MMC_OPS_TIMEOUT_MS;" in mmc_ops:
        raise SystemExit("obsolete generic poll fallback remains")

    sdhci_gates = (
        "#include <linux/bitfield.h>",
        "FIELD_GET(SDHCI_PRESET_SDCLK_FREQ_MASK, pre_val)",
        "static bool sdhci_preset_needed(struct sdhci_host *host,",
        "bool reinit_uhs = host->reinit_uhs;",
        "turning_on_clk = !host->clock;",
        "!sdhci_presetable_values_change(host, ios)",
        "goto ios_done;",
        "ios_done:",
        "host->drv_type = ios->drv_type;",
        "host->reinit_uhs = true;",
        "sdhci_cfg_irq(host, true, false);",
    )
    for needle in sdhci_gates:
        if needle not in sdhci:
            raise SystemExit(f"missing SDHCI behavior: {needle}")
    if "SDHCI_PRESET_SDCLK_FREQ_SHIFT" in sdhci:
        raise SystemExit("obsolete preset frequency shift remains")
    if "SDHCI_PRESET_CLKGEN_SEL_MASK" in sdhci:
        raise SystemExit("obsolete preset clock-generator mask remains")
    if sdhci.count("host->reinit_uhs = true;") != 3:
        raise SystemExit("unexpected UHS reinitialization assignment count")

    changed = run("git", "diff", "--name-only", SCAFFOLD, "--", *map(str, PATHS))
    changed_paths = changed.decode().splitlines()
    expected_paths = [str(path) for path in PATHS]
    if changed_paths != expected_paths:
        raise SystemExit(f"unexpected changed path set: {changed_paths}")
    if subprocess.run(
        ["git", "diff", "--quiet", SCAFFOLD, "--", str(HEADER)], check=False
    ).returncode:
        raise SystemExit("clean SDHCI header was modified")

    patch = run("git", "diff", "--binary", "--full-index", SCAFFOLD, "--", *map(str, PATHS))
    digest = hashlib.sha256(patch).hexdigest()
    Path("lts305-mmc-resolution.patch").write_bytes(patch)
    print("resolved_paths=" + ",".join(expected_paths))
    print(f"patch_sha256={digest}")
    print("sdio_host_validation=yes")
    print("mmc_timeout_policy=yes")
    print("sdhci_voltage_switch_fast_path=yes")
    print("downstream_sdio_irq_cleanup_retained=yes")


def main() -> None:
    verify_baseline()
    resolve_host()
    resolve_mmc_ops()
    resolve_sdhci()
    validate_result()


if __name__ == "__main__":
    try:
        main()
    except BaseException as exc:
        diag = Path("lts305-mmc-resolution")
        diag.mkdir(parents=True, exist_ok=True)
        (diag / "resolver-error.txt").write_text(f"{type(exc).__name__}: {exc}\n")
        raise
