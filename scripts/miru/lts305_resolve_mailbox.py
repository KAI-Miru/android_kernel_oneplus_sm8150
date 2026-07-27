#!/usr/bin/env python3
"""Resolve the authentic mailbox polling-timer conflict for Miru H.40 4.14.305."""

from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

SCAFFOLD = "b92a77e96dd54fd30f8f39c7eef23e76f211c515"
TARGET = "4415bf5e08942aee6487946a3e0a50956ef68f1e"
PATH = Path("drivers/mailbox/mailbox.c")
HEADER = Path("include/linux/mailbox_controller.h")
EXPECTED_SCAFFOLD_BLOB = "d40f47d98c8d08ca428648f64acb68e80bd7f038"
EXPECTED_HEADER_BLOB = "4868590fa0d52c9307f6afc9607b75720a1c063e"


def run(*args: str) -> bytes:
    return subprocess.check_output(list(args))


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    head = run("git", "rev-parse", "HEAD").decode().strip()
    for ancestor in (SCAFFOLD, TARGET):
        if subprocess.run(
            ["git", "merge-base", "--is-ancestor", ancestor, head], check=False
        ).returncode:
            raise SystemExit(f"required ancestor {ancestor} is not an ancestor of {head}")

    scaffold_blob = run("git", "rev-parse", f"{SCAFFOLD}:{PATH}").decode().strip()
    header_blob = run("git", "rev-parse", f"{SCAFFOLD}:{HEADER}").decode().strip()
    if scaffold_blob != EXPECTED_SCAFFOLD_BLOB:
        raise SystemExit(f"unexpected mailbox scaffold blob: {scaffold_blob}")
    if header_blob != EXPECTED_HEADER_BLOB:
        raise SystemExit(f"unexpected mailbox header blob: {header_blob}")
    if run("git", "rev-parse", f"HEAD:{HEADER}").decode().strip() != EXPECTED_HEADER_BLOB:
        raise SystemExit("cleanly merged mailbox header drifted after scaffold")
    if subprocess.run(
        ["git", "diff", "--quiet", SCAFFOLD, "--", str(PATH)], check=False
    ).returncode:
        raise SystemExit(f"owned path drifted after scaffold: {PATH}")

    text = PATH.read_text()
    text = replace_once(
        text,
        "static void msg_submit(struct mbox_chan *chan)\n"
        "{\n"
        "\tint err = 0;\n",
        "static void msg_submit(struct mbox_chan *chan)\n"
        "{\n"
        "\tunsigned long flags;\n"
        "\tint err = 0;\n",
        "msg_submit lock flags",
    )
    text = replace_once(
        text,
        "\t/* kick start the timer immediately to avoid delays */\n"
        "\tif (!err && (chan->txdone_method & TXDONE_BY_POLL)) {\n"
        "\t\t/* but only if not already active */\n"
        "\t\tif (!hrtimer_active(&chan->mbox->poll_hrt))\n"
        "\t\t\thrtimer_start(&chan->mbox->poll_hrt, 0, HRTIMER_MODE_REL);\n"
        "\t}\n",
        "\tif (!err && (chan->txdone_method & TXDONE_BY_POLL)) {\n"
        "\t\t/* kick start the timer immediately to avoid delays */\n"
        "\t\tspin_lock_irqsave(&chan->mbox->poll_hrt_lock, flags);\n"
        "\t\thrtimer_start(&chan->mbox->poll_hrt, 0, HRTIMER_MODE_REL);\n"
        "\t\tspin_unlock_irqrestore(&chan->mbox->poll_hrt_lock, flags);\n"
        "\t}\n",
        "serialized timer start",
    )
    text = replace_once(
        text,
        "\tbool txdone, resched = false;\n"
        "\tint i;\n",
        "\tbool txdone, resched = false;\n"
        "\tint i;\n"
        "\tunsigned long flags;\n",
        "txdone timer lock flags",
    )
    text = replace_once(
        text,
        "\t\tif (chan->active_req && chan->cl) {\n"
        "\t\t\tresched = true;\n"
        "\t\t\ttxdone = chan->mbox->ops->last_tx_done(chan);\n"
        "\t\t\tif (txdone)\n"
        "\t\t\t\ttx_tick(chan, 0);\n"
        "\t\t}\n",
        "\t\tif (chan->active_req && chan->cl) {\n"
        "\t\t\ttxdone = chan->mbox->ops->last_tx_done(chan);\n"
        "\t\t\tif (txdone)\n"
        "\t\t\t\ttx_tick(chan, 0);\n"
        "\t\t\telse\n"
        "\t\t\t\tresched = true;\n"
        "\t\t}\n",
        "reschedule only incomplete transfers",
    )
    text = replace_once(
        text,
        "\tif (resched) {\n"
        "\t\thrtimer_forward_now(hrtimer, ms_to_ktime(mbox->txpoll_period));\n"
        "\t\treturn HRTIMER_RESTART;\n"
        "\t}\n",
        "\tif (resched) {\n"
        "\t\tspin_lock_irqsave(&mbox->poll_hrt_lock, flags);\n"
        "\t\tif (!hrtimer_is_queued(hrtimer))\n"
        "\t\t\thrtimer_forward_now(hrtimer,\n"
        "\t\t\t\t\t    ms_to_ktime(mbox->txpoll_period));\n"
        "\t\tspin_unlock_irqrestore(&mbox->poll_hrt_lock, flags);\n\n"
        "\t\treturn HRTIMER_RESTART;\n"
        "\t}\n",
        "serialized timer forward",
    )
    text = replace_once(
        text,
        "\t\thrtimer_init(&mbox->poll_hrt, CLOCK_MONOTONIC,\n"
        "\t\t\t     HRTIMER_MODE_REL);\n"
        "\t\tmbox->poll_hrt.function = txdone_hrtimer;\n",
        "\t\thrtimer_init(&mbox->poll_hrt, CLOCK_MONOTONIC,\n"
        "\t\t\t     HRTIMER_MODE_REL);\n"
        "\t\tmbox->poll_hrt.function = txdone_hrtimer;\n"
        "\t\tspin_lock_init(&mbox->poll_hrt_lock);\n",
        "poll timer lock initialization",
    )

    gates = {
        "downstream submit helper": "static int __msg_submit(struct mbox_chan *chan)",
        "downstream EAGAIN retry": "} while (err == -EAGAIN);",
        "timer start lock": "spin_lock_irqsave(&chan->mbox->poll_hrt_lock, flags);",
        "timer start unlock": "spin_unlock_irqrestore(&chan->mbox->poll_hrt_lock, flags);",
        "timer forward lock": "spin_lock_irqsave(&mbox->poll_hrt_lock, flags);",
        "timer queued guard": "if (!hrtimer_is_queued(hrtimer))",
        "timer lock initialization": "spin_lock_init(&mbox->poll_hrt_lock);",
    }
    for label, needle in gates.items():
        if needle not in text:
            raise SystemExit(f"missing resolved mailbox behavior: {label}")
    if "hrtimer_active(&chan->mbox->poll_hrt)" in text:
        raise SystemExit("obsolete lockless hrtimer_active gate remains")
    if text.count("poll_hrt_lock") != 5:
        raise SystemExit("unexpected poll_hrt_lock use count")
    if text.count("hrtimer_start(&chan->mbox->poll_hrt, 0, HRTIMER_MODE_REL);") != 1:
        raise SystemExit("unexpected polling timer start count")
    if text.count("resched = true;") != 1:
        raise SystemExit("unexpected mailbox reschedule assignment count")

    PATH.write_text(text)
    changed = run("git", "diff", "--name-only", SCAFFOLD, "--", str(PATH)).decode().splitlines()
    if changed != [str(PATH)]:
        raise SystemExit(f"unexpected changed path set: {changed}")
    patch = run("git", "diff", "--binary", "--full-index", SCAFFOLD, "--", str(PATH))
    digest = hashlib.sha256(patch).hexdigest()
    Path("lts305-mailbox-resolution.patch").write_bytes(patch)
    print(f"resolved_path={PATH}")
    print(f"patch_sha256={digest}")
    print("clean_header_lock_retained=yes")
    print("downstream_eagain_retry_retained=yes")
    print("poll_timer_serialization_imported=yes")


if __name__ == "__main__":
    try:
        main()
    except BaseException as exc:
        diag = Path("lts305-mailbox-resolution")
        diag.mkdir(parents=True, exist_ok=True)
        (diag / "resolver-error.txt").write_text(f"{type(exc).__name__}: {exc}\n")
        raise
