#!/usr/bin/env python3
"""Compare extracted stock boot/recovery DTs with rebuilt DTB/DTBO files."""

from __future__ import annotations

import argparse
import hashlib
from collections import defaultdict
from pathlib import Path


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def relative(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stock_extraction", type=Path)
    parser.add_argument("rebuilt_tree", type=Path)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()

    stock_sets = {
        "boot_dtb": sorted((args.stock_extraction / "boot-dtbs").glob("*.dtb")),
        "recovery_dtbo": sorted((args.stock_extraction / "recovery-dtbo-entries").glob("*.dtb")),
    }
    rebuilt = sorted(path for path in args.rebuilt_tree.rglob("*") if path.is_file() and path.suffix in {".dtb", ".dtbo"})
    rebuilt_by_hash: dict[str, list[Path]] = defaultdict(list)
    for path in rebuilt:
        rebuilt_by_hash[digest(path)].append(path)

    total = exact = 0
    lines = [
        f"stock_extraction={args.stock_extraction.resolve()}",
        f"rebuilt_tree={args.rebuilt_tree.resolve()}",
        f"rebuilt_files={len(rebuilt)}",
    ]
    missing_by_kind: dict[str, int] = {}
    for kind, paths in stock_sets.items():
        kind_exact = 0
        lines.append("")
        lines.append(f"[{kind}]")
        for path in paths:
            total += 1
            checksum = digest(path)
            matches = rebuilt_by_hash.get(checksum, [])
            if matches:
                exact += 1
                kind_exact += 1
                result = ",".join(relative(match, args.rebuilt_tree) for match in matches)
            else:
                result = "MISSING"
            lines.append(f"{path.name}\tsize={path.stat().st_size}\tsha256={checksum}\t{result}")
        missing_by_kind[kind] = len(paths) - kind_exact
        lines.append(f"{kind}_summary=stock:{len(paths)},exact:{kind_exact},missing:{len(paths) - kind_exact}")

    lines[:3] += [f"stock_files={total}", f"exact_matches={exact}", f"missing={total - exact}"]
    for kind, count in sorted(missing_by_kind.items()):
        lines.insert(6, f"missing_{kind}={count}")

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text("\n".join(lines) + "\n")
    print("\n".join(lines[:8]))
    return 1 if total != exact else 0


if __name__ == "__main__":
    raise SystemExit(main())
