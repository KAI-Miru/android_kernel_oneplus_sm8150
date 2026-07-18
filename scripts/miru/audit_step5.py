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
    pathlib.Path("drivers/mmc/core/Kconfig"),
    pathlib.Path("drivers/mmc/core/block.c"),
    pathlib.Path("drivers/mmc/host/sdhci-msm.c"),
    pathlib.Path("include/linux/mmc/host.h"),
)
OUT = pathlib.Path("step5-audit")


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


def extract_symbols(text: str) -> list[str]:
    symbols = set(re.findall(r"\b(?:CONFIG_|MMC_|SDHCI_|CQHCI_|BLK_|REQ_|R1_)[A-Z0-9_]+", text))
    symbols.update(re.findall(r"\bmmc_[A-Za-z0-9_]+", text))
    symbols.update(re.findall(r"\bsdhci_[A-Za-z0-9_]+", text))
    return sorted(symbols)


def token_lines(text: str) -> list[str]:
    tokens = (
        "cmdq", "cqe", "cqhci", "crypto", "ice", "inline", "wrapped",
        "rpmb", "sanitize", "secure erase", "discard", "trim", "packed",
        "reliable", "cache", "bkops", "retune", "tuning", "hs400", "hs200",
        "ddr", "uhs", "sdio", "sd card", "mmcblk", "boot partition",
        "queue", "request", "timeout", "recovery", "reset", "power", "voltage",
        "vqmmc", "vmmc", "clock", "clk", "dll", "bus vote", "interconnect",
        "pm_qos", "devfreq", "scaling", "thermal", "wake", "irq", "dma",
        "adma", "quirk", "caps", "host->", "ops->", "vendor", "oplus", "oppo",
        "qcom", "msm", "sysfs", "debugfs", "trace", "runtime_pm", "suspend",
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
            a.splitlines(True), b.splitlines(True),
            fromfile=f"{a_name}/{path}", tofile=f"{b_name}/{path}",
        )
    )
    (OUT / "diffs" / f"{safe}.{a_name}-vs-{b_name}.diff").write_text(diff)


def write_dependency_report(path: pathlib.Path, functions: set[str], symbols: set[str]) -> None:
    safe = str(path).replace("/", "__")
    lines: list[str] = []
    terms = sorted(functions | {s for s in symbols if s.startswith(("MMC_", "SDHCI_", "CONFIG_"))})
    for term in terms:
        try:
            matches = git("grep", "-n", "-w", term, "--", ":!scripts/miru", ":!.github")
        except subprocess.CalledProcessError:
            matches = ""
        selected = [line for line in matches.splitlines() if not line.startswith(f"{path}:")]
        if selected:
            lines.append(f"## {term}")
            lines.extend(selected[:120])
            lines.append("")
    (OUT / "dependencies" / f"{safe}.txt").write_text("\n".join(lines))


def main() -> None:
    for sub in ("diffs", "sources", "dependencies"):
        (OUT / sub).mkdir(parents=True, exist_ok=True)

    merge_base = git("merge-base", H40_PARENT, STABLE).strip()
    refs = {"base": merge_base, "h40": "current", "stable": STABLE, "lineage": LINEAGE}
    report: dict[str, object] = {
        "branch_head": git("rev-parse", "HEAD").strip(),
        "h40_parent": H40_PARENT,
        "merge_base": merge_base,
        "stable": STABLE,
        "lineage": LINEAGE,
        "files": {},
    }

    for path in FILES:
        versions = {name: read_ref(ref, path) for name, ref in refs.items()}
        for name, text in versions.items():
            target = OUT / "sources" / name / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)

        for left, right in (("base", "h40"), ("base", "stable"), ("h40", "stable"),
                            ("h40", "lineage"), ("stable", "lineage")):
            write_diff(left, versions[left], right, versions[right], path)

        base_tmp = OUT / "sources" / "base" / path
        h40_tmp = OUT / "sources" / "h40" / path
        stable_tmp = OUT / "sources" / "stable" / path
        merge = subprocess.run(
            ["git", "merge-file", "-p", str(h40_tmp), str(base_tmp), str(stable_tmp)],
            text=True, capture_output=True,
        )
        safe = str(path).replace("/", "__")
        (OUT / "diffs" / f"{safe}.raw-three-way-merge.txt").write_text(merge.stdout)
        (OUT / "diffs" / f"{safe}.raw-three-way-status.txt").write_text(
            f"returncode={merge.returncode}\n{merge.stderr}"
        )

        entry: dict[str, object] = {}
        changed_functions: set[str] = set()
        changed_symbols: set[str] = set()
        for name, text in versions.items():
            functions = extract_functions(text)
            symbols = extract_symbols(text)
            entry[name] = {
                "lines": len(text.splitlines()),
                "blob_sha": git("hash-object", str(OUT / "sources" / name / path)).strip(),
                "sha256": sha256(text),
                "functions": functions,
                "symbols": symbols,
                "token_lines": token_lines(text),
            }
        h40_functions = set(entry["h40"]["functions"])
        h40_symbols = set(entry["h40"]["symbols"])
        for other in ("stable", "lineage"):
            changed_functions.update(h40_functions ^ set(entry[other]["functions"]))
            changed_symbols.update(h40_symbols ^ set(entry[other]["symbols"]))
        write_dependency_report(path, changed_functions, changed_symbols)
        report["files"][str(path)] = entry

    (OUT / "audit.json").write_text(json.dumps(report, indent=2, sort_keys=True))

    lines = [
        "Miru H.40 Android 4.14.190 Step 5 MMC/SDHCI audit",
        f"branch_head={report['branch_head']}",
        f"merge_base={merge_base}",
        f"stable={STABLE}",
        f"lineage={LINEAGE}",
        "",
    ]
    for path, entry in report["files"].items():
        lines.append(f"## {path}")
        for name in ("base", "h40", "stable", "lineage"):
            data = entry[name]
            lines.append(
                f"{name}: lines={data['lines']} blob={data['blob_sha']} "
                f"functions={len(data['functions'])} symbols={len(data['symbols'])}"
            )
        h40 = entry["h40"]
        for other in ("stable", "lineage"):
            rhs = entry[other]
            lines.append(f"H40 vs {other} removed_functions={sorted(set(h40['functions']) - set(rhs['functions']))}")
            lines.append(f"H40 vs {other} added_functions={sorted(set(rhs['functions']) - set(h40['functions']))}")
            lines.append(f"H40 vs {other} removed_symbols={sorted(set(h40['symbols']) - set(rhs['symbols']))}")
            lines.append(f"H40 vs {other} added_symbols={sorted(set(rhs['symbols']) - set(h40['symbols']))}")
        lines.append("")
    (OUT / "summary.txt").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
