#!/usr/bin/env python3
"""Resolve the authentic Qualcomm GLINK conflict for Miru H.40 LTS 4.14.305."""

from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

SCAFFOLD = "b92a77e96dd54fd30f8f39c7eef23e76f211c515"
PATH = Path("drivers/rpmsg/qcom_glink_native.c")
EXPECTED_SCAFFOLD_BLOB = "8619ee6481eff7304146506b4db595c13cfbcef1"
OLD = "\t\tstrlcpy(chinfo.name, channel->name, sizeof(chinfo.name));"
NEW = "\t\tstrscpy_pad(chinfo.name, channel->name, sizeof(chinfo.name));"


def run(*args: str) -> bytes:
    return subprocess.check_output(list(args))


def section(text: str, start_marker: str, end_marker: str) -> str:
    start = text.index(start_marker)
    end = text.index(end_marker, start + len(start_marker))
    return text[start:end]


def main() -> None:
    head = run("git", "rev-parse", "HEAD").decode().strip()
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", SCAFFOLD, head], check=False
    ).returncode:
        raise SystemExit(f"scaffold {SCAFFOLD} is not an ancestor of {head}")

    scaffold_blob = run("git", "rev-parse", f"{SCAFFOLD}:{PATH}").decode().strip()
    if scaffold_blob != EXPECTED_SCAFFOLD_BLOB:
        raise SystemExit(
            f"unexpected scaffold blob for {PATH}: {scaffold_blob}"
        )
    if subprocess.run(
        ["git", "diff", "--quiet", SCAFFOLD, "--", str(PATH)], check=False
    ).returncode:
        raise SystemExit(f"owned path drifted after scaffold: {PATH}")

    text = PATH.read_text()
    rx_close = section(
        text,
        "static void qcom_glink_rx_close(",
        "static void qcom_glink_rx_close_ack(",
    )
    rx_close_ack = section(
        text,
        "static void qcom_glink_rx_close_ack(",
        "static void qcom_glink_work(",
    )
    intr = section(
        text,
        "static irqreturn_t qcom_glink_native_intr(",
        "/* Locally initiated rpmsg_create_ept */",
    )

    if rx_close.count(OLD) != 1 or NEW in rx_close:
        raise SystemExit("unexpected qcom_glink_rx_close string-copy state")
    if rx_close_ack.count(OLD) != 1:
        raise SystemExit("downstream qcom_glink_rx_close_ack behavior drifted")

    protected = {
        "missing-channel intent FIFO advance":
            "qcom_glink_rx_advance(glink, ALIGN(msglen, 8));",
        "missing-local-intent error": "ret = -ENOENT;",
        "missing-local-intent drain": "goto advance_rx;",
        "RX payload advance":
            "qcom_glink_rx_advance(glink, ALIGN(sizeof(hdr) + chunk_size, 8));",
    }
    for label, needle in protected.items():
        if needle not in text:
            raise SystemExit(f"protected GLINK behavior missing: {label}")
    if "if (ret == -ENOENT)" in intr:
        raise SystemExit("GLINK interrupt path still suppresses -ENOENT")
    if "if (ret)\n\t\t\tbreak;" not in intr:
        raise SystemExit("GLINK interrupt error propagation drifted")

    resolved_rx_close = rx_close.replace(OLD, NEW, 1)
    text = text.replace(rx_close, resolved_rx_close, 1)
    if text.count(NEW) != 1:
        raise SystemExit("expected exactly one strscpy_pad GLINK close conversion")
    if text.count(OLD) != 1:
        raise SystemExit("downstream close-ack copy should remain the sole strlcpy")
    if "strncpy(chinfo.name" in text:
        raise SystemExit("deprecated chinfo strncpy remains")

    PATH.write_text(text)

    changed = run("git", "diff", "--name-only", SCAFFOLD, "--", str(PATH)).decode().splitlines()
    if changed != [str(PATH)]:
        raise SystemExit(f"unexpected changed path set: {changed}")
    numstat = run("git", "diff", "--numstat", SCAFFOLD, "--", str(PATH)).decode().strip()
    if numstat != f"1\t1\t{PATH}":
        raise SystemExit(f"unexpected GLINK diff size: {numstat}")

    patch = run("git", "diff", "--binary", "--full-index", SCAFFOLD, "--", str(PATH))
    if OLD.encode() not in patch or NEW.encode() not in patch:
        raise SystemExit("canonical patch lacks the reviewed GLINK replacement")
    digest = hashlib.sha256(patch).hexdigest()
    Path("lts305-glink-resolution.patch").write_bytes(patch)
    print(f"resolved_path={PATH}")
    print(f"patch_sha256={digest}")
    print("protected_glink_gates=PASS")


if __name__ == "__main__":
    try:
        main()
    except BaseException as exc:
        diag = Path("lts305-glink-resolution")
        diag.mkdir(parents=True, exist_ok=True)
        (diag / "resolver-error.txt").write_text(f"{type(exc).__name__}: {exc}\n")
        raise
