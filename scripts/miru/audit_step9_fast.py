#!/usr/bin/env python3

from __future__ import annotations

import difflib
import hashlib
import json
import pathlib
import re
import urllib.request

BASE = "816f245a4e2afc92ac6119852e33524858410c41"
STABLE = "d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac"
LINEAGE = "0190a01fb1cde1c2ba48e7836084bad818c14d94"
TARGET = pathlib.Path("mm/huge_memory.c")
OUT = pathlib.Path("step9-fast-audit")


def download(ref: str) -> str:
    url = f"https://raw.githubusercontent.com/LineageOS/android_kernel_oneplus_sm8150/{ref}/{TARGET}"
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read().decode("utf-8")


def function_names(text: str) -> list[str]:
    pattern = re.compile(
        r"^(?:static\s+)?(?:inline\s+)?(?:__\w+\s+)*(?:[A-Za-z_][\w\s\*]+?)\s+"
        r"([A-Za-z_][A-Za-z0-9_]*)\s*\([^;{}]*\)\s*\{",
        re.M,
    )
    return sorted(set(pattern.findall(text)))


def selected_lines(text: str) -> list[str]:
    keys = (
        "split_huge", "collapse_huge", "change_huge", "copy_huge",
        "do_huge", "follow_trans", "huge_pmd", "huge_zero", "pmd_trans",
        "pmd_migration", "pmd_devmap", "pmd_write", "pmd_dirty", "pmd_young",
        "pmdp", "mmu_notifier", "madvise", "deferred_split", "page_vma",
        "freeze", "anon_vma", "memcg", "migration", "FOLL_", "VM_",
        "READ_ONCE", "WRITE_ONCE", "barrier", "lock", "spin", "VENDOR_EDIT",
        "OPLUS", "CONFIG_",
    )
    return [
        f"{number}: {line}"
        for number, line in enumerate(text.splitlines(), 1)
        if any(key.lower() in line.lower() for key in keys)
    ]


def write_version(name: str, text: str) -> None:
    path = OUT / "sources" / name / TARGET
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def write_diff(left_name: str, left: str, right_name: str, right: str) -> None:
    diff = "".join(
        difflib.unified_diff(
            left.splitlines(True), right.splitlines(True),
            fromfile=f"{left_name}/{TARGET}", tofile=f"{right_name}/{TARGET}", n=10,
        )
    )
    (OUT / "diffs" / f"{left_name}-vs-{right_name}.diff").write_text(diff)


def main() -> None:
    (OUT / "diffs").mkdir(parents=True, exist_ok=True)
    versions = {
        "base": download(BASE),
        "h40": TARGET.read_text(),
        "stable": download(STABLE),
        "lineage": download(LINEAGE),
    }
    for name, text in versions.items():
        write_version(name, text)
    for left, right in (
        ("base", "h40"), ("base", "stable"), ("h40", "stable"),
        ("h40", "lineage"), ("stable", "lineage"),
    ):
        write_diff(left, versions[left], right, versions[right])

    report = {"refs": {"base": BASE, "stable": STABLE, "lineage": LINEAGE}, "versions": {}}
    for name, text in versions.items():
        report["versions"][name] = {
            "lines": len(text.splitlines()),
            "sha1": hashlib.sha1(text.encode()).hexdigest(),
            "sha256": hashlib.sha256(text.encode()).hexdigest(),
            "functions": function_names(text),
            "selected_lines": selected_lines(text),
        }
    (OUT / "audit.json").write_text(json.dumps(report, indent=2, sort_keys=True))

    h40f = set(report["versions"]["h40"]["functions"])
    lines = ["Miru Step 9 fast THP source comparison", ""]
    for name in ("base", "h40", "stable", "lineage"):
        item = report["versions"][name]
        lines.append(f"{name}: lines={item['lines']} sha1={item['sha1']} functions={len(item['functions'])}")
    for name in ("stable", "lineage"):
        funcs = set(report["versions"][name]["functions"])
        lines.append(f"H40-only vs {name}: {sorted(h40f - funcs)}")
        lines.append(f"{name}-only vs H40: {sorted(funcs - h40f)}")
    (OUT / "summary.txt").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
