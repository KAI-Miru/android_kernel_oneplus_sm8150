#!/usr/bin/env python3
"""Resolve the authentic EDAC device polling conflict for Miru H.40 4.14.305."""

from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

SCAFFOLD = "b92a77e96dd54fd30f8f39c7eef23e76f211c515"
PATH = Path("drivers/edac/edac_device.c")
EXPECTED_SCAFFOLD_BLOB = "5426925da924d88bb86ad5e12646abf0963825d4"


def run(*args: str) -> bytes:
    return subprocess.check_output(list(args))


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    head = run("git", "rev-parse", "HEAD").decode().strip()
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", SCAFFOLD, head], check=False
    ).returncode:
        raise SystemExit(f"scaffold {SCAFFOLD} is not an ancestor of {head}")
    scaffold_blob = run("git", "rev-parse", f"{SCAFFOLD}:{PATH}").decode().strip()
    if scaffold_blob != EXPECTED_SCAFFOLD_BLOB:
        raise SystemExit(f"unexpected scaffold blob: {scaffold_blob}")
    if subprocess.run(
        ["git", "diff", "--quiet", SCAFFOLD, "--", str(PATH)], check=False
    ).returncode:
        raise SystemExit(f"owned path drifted after scaffold: {PATH}")

    text = PATH.read_text()
    text = replace_once(
        text,
        "static DEFINE_MUTEX(device_ctls_mutex);\n"
        "static LIST_HEAD(edac_device_list);\n\n"
        "#ifdef CONFIG_EDAC_DEBUG",
        "static DEFINE_MUTEX(device_ctls_mutex);\n"
        "static LIST_HEAD(edac_device_list);\n\n"
        "/* Default workqueue processing interval on this instance, in msecs */\n"
        "#define DEFAULT_POLL_INTERVAL 1000\n\n"
        "#ifdef CONFIG_EDAC_DEBUG",
        "default interval definition",
    )

    if text.count("if (edac_dev->poll_msec == 1000)") != 2:
        raise SystemExit("unexpected pre-resolution 1000-ms comparison count")
    text = text.replace(
        "if (edac_dev->poll_msec == 1000)",
        "if (edac_dev->poll_msec == DEFAULT_POLL_INTERVAL)",
    )

    text = replace_once(
        text,
        "\t/* take the arg 'msec' and set it into the control structure\n"
        "\t * to used in the time period calculation\n"
        "\t * then calc the number of jiffies that represents. Also, force\n"
        "\t * polling period to 1 second if it is smaller than that, as\n"
        "\t * anything less than 1 second does not make sense.\n"
        "\t */\n"
        "\tif (msec <= 1000) {\n"
        "\t\tedac_device_printk(edac_dev, KERN_WARNING,\n"
        "\t\t\t\t   \"Forcing polling period to 1 second\\n\");\n"
        "\t\tmsec = 1000;\n"
        "\t}\n\n",
        "\t/* take the arg 'msec' and set it into the control structure\n"
        "\t * to used in the time period calculation\n"
        "\t * then calc the number of jiffies that represents\n"
        "\t */\n",
        "driver-supplied polling interval",
    )

    text = replace_once(
        text,
        "void edac_device_reset_delay_period(struct edac_device_ctl_info *edac_dev,\n"
        "\t\t\t\t\tunsigned long value)\n"
        "{\n"
        "\tunsigned long jiffs = msecs_to_jiffies(value);\n\n"
        "\tif (value == 1000)\n"
        "\t\tjiffs = round_jiffies_relative(value);\n\n"
        "\tedac_dev->poll_msec = value;\n"
        "\tedac_dev->delay\t    = jiffs;\n\n"
        "\tedac_mod_work(&edac_dev->work, jiffs);\n"
        "}",
        "void edac_device_reset_delay_period(struct edac_device_ctl_info *edac_dev,\n"
        "\t\t\t\t    unsigned long msec)\n"
        "{\n"
        "\tedac_dev->poll_msec = msec;\n"
        "\tedac_dev->delay\t    = msecs_to_jiffies(msec);\n\n"
        "\t/* See comment in edac_device_workq_setup() above */\n"
        "\tif (edac_dev->poll_msec == DEFAULT_POLL_INTERVAL)\n"
        "\t\tedac_mod_work(&edac_dev->work,\n"
        "\t\t\t      round_jiffies_relative(edac_dev->delay));\n"
        "\telse\n"
        "\t\tedac_mod_work(&edac_dev->work, edac_dev->delay);\n"
        "}",
        "reset-delay calculation",
    )

    text = replace_once(
        text,
        "\t\t/*\n"
        "\t\t * enable workq processing on this instance,\n"
        "\t\t * default = 1000 msec\n"
        "\t\t */\n"
        "\t\tedac_device_workq_setup(edac_dev, edac_dev->poll_msec);",
        "\t\tedac_device_workq_setup(edac_dev,\n"
        "\t\t\t\t\tedac_dev->poll_msec ?: DEFAULT_POLL_INTERVAL);",
        "driver polling value setup",
    )

    gates = {
        "default interval": "#define DEFAULT_POLL_INTERVAL 1000",
        "deferrable work retained": "if (edac_dev->defer_work)",
        "deferrable initializer retained": "INIT_DEFERRABLE_WORK(&edac_dev->work,",
        "reset uses converted delay": "edac_dev->delay\t    = msecs_to_jiffies(msec);",
        "reset rounds converted delay": "round_jiffies_relative(edac_dev->delay)",
        "driver interval default": "edac_dev->poll_msec ?: DEFAULT_POLL_INTERVAL",
    }
    for label, needle in gates.items():
        if needle not in text:
            raise SystemExit(f"missing resolved EDAC behavior: {label}")
    if "Forcing polling period to 1 second" in text or "if (msec <= 1000)" in text:
        raise SystemExit("obsolete EDAC sub-second forcing remains")
    if text.count("DEFAULT_POLL_INTERVAL") != 5:
        raise SystemExit("unexpected DEFAULT_POLL_INTERVAL use count")

    PATH.write_text(text)
    changed = run("git", "diff", "--name-only", SCAFFOLD, "--", str(PATH)).decode().splitlines()
    if changed != [str(PATH)]:
        raise SystemExit(f"unexpected changed path set: {changed}")
    patch = run("git", "diff", "--binary", "--full-index", SCAFFOLD, "--", str(PATH))
    digest = hashlib.sha256(patch).hexdigest()
    Path("lts305-edac-device-resolution.patch").write_bytes(patch)
    print(f"resolved_path={PATH}")
    print(f"patch_sha256={digest}")
    print("defer_work_retained=yes")
    print("driver_poll_interval_respected=yes")
    print("reset_delay_rounding_fixed=yes")


if __name__ == "__main__":
    try:
        main()
    except BaseException as exc:
        diag = Path("lts305-edac-device-resolution")
        diag.mkdir(parents=True, exist_ok=True)
        (diag / "resolver-error.txt").write_text(f"{type(exc).__name__}: {exc}\n")
        raise
