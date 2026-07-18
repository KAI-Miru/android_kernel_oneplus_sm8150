#!/usr/bin/env python3

from __future__ import annotations

import difflib
import hashlib
import json
import pathlib
import re
import subprocess

H40_PARENT = "59858c8f798778f4e6c1c4449baba631e353600e"
STABLE = "d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac"
LINEAGE = "0190a01fb1cde1c2ba48e7836084bad818c14d94"
TARGET = pathlib.Path("drivers/scsi/ufs/ufs-qcom.c")
RELATED = (
    pathlib.Path("drivers/scsi/ufs/ufs-qcom.h"),
    pathlib.Path("drivers/scsi/ufs/ufshcd.h"),
    pathlib.Path("drivers/scsi/ufs/ufshcd-crypto-qti.h"),
    pathlib.Path("drivers/scsi/ufs/ufs-qcom-ice.c"),
)
OUT = pathlib.Path("step6-audit")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()


def read_ref(ref: str, path: pathlib.Path) -> str:
    if ref == "current":
        return path.read_text()
    return git("show", f"{ref}:{path}")


def extract_functions(text: str) -> list[str]:
    pattern = re.compile(
        r"^(?:static\s+)?(?:inline\s+)?(?:__\w+\s+)*"
        r"(?:[A-Za-z_][\w\s\*]+?)\s+([A-Za-z_][A-Za-z0-9_]*)"
        r"\s*\([^;{}]*\)\s*\{",
        re.M,
    )
    return sorted(set(pattern.findall(text)))


def extract_exports(text: str) -> list[str]:
    return sorted(set(re.findall(r"EXPORT_SYMBOL(?:_GPL)?\(([^)]+)\)", text)))


def extract_includes(text: str) -> list[str]:
    return sorted(set(re.findall(r'^#include\s+[<"]([^>"]+)[>"]', text, re.M)))


def extract_defines(text: str) -> list[str]:
    return sorted(set(re.findall(r"^#define\s+([A-Za-z_][A-Za-z0-9_]*)", text, re.M)))


def token_lines(text: str) -> list[str]:
    tokens = (
        "crypto",
        "ice",
        "wrapped",
        "keyslot",
        "hibern8",
        "suspend",
        "resume",
        "runtime",
        "bus_vote",
        "devfreq",
        "clock",
        "clk",
        "reset",
        "phy",
        "lane",
        "link_startup",
        "power_change",
        "gear",
        "qos",
        "regulator",
        "vcc",
        "vdd",
        "pm_runtime",
        "save",
        "restore",
        "testbus",
        "quirk",
        "caps",
        "UFS_QCOM",
        "VENDOR_EDIT",
        "OPLUS",
    )
    return [
        f"{idx}: {line}"
        for idx, line in enumerate(text.splitlines(), 1)
        if any(token.lower() in line.lower() for token in tokens)
    ]


def write_diff(a_name: str, a: str, b_name: str, b: str, path: pathlib.Path) -> None:
    safe = str(path).replace("/", "__")
    diff = "".join(
        difflib.unified_diff(
            a.splitlines(True),
            b.splitlines(True),
            fromfile=f"{a_name}/{path}",
            tofile=f"{b_name}/{path}",
        )
    )
    (OUT / "diffs" / f"{safe}.{a_name}-vs-{b_name}.diff").write_text(diff)


def write_callsites(functions: set[str]) -> None:
    lines: list[str] = []
    for fn in sorted(functions):
        try:
            matches = git("grep", "-n", "-w", fn, "--", "drivers/scsi/ufs", "include")
        except subprocess.CalledProcessError:
            matches = ""
        selected = [line for line in matches.splitlines() if not line.startswith(f"{TARGET}:")]
        if selected:
            lines.append(f"## {fn}")
            lines.extend(selected[:200])
            lines.append("")
    (OUT / "callsites.txt").write_text("\n".join(lines))


