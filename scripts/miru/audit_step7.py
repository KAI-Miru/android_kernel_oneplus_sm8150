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
FILES = (
    pathlib.Path("drivers/usb/gadget/composite.c"),
    pathlib.Path("drivers/usb/gadget/function/f_uac1_legacy.c"),
)
RELATED = (
    pathlib.Path("include/linux/usb/composite.h"),
    pathlib.Path("drivers/usb/gadget/function/u_uac1_legacy.h"),
    pathlib.Path("drivers/usb/gadget/function/u_audio.h"),
)
OUT = pathlib.Path("step7-audit")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def read_ref(ref: str, path: pathlib.Path) -> str:
    return path.read_text() if ref == "current" else git("show", f"{ref}:{path}")


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


def token_lines(text: str) -> list[str]:
    tokens = (
        "disconnect", "unbind", "deactivate", "activate", "delayed_status",
        "set_alt", "disable", "setup", "config", "composite", "os_desc",
        "superspeed", "endpoint", "request", "audio", "uac", "speaker",
        "microphone", "playback", "capture", "sample", "volume", "mute",
        "work", "atomic", "spin_lock", "mutex", "free", "kfree", "usb_ep",
        "VENDOR_EDIT", "OPLUS", "qcom", "boot_stats",
    )
    return [
        f"{idx}: {line}" for idx, line in enumerate(text.splitlines(), 1)
        if any(token.lower() in line.lower() for token in tokens)
    ]


def write_diff(left: str, a: str, right: str, b: str, path: pathlib.Path) -> None:
    safe = str(path).replace("/", "__")
    diff = "".join(difflib.unified_diff(
        a.splitlines(True), b.splitlines(True),
        fromfile=f"{left}/{path}", tofile=f"{right}/{path}",
    ))
    (OUT / "diffs" / f"{safe}.{left}-vs-{right}.diff").write_text(diff)


def main() -> None:
    (OUT / "diffs").mkdir(parents=True, exist_ok=True)
    (OUT / "sources").mkdir(parents=True, exist_ok=True)
    (OUT / "related").mkdir(parents=True, exist_ok=True)

    merge_base = git("merge-base", H40_PARENT, STABLE).strip()
    refs = {"base": merge_base, "h40": "current", "stable": STABLE, "lineage": LINEAGE}
    report: dict[str, object] = {
        "branch_head": git("rev-parse", "HEAD").strip(),
        "merge_base": merge_base,
        "stable": STABLE,
        "lineage": LINEAGE,
        "files": {},
        "related": {},
    }

    for path in FILES:
        versions = {name: read_ref(ref, path) for name, ref in refs.items()}
        for name, text in versions.items():
            target = OUT / "sources" / name / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)

        for left, right in (("base", "h40"), ("base", "stable"),
                            ("h40", "stable"), ("h40", "lineage"),
                            ("stable", "lineage")):
            write_diff(left, versions[left], right, versions[right], path)

        base_tmp = OUT / "sources" / "base" / path
        h40_tmp = OUT / "sources" / "h40" / path
        stable_tmp = OUT / "sources" / "stable" / path
        proc = subprocess.run(
            ["git", "merge-file", "-p", str(h40_tmp), str(base_tmp), str(stable_tmp)],
            text=True, capture_output=True,
        )
        safe = str(path).replace("/", "__")
        (OUT / "diffs" / f"{safe}.raw-three-way-merge.txt").write_text(proc.stdout)
        (OUT / "diffs" / f"{safe}.raw-three-way-status.txt").write_text(
            f"returncode={proc.returncode}\n{proc.stderr}"
        )

        entry = {}
        for name, text in versions.items():
            entry[name] = {
                "lines": len(text.splitlines()),
                "blob_sha": git("hash-object", str(OUT / "sources" / name / path)).strip(),
                "sha256": hashlib.sha256(text.encode()).hexdigest(),
                "functions": extract_functions(text),
                "exports": extract_exports(text),
                "token_lines": token_lines(text),
            }
        report["files"][str(path)] = entry

    for path in RELATED:
        if not path.exists():
            report["related"][str(path)] = {"missing": True}
            continue
        text = path.read_text()
        target = OUT / "related" / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
        report["related"][str(path)] = {
            "blob_sha": git("hash-object", str(path)).strip(),
            "lines": len(text.splitlines()),
            "functions": extract_functions(text),
            "token_lines": token_lines(text),
        }

    try:
        grep = git(
            "grep", "-n", "-E",
            "usb_composite_|composite_|f_uac1|uac1_|gaudio_|usb_function_(activate|deactivate)|delayed_status|setup_pending",
            "--", "drivers/usb/gadget", "include/linux/usb", "arch/arm64/configs", "h40-repro/config"
        )
    except subprocess.CalledProcessError:
        grep = ""
    (OUT / "tree-api-uses.txt").write_text(grep)
    (OUT / "audit.json").write_text(json.dumps(report, indent=2, sort_keys=True))

    summary = [
        "Miru H.40 Android 4.14.190 Step 7 USB gadget audit",
        f"branch_head={report['branch_head']}",
        f"merge_base={merge_base}",
        f"stable={STABLE}",
        f"lineage={LINEAGE}",
        "",
    ]
    for path, entry in report["files"].items():
        summary.append(f"## {path}")
        h40 = entry["h40"]
        for name in ("base", "h40", "stable", "lineage"):
            data = entry[name]
            summary.append(
                f"{name}: lines={data['lines']} blob={data['blob_sha']} "
                f"functions={len(data['functions'])} exports={len(data['exports'])}"
            )
        for other in ("stable", "lineage"):
            rhs = entry[other]
            summary.append(
                f"H40 vs {other} removed_functions="
                f"{sorted(set(h40['functions']) - set(rhs['functions']))}"
            )
            summary.append(
                f"H40 vs {other} added_functions="
                f"{sorted(set(rhs['functions']) - set(h40['functions']))}"
            )
            summary.append(
                f"H40 vs {other} removed_exports="
                f"{sorted(set(h40['exports']) - set(rhs['exports']))}"
            )
            summary.append(
                f"H40 vs {other} added_exports="
                f"{sorted(set(rhs['exports']) - set(h40['exports']))}"
            )
        summary.append("")
    (OUT / "summary.txt").write_text("\n".join(summary) + "\n")


if __name__ == "__main__":
    main()
