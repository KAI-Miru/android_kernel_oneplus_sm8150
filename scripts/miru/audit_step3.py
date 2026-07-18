#!/usr/bin/env python3

from __future__ import annotations

import difflib
import hashlib
import json
import pathlib
import re
import subprocess

STABLE = "d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac"
LINEAGE = "0190a01fb1cde1c2ba48e7836084bad818c14d94"
FILES = (
    pathlib.Path("drivers/md/dm-default-key.c"),
    pathlib.Path("fs/block_dev.c"),
    pathlib.Path("include/linux/fs.h"),
)
OUT = pathlib.Path("step3-audit")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()


def read_ref(ref: str, path: pathlib.Path) -> str:
    if ref == "h40":
        return path.read_text()
    return git("show", f"{ref}:{path}")


def extract_functions(text: str) -> list[str]:
    pattern = re.compile(
        r"^(?:static\s+)?(?:inline\s+)?(?:[A-Za-z_][\w\s\*]+?)\s+"
        r"([A-Za-z_][A-Za-z0-9_]*)\s*\([^;{}]*\)\s*\{",
        re.M,
    )
    return sorted(set(pattern.findall(text)))


def extract_prototypes(text: str) -> list[str]:
    result = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.endswith(";") and "(" in stripped and ")" in stripped:
            if not stripped.startswith(("#", "typedef", "return", "if", "for", "while")):
                result.append(stripped)
    return sorted(set(result))


def extract_exports(text: str) -> list[str]:
    return sorted(set(re.findall(r"EXPORT_SYMBOL(?:_GPL)?\(([^)]+)\)", text)))


def extract_struct(text: str, name: str) -> str | None:
    match = re.search(rf"struct\s+{re.escape(name)}\s*\{{", text)
    if not match:
        return None
    start = match.start()
    pos = match.end()
    depth = 1
    while pos < len(text) and depth:
        if text[pos] == "{":
            depth += 1
        elif text[pos] == "}":
            depth -= 1
        pos += 1
    if depth:
        return None
    end = text.find(";", pos)
    if end == -1:
        return None
    return text[start : end + 1]


def token_lines(text: str) -> list[str]:
    tokens = (
        "dm-default-key",
        "inline_crypt",
        "inline encryption",
        "blk_crypto",
        "bio_crypt",
        "bio_dun",
        "keyring",
        "fscrypt",
        "bdev",
        "bd_holder",
        "bd_super",
        "bd_claim",
        "bd_start_claiming",
        "freeze_bdev",
        "thaw_bdev",
        "invalidate_bdev",
        "FMODE_EXCL",
        "GENHD_FL_UP",
        "BLKDEV",
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


def main() -> None:
    (OUT / "diffs").mkdir(parents=True, exist_ok=True)
    (OUT / "sources").mkdir(parents=True, exist_ok=True)

    refs = {"h40": "h40", "stable": STABLE, "lineage": LINEAGE}
    report: dict[str, object] = {
        "branch_head": git("rev-parse", "HEAD").strip(),
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

        write_diff("h40", versions["h40"], "stable", versions["stable"], path)
        write_diff("h40", versions["h40"], "lineage", versions["lineage"], path)
        write_diff("stable", versions["stable"], "lineage", versions["lineage"], path)

        entry: dict[str, object] = {}
        for name, text in versions.items():
            entry[name] = {
                "lines": len(text.splitlines()),
                "sha256": sha256(text),
                "functions": extract_functions(text),
                "prototypes": extract_prototypes(text),
                "exports": extract_exports(text),
                "token_lines": token_lines(text),
            }

        for struct_name in ("block_device", "super_block", "file", "inode"):
            structs = {
                name: extract_struct(text, struct_name)
                for name, text in versions.items()
            }
            if any(value is not None for value in structs.values()):
                entry.setdefault("structs", {})[struct_name] = structs

        report["files"][str(path)] = entry

    (OUT / "audit.json").write_text(json.dumps(report, indent=2, sort_keys=True))

    summary = [
        "Miru H.40 Android 4.14.190 Step 3 audit",
        f"branch_head={report['branch_head']}",
        f"stable={STABLE}",
        f"lineage={LINEAGE}",
        "",
    ]
    for path, entry in report["files"].items():
        summary.append(f"## {path}")
        for name in ("h40", "stable", "lineage"):
            data = entry[name]
            summary.append(
                f"{name}: lines={data['lines']} sha256={data['sha256']} "
                f"functions={len(data['functions'])} exports={len(data['exports'])}"
            )
        h40 = entry["h40"]
        for other in ("stable", "lineage"):
            rhs = entry[other]
            removed_functions = sorted(set(h40["functions"]) - set(rhs["functions"]))
            added_functions = sorted(set(rhs["functions"]) - set(h40["functions"]))
            removed_exports = sorted(set(h40["exports"]) - set(rhs["exports"]))
            added_exports = sorted(set(rhs["exports"]) - set(h40["exports"]))
            summary.extend(
                [
                    f"H40 vs {other} removed_functions={removed_functions}",
                    f"H40 vs {other} added_functions={added_functions}",
                    f"H40 vs {other} removed_exports={removed_exports}",
                    f"H40 vs {other} added_exports={added_exports}",
                ]
            )
        summary.append("")

    (OUT / "summary.txt").write_text("\n".join(summary) + "\n")


if __name__ == "__main__":
    main()
