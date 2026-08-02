#!/usr/bin/env python3
"""Resolve the STMMAC sub-second increment conflict for Miru H.40 4.14.305."""

from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

SCAFFOLD = "b92a77e96dd54fd30f8f39c7eef23e76f211c515"
PATH = Path("drivers/net/ethernet/stmicro/stmmac/stmmac_hwtstamp.c")
HEADER = Path("drivers/net/ethernet/stmicro/stmmac/stmmac_ptp.h")
EXPECTED_SCAFFOLD_BLOB = "a0063307b04c34276ae956d12026ae06298e5bb5"
EXPECTED_HEADER_BLOB = "aa222e0cdce86e00a11d699fd66afb70ea747e23"


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
        raise SystemExit(f"unexpected scaffold source blob: {scaffold_blob}")
    if subprocess.run(
        ["git", "diff", "--quiet", SCAFFOLD, "--", str(PATH)], check=False
    ).returncode:
        raise SystemExit(f"owned path drifted after scaffold: {PATH}")

    scaffold_header = run("git", "rev-parse", f"{SCAFFOLD}:{HEADER}").decode().strip()
    current_header = run("git", "rev-parse", f"HEAD:{HEADER}").decode().strip()
    if scaffold_header != EXPECTED_HEADER_BLOB or current_header != EXPECTED_HEADER_BLOB:
        raise SystemExit(
            f"unexpected clean header blob: scaffold={scaffold_header} current={current_header}"
        )

    text = PATH.read_text()
    text = replace_once(
        text,
        "\tss_inc &= PTP_SSIR_SSINC_MASK;\n"
        "\tsns_inc &= PTP_SSIR_SNSINC_MASK;",
        "\tif (ss_inc > PTP_SSIR_SSINC_MAX)\n"
        "\t\tss_inc = PTP_SSIR_SSINC_MAX;\n"
        "\tsns_inc &= PTP_SSIR_SNSINC_MASK;",
        "sub-second increment clamp",
    )

    required = {
        "upper-bound comparison": "if (ss_inc > PTP_SSIR_SSINC_MAX)",
        "upper-bound assignment": "ss_inc = PTP_SSIR_SSINC_MAX;",
        "fractional increment retained": "sns_inc = div_u64((sns_inc * 256), ptpclock);",
        "fractional mask retained": "sns_inc &= PTP_SSIR_SNSINC_MASK;",
        "gmac4 shift retained": "reg_value <<= GMAC4_PTP_SSIR_SSINC_SHIFT;",
        "fractional register field retained": "reg_value |= (sns_inc << GMAC4_PTP_SSIR_SNSINC_SHIFT);",
    }
    for label, needle in required.items():
        if needle not in text:
            raise SystemExit(f"missing resolved STMMAC behavior: {label}")
    if "PTP_SSIR_SSINC_MASK" in text:
        raise SystemExit("obsolete STMMAC SSINC mask reference remains")
    if text.count("PTP_SSIR_SSINC_MAX") != 2:
        raise SystemExit("unexpected PTP_SSIR_SSINC_MAX use count")

    PATH.write_text(text)
    changed = run("git", "diff", "--name-only", SCAFFOLD, "--", str(PATH)).decode().splitlines()
    if changed != [str(PATH)]:
        raise SystemExit(f"unexpected changed path set: {changed}")
    if run("git", "rev-parse", f"HEAD:{HEADER}").decode().strip() != EXPECTED_HEADER_BLOB:
        raise SystemExit("clean STMMAC header changed during resolution")

    patch = run("git", "diff", "--binary", "--full-index", SCAFFOLD, "--", str(PATH))
    digest = hashlib.sha256(patch).hexdigest()
    Path("lts305-stmmac-hwtstamp-resolution.patch").write_bytes(patch)
    print(f"resolved_path={PATH}")
    print(f"patch_sha256={digest}")
    print("ssinc_saturating_clamp=yes")
    print("fractional_increment_retained=yes")
    print("clean_header_retained=yes")


if __name__ == "__main__":
    try:
        main()
    except BaseException as exc:
        diag = Path("lts305-stmmac-hwtstamp-resolution")
        diag.mkdir(parents=True, exist_ok=True)
        (diag / "resolver-error.txt").write_text(f"{type(exc).__name__}: {exc}\n")
        raise
