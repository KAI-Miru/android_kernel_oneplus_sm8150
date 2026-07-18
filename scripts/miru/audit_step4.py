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
    pathlib.Path("fs/crypto/inline_crypt.c"),
    pathlib.Path("fs/crypto/keyring.c"),
    pathlib.Path("fs/f2fs/checkpoint.c"),
    pathlib.Path("fs/incfs/data_mgmt.c"),
)
OUT = pathlib.Path("step4-audit")


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


def extract_calls(text: str) -> list[str]:
    keywords = {"if", "for", "while", "switch", "return", "sizeof", "typeof"}
    calls = set(re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", text))
    return sorted(calls - keywords)


def token_lines(text: str) -> list[str]:
    tokens = (
        "inline_crypt",
        "inline crypt",
        "blk_crypto",
        "bio_crypt",
        "fscrypt",
        "master_key",
        "keyring",
        "secret",
        "wrapped",
        "crypto_key",
        "ci_key",
        "ci_inline",
        "prepare_key",
        "evict_key",
        "checkpoint",
        "cp_pack",
        "orphan",
        "quota",
        "discard",
        "trim",
        "sit_bitmap",
        "nat_bitmap",
        "kbytes_written",
        "incfs",
        "data_block",
        "pending_read",
        "waitqueue",
        "metadata",
        "hash_block",
        "mutex",
        "rwsem",
        "refcount",
        "atomic",
        "READ_ONCE",
        "WRITE_ONCE",
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


def write_callsite_report(functions: set[str], path: pathlib.Path) -> None:
    safe = str(path).replace("/", "__")
    lines: list[str] = []
    for fn in sorted(functions):
        try:
            matches = git("grep", "-n", "-w", fn, "--", ":!scripts/miru", ":!.github")
        except subprocess.CalledProcessError:
            matches = ""
        selected = [line for line in matches.splitlines() if not line.startswith(f"{path}:")]
        if selected:
            lines.append(f"## {fn}")
            lines.extend(selected[:200])
            lines.append("")
    (OUT / "callsites" / f"{safe}.txt").write_text("\n".join(lines))


def main() -> None:
    (OUT / "diffs").mkdir(parents=True, exist_ok=True)
    (OUT / "sources").mkdir(parents=True, exist_ok=True)
    (OUT / "callsites").mkdir(parents=True, exist_ok=True)

    merge_base = git("merge-base", H40_PARENT, STABLE).strip()
    refs = {
        "base": merge_base,
        "h40": "current",
        "stable": STABLE,
        "lineage": LINEAGE,
    }
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

        comparisons = (
            ("base", "h40"),
            ("base", "stable"),
            ("h40", "stable"),
            ("h40", "lineage"),
            ("stable", "lineage"),
        )
        for left, right in comparisons:
            write_diff(left, versions[left], right, versions[right], path)

        safe = str(path).replace("/", "__")
        merge_proc = subprocess.run(
            ["git", "merge-file", "-p", str(path), f"{merge_base}:{path}", f"{STABLE}:{path}"],
            text=True,
            capture_output=True,
        )
        # git merge-file does not accept tree:path directly, so create a true candidate below.
        base_tmp = OUT / "sources" / "base" / path
        h40_tmp = OUT / "sources" / "h40" / path
        stable_tmp = OUT / "sources" / "stable" / path
        merge_proc = subprocess.run(
            ["git", "merge-file", "-p", str(h40_tmp), str(base_tmp), str(stable_tmp)],
            text=True,
            capture_output=True,
        )
        (OUT / "diffs" / f"{safe}.raw-three-way-merge.txt").write_text(merge_proc.stdout)
        (OUT / "diffs" / f"{safe}.raw-three-way-status.txt").write_text(
            f"returncode={merge_proc.returncode}\n{merge_proc.stderr}"
        )

        entry: dict[str, object] = {}
        all_changed_functions: set[str] = set()
        for name, text in versions.items():
            functions = extract_functions(text)
            entry[name] = {
                "lines": len(text.splitlines()),
                "blob_sha": git("hash-object", str(OUT / "sources" / name / path)).strip(),
                "sha256": sha256(text),
                "functions": functions,
                "exports": extract_exports(text),
                "includes": extract_includes(text),
                "calls": extract_calls(text),
                "token_lines": token_lines(text),
            }
        h40_functions = set(entry["h40"]["functions"])
        for other in ("stable", "lineage"):
            other_functions = set(entry[other]["functions"])
            all_changed_functions.update(h40_functions ^ other_functions)
        write_callsite_report(all_changed_functions, path)
        report["files"][str(path)] = entry

    (OUT / "audit.json").write_text(json.dumps(report, indent=2, sort_keys=True))

    summary = [
        "Miru H.40 Android 4.14.190 Step 4 audit",
        f"branch_head={report['branch_head']}",
        f"h40_parent={H40_PARENT}",
        f"merge_base={merge_base}",
        f"stable={STABLE}",
        f"lineage={LINEAGE}",
        "",
    ]
    for path, entry in report["files"].items():
        summary.append(f"## {path}")
        for name in ("base", "h40", "stable", "lineage"):
            data = entry[name]
            summary.append(
                f"{name}: lines={data['lines']} blob={data['blob_sha']} "
                f"functions={len(data['functions'])} exports={len(data['exports'])}"
            )
        h40 = entry["h40"]
        for other in ("stable", "lineage"):
            rhs = entry[other]
            summary.extend(
                [
                    f"H40 vs {other} removed_functions={sorted(set(h40['functions']) - set(rhs['functions']))}",
                    f"H40 vs {other} added_functions={sorted(set(rhs['functions']) - set(h40['functions']))}",
                    f"H40 vs {other} removed_exports={sorted(set(h40['exports']) - set(rhs['exports']))}",
                    f"H40 vs {other} added_exports={sorted(set(rhs['exports']) - set(h40['exports']))}",
                    f"H40 vs {other} removed_includes={sorted(set(h40['includes']) - set(rhs['includes']))}",
                    f"H40 vs {other} added_includes={sorted(set(rhs['includes']) - set(h40['includes']))}",
                ]
            )
        summary.append("")

    (OUT / "summary.txt").write_text("\n".join(summary) + "\n")


if __name__ == "__main__":
    main()
