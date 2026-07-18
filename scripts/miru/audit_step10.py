#!/usr/bin/env python3

from __future__ import annotations

import difflib
import hashlib
import json
import pathlib
import re
import subprocess
import urllib.request

BASE = "816f245a4e2afc92ac6119852e33524858410c41"
STABLE = "d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac"
LINEAGE = "0190a01fb1cde1c2ba48e7836084bad818c14d94"
FILES = (
    pathlib.Path("sound/core/compress_offload.c"),
    pathlib.Path("sound/core/rawmidi.c"),
)
RELATED = (
    pathlib.Path("include/sound/compress_driver.h"),
    pathlib.Path("include/sound/compress_offload.h"),
    pathlib.Path("include/sound/rawmidi.h"),
    pathlib.Path("sound/core/compress_debug.c"),
    pathlib.Path("sound/core/rawmidi_compat.c"),
)
OUT = pathlib.Path("step10-audit")


def git(*args: str, check: bool = True) -> str:
    proc = subprocess.run(["git", *args], text=True, capture_output=True)
    if check and proc.returncode:
        raise SystemExit(proc.stderr or proc.stdout)
    return proc.stdout


def download(ref: str, path: pathlib.Path) -> str:
    url = f"https://raw.githubusercontent.com/LineageOS/android_kernel_oneplus_sm8150/{ref}/{path}"
    with urllib.request.urlopen(url, timeout=90) as response:
        return response.read().decode("utf-8")


def functions(text: str) -> list[str]:
    pattern = re.compile(
        r"^(?:static\s+)?(?:inline\s+)?(?:__\w+\s+)*(?:[A-Za-z_][\w\s\*]+?)\s+"
        r"([A-Za-z_][A-Za-z0-9_]*)\s*\([^;{}]*\)\s*\{",
        re.M,
    )
    return sorted(set(pattern.findall(text)))


def exports(text: str) -> list[str]:
    return sorted(set(re.findall(r"EXPORT_SYMBOL(?:_GPL)?\(([^)]+)\)", text)))


def selected_lines(text: str) -> list[str]:
    keys = (
        "SNDRV_PCM_STATE", "trigger", "drain", "pause", "resume", "stop",
        "error_work", "runtime", "fragment", "buffer", "copy", "mmap",
        "ioctl", "lock", "mutex", "spin_lock", "realloc", "resize", "avail",
        "appl_ptr", "hw_ptr", "append", "event_work", "disconnect", "free",
        "wait_event", "wake_up", "compat", "VENDOR_EDIT", "OPLUS", "qcom",
    )
    return [
        f"{number}: {line}"
        for number, line in enumerate(text.splitlines(), 1)
        if any(key.lower() in line.lower() for key in keys)
    ]


def write_diff(path: pathlib.Path, left_name: str, left: str,
               right_name: str, right: str) -> None:
    safe = str(path).replace("/", "__")
    diff = "".join(
        difflib.unified_diff(
            left.splitlines(True), right.splitlines(True),
            fromfile=f"{left_name}/{path}", tofile=f"{right_name}/{path}", n=10,
        )
    )
    (OUT / "diffs" / f"{safe}.{left_name}-vs-{right_name}.diff").write_text(diff)


def main() -> None:
    (OUT / "sources").mkdir(parents=True, exist_ok=True)
    (OUT / "related").mkdir(parents=True, exist_ok=True)
    (OUT / "diffs").mkdir(parents=True, exist_ok=True)

    report: dict[str, object] = {
        "branch_head": git("rev-parse", "HEAD").strip(),
        "refs": {"base": BASE, "stable": STABLE, "lineage": LINEAGE},
        "files": {},
        "related": {},
    }

    for path in FILES:
        versions = {
            "base": download(BASE, path),
            "h40": path.read_text(),
            "stable": download(STABLE, path),
            "lineage": download(LINEAGE, path),
        }
        for name, text in versions.items():
            destination = OUT / "sources" / name / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(text)

        for left, right in (
            ("base", "h40"), ("base", "stable"), ("h40", "stable"),
            ("h40", "lineage"), ("stable", "lineage"),
        ):
            write_diff(path, left, versions[left], right, versions[right])

        base_file = OUT / "sources" / "base" / path
        h40_file = OUT / "sources" / "h40" / path
        stable_file = OUT / "sources" / "stable" / path
        merge = subprocess.run(
            ["git", "merge-file", "-p", str(h40_file), str(base_file), str(stable_file)],
            text=True, capture_output=True,
        )
        safe = str(path).replace("/", "__")
        (OUT / "diffs" / f"{safe}.raw-three-way-merge.txt").write_text(merge.stdout)
        (OUT / "diffs" / f"{safe}.raw-three-way-status.txt").write_text(
            f"returncode={merge.returncode}\n{merge.stderr}"
        )

        entry = {}
        for name, text in versions.items():
            entry[name] = {
                "lines": len(text.splitlines()),
                "git_blob": git("hash-object", str(OUT / "sources" / name / path)).strip(),
                "sha256": hashlib.sha256(text.encode()).hexdigest(),
                "functions": functions(text),
                "exports": exports(text),
                "selected_lines": selected_lines(text),
            }
        report["files"][str(path)] = entry

    for path in RELATED:
        if not path.exists():
            report["related"][str(path)] = {"missing": True}
            continue
        text = path.read_text()
        destination = OUT / "related" / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text)
        report["related"][str(path)] = {
            "lines": len(text.splitlines()),
            "git_blob": git("hash-object", str(path)).strip(),
            "functions": functions(text),
            "selected_lines": selected_lines(text),
        }

    grep = git(
        "grep", "-n", "-E",
        "snd_compr_|snd_rawmidi_|realloc_mutex|error_work|SNDRV_COMPRESS_|"
        "SNDRV_RAWMIDI_|buffer_size|avail_min|appl_ptr|hw_ptr",
        "--", "include/sound", "sound", "arch/arm64/configs", "h40-repro/config",
        check=False,
    )
    (OUT / "tree-api-uses.txt").write_text(grep)
    (OUT / "audit.json").write_text(json.dumps(report, indent=2, sort_keys=True))

    summary = [
        "Miru H.40 Android 4.14.190 Step 10 ALSA core audit",
        f"branch_head={report['branch_head']}",
        f"base={BASE}",
        f"stable={STABLE}",
        f"lineage={LINEAGE}",
        "",
    ]
    for path, entry in report["files"].items():
        summary.append(f"## {path}")
        h40_functions = set(entry["h40"]["functions"])
        h40_exports = set(entry["h40"]["exports"])
        for name in ("base", "h40", "stable", "lineage"):
            item = entry[name]
            summary.append(
                f"{name}: lines={item['lines']} blob={item['git_blob']} "
                f"functions={len(item['functions'])} exports={len(item['exports'])}"
            )
        for name in ("stable", "lineage"):
            item = entry[name]
            summary.append(
                f"H40-only functions vs {name}: "
                f"{sorted(h40_functions - set(item['functions']))}"
            )
            summary.append(
                f"{name}-only functions vs H40: "
                f"{sorted(set(item['functions']) - h40_functions)}"
            )
            summary.append(
                f"H40-only exports vs {name}: "
                f"{sorted(h40_exports - set(item['exports']))}"
            )
            summary.append(
                f"{name}-only exports vs H40: "
                f"{sorted(set(item['exports']) - h40_exports)}"
            )
        summary.append("")
    (OUT / "summary.txt").write_text("\n".join(summary) + "\n")


if __name__ == "__main__":
    main()