def main() -> None:
    (OUT / "diffs").mkdir(parents=True, exist_ok=True)
    (OUT / "sources").mkdir(parents=True, exist_ok=True)
    (OUT / "related").mkdir(parents=True, exist_ok=True)

    merge_base = git("merge-base", H40_PARENT, STABLE).strip()
    refs = {
        "base": merge_base,
        "h40": "current",
        "stable": STABLE,
        "lineage": LINEAGE,
    }
    versions = {name: read_ref(ref, TARGET) for name, ref in refs.items()}

    for name, text in versions.items():
        target = OUT / "sources" / name / TARGET
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    for left, right in (
        ("base", "h40"),
        ("base", "stable"),
        ("h40", "stable"),
        ("h40", "lineage"),
        ("stable", "lineage"),
    ):
        write_diff(left, versions[left], right, versions[right], TARGET)

    base_tmp = OUT / "sources" / "base" / TARGET
    h40_tmp = OUT / "sources" / "h40" / TARGET
    stable_tmp = OUT / "sources" / "stable" / TARGET
    merge_proc = subprocess.run(
        ["git", "merge-file", "-p", str(h40_tmp), str(base_tmp), str(stable_tmp)],
        text=True,
        capture_output=True,
    )
    safe = str(TARGET).replace("/", "__")
    (OUT / "diffs" / f"{safe}.raw-three-way-merge.txt").write_text(merge_proc.stdout)
    (OUT / "diffs" / f"{safe}.raw-three-way-status.txt").write_text(
        f"returncode={merge_proc.returncode}\n{merge_proc.stderr}"
    )

    report: dict[str, object] = {
        "branch_head": git("rev-parse", "HEAD").strip(),
        "h40_parent": H40_PARENT,
        "merge_base": merge_base,
        "stable": STABLE,
        "lineage": LINEAGE,
        "target": str(TARGET),
        "versions": {},
        "related": {},
    }

    changed_functions: set[str] = set()
    h40_functions = set(extract_functions(versions["h40"]))
    for name, text in versions.items():
        functions = extract_functions(text)
        report["versions"][name] = {
            "lines": len(text.splitlines()),
            "blob_sha": git("hash-object", str(OUT / "sources" / name / TARGET)).strip(),
            "sha256": sha256(text),
            "functions": functions,
            "exports": extract_exports(text),
            "includes": extract_includes(text),
            "defines": extract_defines(text),
            "token_lines": token_lines(text),
        }
        if name in ("stable", "lineage"):
            changed_functions.update(h40_functions ^ set(functions))
    write_callsites(changed_functions)

    for path in RELATED:
        if not path.exists():
            report["related"][str(path)] = {"missing": True}
            continue
        text = path.read_text()
        target = OUT / "related" / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
        report["related"][str(path)] = {
            "lines": len(text.splitlines()),
            "blob_sha": git("hash-object", str(path)).strip(),
            "functions": extract_functions(text),
            "exports": extract_exports(text),
            "includes": extract_includes(text),
            "defines": extract_defines(text),
            "token_lines": token_lines(text),
        }

    try:
        grep = git(
            "grep", "-n", "-E",
            "ufs_qcom_|ufshcd_qti_|ufs_qcom_ice|UFS_QCOM|QTI_UFS|crypto_capabilities|keyslot|bus_vote|pm_qos",
            "--", "drivers/scsi/ufs", "include", "arch/arm64/configs", "h40-repro/config"
        )
    except subprocess.CalledProcessError:
        grep = ""
    (OUT / "tree-api-uses.txt").write_text(grep)

    (OUT / "audit.json").write_text(json.dumps(report, indent=2, sort_keys=True))

    summary = [
        "Miru H.40 Android 4.14.190 Step 6 UFS audit",
        f"branch_head={report['branch_head']}",
        f"h40_parent={H40_PARENT}",
        f"merge_base={merge_base}",
        f"stable={STABLE}",
        f"lineage={LINEAGE}",
        "",
    ]
    h40 = report["versions"]["h40"]
    for name in ("base", "h40", "stable", "lineage"):
        data = report["versions"][name]
        summary.append(
            f"{name}: lines={data['lines']} blob={data['blob_sha']} "
            f"functions={len(data['functions'])} exports={len(data['exports'])} "
            f"defines={len(data['defines'])}"
        )
    for other in ("stable", "lineage"):
        rhs = report["versions"][other]
        summary.extend(
            [
                f"H40 vs {other} removed_functions={sorted(set(h40['functions']) - set(rhs['functions']))}",
                f"H40 vs {other} added_functions={sorted(set(rhs['functions']) - set(h40['functions']))}",
                f"H40 vs {other} removed_exports={sorted(set(h40['exports']) - set(rhs['exports']))}",
                f"H40 vs {other} added_exports={sorted(set(rhs['exports']) - set(h40['exports']))}",
                f"H40 vs {other} removed_includes={sorted(set(h40['includes']) - set(rhs['includes']))}",
                f"H40 vs {other} added_includes={sorted(set(rhs['includes']) - set(h40['includes']))}",
                f"H40 vs {other} removed_defines={sorted(set(h40['defines']) - set(rhs['defines']))}",
                f"H40 vs {other} added_defines={sorted(set(rhs['defines']) - set(h40['defines']))}",
            ]
        )
    summary.append("")
    summary.append("## Related H.40 files")
    for path, data in report["related"].items():
        if data.get("missing"):
            summary.append(f"{path}: missing")
        else:
            summary.append(
                f"{path}: lines={data['lines']} blob={data['blob_sha']} "
                f"functions={len(data['functions'])} defines={len(data['defines'])}"
            )
    (OUT / "summary.txt").write_text("\n".join(summary) + "\n")


if __name__ == "__main__":
    main()
