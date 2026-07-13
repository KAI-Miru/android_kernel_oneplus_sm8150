#!/usr/bin/env python3
"""Compare stock /proc/kallsyms with rebuilt System.map and optional vmlinux."""

from __future__ import annotations

import argparse
import subprocess
from bisect import bisect_left
from collections import Counter
from pathlib import Path


def read_stock(path: Path):
    result = []
    modules = Counter()
    nonzero = 0
    for line in path.read_text(errors="replace").splitlines():
        parts = line.split()
        if not parts:
            continue
        nonzero += parts[0] != "0000000000000000"
        if len(parts) > 3:
            modules[parts[3].strip("[]")] += 1
        elif len(parts) == 3:
            result.append((parts[1], parts[2]))
    return result, modules, nonzero


def read_map(path: Path):
    result = []
    for line in path.read_text(errors="replace").splitlines():
        parts = line.split()
        if len(parts) >= 3:
            result.append((parts[1], parts[2]))
    return result


def write_occurrences(path: Path, counter: Counter):
    with path.open("w") as stream:
        for (kind, name), count in sorted(counter.items(), key=lambda item: item[0][1]):
            stream.write(f"{count}\t{kind}\t{name}\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("stock_kallsyms", type=Path)
    parser.add_argument("system_map", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--vmlinux", type=Path)
    parser.add_argument("--nm", type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    stock, modules, nonzero = read_stock(args.stock_kallsyms)
    rebuild = read_map(args.system_map)
    stock_counter, rebuild_counter = Counter(stock), Counter(rebuild)
    missing = stock_counter - rebuild_counter
    extra = rebuild_counter - stock_counter
    write_occurrences(args.output_dir / "missing-in-rebuild.txt", missing)
    write_occurrences(args.output_dir / "extra-in-rebuild.txt", extra)

    stock_names = Counter(name for _, name in stock)
    rebuild_names = Counter(name for _, name in rebuild)
    unique_common = {name for name, count in stock_names.items() if count == 1 and rebuild_names[name] == 1}
    positions = {name: i for i, (_, name) in enumerate(rebuild) if name in unique_common}
    sequence = [positions[name] for _, name in stock if name in unique_common]
    tails = []
    for value in sequence:
        offset = bisect_left(tails, value)
        if offset == len(tails):
            tails.append(value)
        else:
            tails[offset] = value

    stock_types = {name: kind for kind, name in stock if stock_names[name] == 1}
    rebuild_types = {name: kind for kind, name in rebuild if rebuild_names[name] == 1}
    type_mismatches = sorted(
        (name, stock_types[name], rebuild_types[name])
        for name in stock_types.keys() & rebuild_types.keys()
        if stock_types[name] != rebuild_types[name]
    )

    nm_same_pair = nm_any_type = nm_absent = None
    if args.vmlinux and args.nm:
        output = subprocess.check_output([str(args.nm), "-n", str(args.vmlinux)], text=True, errors="replace")
        nm_pairs = set()
        nm_names = set()
        for line in output.splitlines():
            parts = line.split()
            if len(parts) >= 3:
                nm_pairs.add((parts[1], parts[2]))
                nm_names.add(parts[2])
        nm_same_pair = sum(count for pair, count in missing.items() if pair in nm_pairs)
        nm_any_type = sum(count for (_, name), count in missing.items() if name in nm_names)
        nm_absent = sum(count for (_, name), count in missing.items() if name not in nm_names)

    with (args.output_dir / "order-or-address-mismatches.txt").open("w") as stream:
        if nonzero == 0:
            stream.write("All stock addresses are zero; address/offset comparison is unavailable.\n")
        stream.write(f"unique_common_symbols={len(sequence)}\n")
        stream.write(f"longest_in_order_subsequence={len(tails)}\n")
        stream.write(f"minimum_symbols_out_of_order={len(sequence) - len(tails)}\n")
        stream.write(f"unique_name_type_mismatches={len(type_mismatches)}\n")
        for name, stock_type, rebuild_type in type_mismatches:
            stream.write(f"type\t{stock_type}->{rebuild_type}\t{name}\n")

    categories = Counter()
    for (_, name), count in missing.items():
        if name.startswith("bpf_prog_"):
            categories["runtime_bpf_jit"] += count
        elif "oppo" in name.lower():
            categories["oppo_named"] += count
        elif name.startswith("VL53L1") or name.startswith(("LL_", "ML_")):
            categories["vl53l1_mksysmap_filter"] += count
        else:
            categories["other"] += count

    with (args.output_dir / "symbol-comparison-summary.txt").open("w") as stream:
        stream.write(f"stock_total_lines={len(stock) + sum(modules.values())}\n")
        stream.write(f"stock_kernel_lines={len(stock)}\n")
        stream.write(f"stock_module_lines={sum(modules.values())}\n")
        stream.write(f"stock_nonzero_addresses={nonzero}\n")
        stream.write(f"rebuilt_system_map_lines={len(rebuild)}\n")
        stream.write(f"missing_occurrences={sum(missing.values())}\n")
        stream.write(f"missing_unique_type_name_pairs={len(missing)}\n")
        stream.write(f"extra_occurrences={sum(extra.values())}\n")
        stream.write(f"extra_unique_type_name_pairs={len(extra)}\n")
        stream.write(f"unique_common_symbols={len(sequence)}\n")
        stream.write(f"minimum_symbols_out_of_order={len(sequence) - len(tails)}\n")
        stream.write(f"unique_name_type_mismatches={len(type_mismatches)}\n")
        if nm_same_pair is not None:
            stream.write(f"missing_occurrences_present_same_pair_in_vmlinux_nm={nm_same_pair}\n")
            stream.write(f"missing_occurrences_name_present_in_vmlinux_nm={nm_any_type}\n")
            stream.write(f"missing_occurrences_absent_from_vmlinux_nm={nm_absent}\n")
        for category, count in sorted(categories.items()):
            stream.write(f"missing_category_{category}={count}\n")
        stream.write("stock_module_symbol_counts:\n")
        for module, count in modules.most_common():
            stream.write(f"  {module}={count}\n")


if __name__ == "__main__":
    main()
