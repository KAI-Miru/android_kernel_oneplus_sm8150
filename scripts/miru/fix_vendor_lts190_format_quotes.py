#!/usr/bin/env python3

from __future__ import annotations

import argparse
import pathlib
import subprocess

EXPECTED_BLOBS = {
    "oplus/kernel/of2fs/super.c": "fac7d29c5d9dc062c4bcff70b0577daf014e5738",
    "oplus/kernel_4.14/ext4/super.c": "8ee559014d0b8d6e6bda5a14a782c0087f8faf10",
}


def git_blob(path: pathlib.Path) -> str:
    return subprocess.check_output(["git", "hash-object", str(path)], text=True).strip()


def replace_exact(text: str, old: str, new: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(
            f"format-quote guard expected {expected}, found {count}: {old!r}"
        )
    return text.replace(old, new, expected)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("vendor_root", type=pathlib.Path)
    parser.add_argument("--report", type=pathlib.Path)
    args = parser.parse_args()

    root = args.vendor_root.resolve()
    paths = {rel: root / rel for rel in EXPECTED_BLOBS}
    for rel, path in paths.items():
        if not path.is_file():
            raise SystemExit(f"missing migrated vendor file: {path}")
        actual = git_blob(path)
        expected = EXPECTED_BLOBS[rel]
        if actual != expected:
            raise SystemExit(
                f"{rel}: expected migrated blob {expected}, found {actual}"
            )

    for path in paths.values():
        text = path.read_text()
        text = replace_exact(
            text,
            '"Value of option "%s" is unrecognized"',
            '"Value of option \\"%s\\" is unrecognized"',
        )
        text = replace_exact(
            text,
            '"Error processing option "%s" [%d]"',
            '"Error processing option \\"%s\\" [%d]"',
        )
        path.write_text(text)

    report_lines = [
        "Miru H.40 Android 4.14.190 vendor format-string correction",
        "",
        "Cause: build-time migration emitted unescaped nested quotes around %s.",
        "The compiler therefore parsed s as an identifier; no variable was missing.",
        "",
    ]
    for rel, path in paths.items():
        text = path.read_text()
        if 'option "%s"' in text or 'option \\"%s\\"' not in text:
            raise SystemExit(f"{rel}: quote correction semantic guard failed")
        report_lines.append(f"{rel}: git_blob={git_blob(path)}")

    report = "\n".join(report_lines) + "\n"
    print(report, end="")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(report)


if __name__ == "__main__":
    main()
