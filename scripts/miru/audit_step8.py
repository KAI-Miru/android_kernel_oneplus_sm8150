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
    pathlib.Path("include/net/netfilter/nf_conntrack.h"),
    pathlib.Path("net/ipv4/sysctl_net_ipv4.c"),
    pathlib.Path("net/qrtr/qrtr.c"),
)
RELATED = (
    pathlib.Path("net/netfilter/nf_conntrack_core.c"),
    pathlib.Path("net/netfilter/nf_conntrack_standalone.c"),
    pathlib.Path("include/net/net_namespace.h"),
    pathlib.Path("include/net/netns/ipv4.h"),
    pathlib.Path("include/net/sock.h"),
    pathlib.Path("include/uapi/linux/qrtr.h"),
)
OUT = pathlib.Path("step8-audit")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def read_ref(ref: str, path: pathlib.Path) -> str:
    return path.read_text() if ref == "current" else git("show", f"{ref}:{path}")


def functions(text: str) -> list[str]:
    p = re.compile(r"^(?:static\s+)?(?:inline\s+)?(?:__\w+\s+)*(?:[A-Za-z_][\w\s\*]+?)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;{}]*\)\s*\{", re.M)
    return sorted(set(p.findall(text)))


def tokens(text: str) -> list[str]:
    keys = (
        "conntrack", "nf_ct", "tuplehash", "status", "timeout", "expect",
        "zone", "netns", "sysctl", "register_net_sysctl", "procname",
        "data", "extra1", "extra2", "qrtr", "sock", "sk", "release",
        "shutdown", "reset", "node", "port", "work", "refcount", "rcu",
        "spin_lock", "mutex", "list_del", "hash_del", "VENDOR_EDIT", "OPLUS",
    )
    return [f"{i}: {line}" for i, line in enumerate(text.splitlines(), 1)
            if any(k.lower() in line.lower() for k in keys)]


def write_diff(a_name: str, a: str, b_name: str, b: str, path: pathlib.Path) -> None:
    safe = str(path).replace("/", "__")
    diff = "".join(difflib.unified_diff(a.splitlines(True), b.splitlines(True),
                                         fromfile=f"{a_name}/{path}", tofile=f"{b_name}/{path}"))
    (OUT / "diffs" / f"{safe}.{a_name}-vs-{b_name}.diff").write_text(diff)


def main() -> None:
    (OUT / "diffs").mkdir(parents=True, exist_ok=True)
    (OUT / "sources").mkdir(parents=True, exist_ok=True)
    (OUT / "related").mkdir(parents=True, exist_ok=True)
    base = git("merge-base", H40_PARENT, STABLE).strip()
    refs = {"base": base, "h40": "current", "stable": STABLE, "lineage": LINEAGE}
    report: dict[str, object] = {
        "branch_head": git("rev-parse", "HEAD").strip(),
        "merge_base": base,
        "stable": STABLE,
        "lineage": LINEAGE,
        "files": {},
        "related": {},
    }

    for path in FILES:
        versions = {name: read_ref(ref, path) for name, ref in refs.items()}
        for name, text in versions.items():
            dst = OUT / "sources" / name / path
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text(text)
        for left, right in (("base", "h40"), ("base", "stable"),
                            ("h40", "stable"), ("h40", "lineage"),
                            ("stable", "lineage")):
            write_diff(left, versions[left], right, versions[right], path)
        proc = subprocess.run(
            ["git", "merge-file", "-p", str(OUT / "sources" / "h40" / path),
             str(OUT / "sources" / "base" / path),
             str(OUT / "sources" / "stable" / path)],
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
                "functions": functions(text),
                "tokens": tokens(text),
            }
        report["files"][str(path)] = entry

    for path in RELATED:
        if not path.exists():
            report["related"][str(path)] = {"missing": True}
            continue
        text = path.read_text()
        dst = OUT / "related" / path
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(text)
        report["related"][str(path)] = {
            "blob_sha": git("hash-object", str(path)).strip(),
            "lines": len(text.splitlines()),
            "functions": functions(text),
            "tokens": tokens(text),
        }

    try:
        grep = git("grep", "-n", "-E",
                   "nf_conn|sysctl_net_ipv4|register_net_sysctl|qrtr_|AF_QIPCRTR|sock_orphan|sk_common_release|sk_prot_clear_nulls|sk_refcnt",
                   "--", "include/net", "net/netfilter", "net/ipv4", "net/qrtr", "arch/arm64/configs", "h40-repro/config")
    except subprocess.CalledProcessError:
        grep = ""
    (OUT / "tree-api-uses.txt").write_text(grep)
    (OUT / "audit.json").write_text(json.dumps(report, indent=2, sort_keys=True))

    summary = [
        "Miru H.40 Android 4.14.190 Step 8 networking audit",
        f"branch_head={report['branch_head']}",
        f"merge_base={base}",
        f"stable={STABLE}",
        f"lineage={LINEAGE}",
        "",
    ]
    for path, entry in report["files"].items():
        summary.append(f"## {path}")
        h40 = entry["h40"]
        for name in ("base", "h40", "stable", "lineage"):
            d = entry[name]
            summary.append(f"{name}: lines={d['lines']} blob={d['blob_sha']} functions={len(d['functions'])}")
        for other in ("stable", "lineage"):
            d = entry[other]
            summary.append(f"H40 vs {other} removed_functions={sorted(set(h40['functions']) - set(d['functions']))}")
            summary.append(f"H40 vs {other} added_functions={sorted(set(d['functions']) - set(h40['functions']))}")
        summary.append("")
    (OUT / "summary.txt").write_text("\n".join(summary) + "\n")


if __name__ == "__main__":
    main()
