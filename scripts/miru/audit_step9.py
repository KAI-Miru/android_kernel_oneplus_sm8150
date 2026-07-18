#!/usr/bin/env python3

from __future__ import annotations

import difflib
import hashlib
import json
import pathlib
import re
import subprocess

BASE = "816f245a4e2afc92ac6119852e33524858410c41"
STABLE = "d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac"
LINEAGE = "0190a01fb1cde1c2ba48e7836084bad818c14d94"
TARGET = pathlib.Path("mm/huge_memory.c")
RELATED = (
    pathlib.Path("include/linux/huge_mm.h"),
    pathlib.Path("include/linux/mm.h"),
    pathlib.Path("include/linux/mm_types.h"),
    pathlib.Path("mm/khugepaged.c"),
    pathlib.Path("mm/memory.c"),
    pathlib.Path("mm/migrate.c"),
    pathlib.Path("mm/mprotect.c"),
    pathlib.Path("mm/mremap.c"),
    pathlib.Path("mm/page_vma_mapped.c"),
    pathlib.Path("mm/rmap.c"),
    pathlib.Path("mm/swap.c"),
)
OUT = pathlib.Path("step9-audit")


def git(*args: str, check: bool = True) -> str:
    proc = subprocess.run(["git", *args], text=True, capture_output=True)
    if check and proc.returncode:
        raise SystemExit(proc.stderr or proc.stdout)
    return proc.stdout


def read_ref(ref: str, path: pathlib.Path) -> str:
    if ref == "current":
        return path.read_text()
    return git("show", f"{ref}:{path}")


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


def write_diff(left_name: str, left: str, right_name: str, right: str) -> None:
    diff = "".join(
        difflib.unified_diff(
            left.splitlines(True),
            right.splitlines(True),
            fromfile=f"{left_name}/{TARGET}",
            tofile=f"{right_name}/{TARGET}",
            n=8,
        )
    )
    (OUT / "diffs" / f"{left_name}-vs-{right_name}.diff").write_text(diff)


def main() -> None:
    (OUT / "sources").mkdir(parents=True, exist_ok=True)
    (OUT / "diffs").mkdir(parents=True, exist_ok=True)
    (OUT / "related").mkdir(parents=True, exist_ok=True)

    refs = {"base": BASE, "h40": "current", "stable": STABLE, "lineage": LINEAGE}
    versions = {name: read_ref(ref, TARGET) for name, ref in refs.items()}

    for name, text in versions.items():
        destination = OUT / "sources" / name / TARGET
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text)

    for left, right in (
        ("base", "h40"),
        ("base", "stable"),
        ("h40", "stable"),
        ("h40", "lineage"),
        ("stable", "lineage"),
    ):
        write_diff(left, versions[left], right, versions[right])

    raw_merge = subprocess.run(
        [
            "git", "merge-file", "-p",
            str(OUT / "sources" / "h40" / TARGET),
            str(OUT / "sources" / "base" / TARGET),
            str(OUT / "sources" / "stable" / TARGET),
        ],
        text=True,
        capture_output=True,
    )
    (OUT / "diffs" / "raw-three-way-merge.txt").write_text(raw_merge.stdout)
    (OUT / "diffs" / "raw-three-way-status.txt").write_text(
        f"returncode={raw_merge.returncode}\n{raw_merge.stderr}"
    )

    history = git(
        "log", "--reverse", "--format=%H%x09%s", f"{BASE}..{STABLE}", "--", str(TARGET)
    )
    (OUT / "stable-history.txt").write_text(history)

    report: dict[str, object] = {
        "branch_head": git("rev-parse", "HEAD").strip(),
        "base": BASE,
        "stable": STABLE,
        "lineage": LINEAGE,
        "target": str(TARGET),
        "versions": {},
        "related": {},
    }

    for name, text in versions.items():
        report["versions"][name] = {
            "lines": len(text.splitlines()),
            "blob_sha": git("hash-object", str(OUT / "sources" / name / TARGET)).strip(),
            "sha256": hashlib.sha256(text.encode()).hexdigest(),
            "functions": function_names(text),
            "selected_lines": selected_lines(text),
        }

    for path in RELATED:
        if not path.exists():
            report["related"][str(path)] = {"missing": True}
            continue
        text = path.read_text()
        destination = OUT / "related" / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text)
        report["related"][str(path)] = {
            "blob_sha": git("hash-object", str(path)).strip(),
            "lines": len(text.splitlines()),
            "functions": function_names(text),
            "selected_lines": selected_lines(text),
        }

    grep = git(
        "grep", "-n", "-E",
        "split_huge_page|split_huge_pmd|change_huge_pmd|copy_huge_pmd|do_huge_pmd|"
        "follow_trans_huge|pmd_trans_huge|pmd_migration|pmd_devmap|deferred_split|"
        "transparent_hugepage|khugepaged|madvise_free_huge_pmd|zap_huge_pmd",
        "--", "include", "mm", "arch/arm64", "arch/arm64/configs", "h40-repro/config",
        check=False,
    )
    (OUT / "tree-api-uses.txt").write_text(grep)

    h40_functions = set(report["versions"]["h40"]["functions"])
    summary = [
        "Miru H.40 Android 4.14.190 Step 9 transparent huge memory audit",
        f"branch_head={report['branch_head']}",
        f"base={BASE}",
        f"stable={STABLE}",
        f"lineage={LINEAGE}",
        "",
    ]
    for name in ("base", "h40", "stable", "lineage"):
        entry = report["versions"][name]
        summary.append(
            f"{name}: lines={entry['lines']} blob={entry['blob_sha']} functions={len(entry['functions'])}"
        )
    for name in ("stable", "lineage"):
        functions = set(report["versions"][name]["functions"])
        summary.append(f"H40-only vs {name}: {sorted(h40_functions - functions)}")
        summary.append(f"{name}-only vs H40: {sorted(functions - h40_functions)}")
    summary.append("")
    summary.append("Stable commits touching mm/huge_memory.c:")
    summary.extend(history.splitlines())
    (OUT / "summary.txt").write_text("\n".join(summary) + "\n")
    (OUT / "audit.json").write_text(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
