#!/usr/bin/env python3
"""Compare Android kernel module MODVERSIONS CRCs with a Module.symvers file.

The parser intentionally has no Python package dependencies.  It supports the
little-endian ELF64 modules used by the H.40 arm64 build and uses nm only to
collect CRCs exported by the supplied module set.
"""

import argparse
import collections
import hashlib
import struct
import subprocess
import sys
from pathlib import Path


class ModuleFormatError(RuntimeError):
    pass


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def elf_sections(path):
    data = path.read_bytes()
    if data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        raise ModuleFormatError(
            "{} is not a little-endian ELF64 file".format(path)
        )

    header_format = "<16sHHIQQQIHHHHHH"
    section_format = "<IIQQQQIIQQ"
    header = struct.unpack_from(header_format, data, 0)
    section_offset = header[6]
    section_entry_size = header[11]
    section_count = header[12]
    names_index = header[13]

    section_size = struct.calcsize(section_format)
    if section_entry_size < section_size:
        raise ModuleFormatError("{} has invalid section headers".format(path))

    headers = [
        struct.unpack_from(
            section_format, data, section_offset + index * section_entry_size
        )
        for index in range(section_count)
    ]
    if names_index >= len(headers):
        raise ModuleFormatError("{} has an invalid shstrndx".format(path))

    names_header = headers[names_index]
    names = data[
        names_header[4] : names_header[4] + names_header[5]
    ]
    sections = {}
    for entry in headers:
        name_offset = entry[0]
        name_end = names.find(b"\0", name_offset)
        if name_end < 0:
            raise ModuleFormatError("{} has an unterminated section name".format(path))
        name = names[name_offset:name_end].decode("ascii", "replace")
        # SHT_NOBITS occupies no bytes in the file.
        content = b"" if entry[1] == 8 else data[entry[4] : entry[4] + entry[5]]
        sections[name] = content
    return sections


def parse_module(path):
    sections = elf_sections(path)
    modinfo = collections.defaultdict(list)
    for item in sections.get(".modinfo", b"").split(b"\0"):
        if b"=" not in item:
            continue
        key, value = item.split(b"=", 1)
        modinfo[key.decode("ascii", "replace")].append(
            value.decode("utf-8", "replace")
        )

    versions_data = sections.get("__versions")
    if versions_data is None:
        raise ModuleFormatError("{} has no __versions section".format(path))
    if len(versions_data) % 64:
        raise ModuleFormatError(
            "{} has an invalid __versions size ({})".format(path, len(versions_data))
        )

    versions = {}
    for offset in range(0, len(versions_data), 64):
        crc = struct.unpack_from("<Q", versions_data, offset)[0]
        name = versions_data[offset + 8 : offset + 64]
        name = name.split(b"\0", 1)[0].decode("ascii", "replace")
        versions[name] = crc

    comments = sorted(
        {
            value.decode("utf-8", "replace")
            for value in sections.get(".comment", b"").split(b"\0")
            if value
        }
    )
    return {
        "filename": path.name,
        "name": modinfo.get("name", [path.stem])[0],
        "vermagic": modinfo.get("vermagic", [""])[0],
        "depends": modinfo.get("depends", [""])[0],
        "comments": comments,
        "versions": versions,
        "sha256": sha256(path),
    }


def parse_symvers(path):
    vmlinux = {}
    module_exports = {}
    for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        fields = line.split()
        if len(fields) < 3:
            continue
        try:
            crc = int(fields[0], 16)
        except ValueError as error:
            raise ModuleFormatError(
                "{}:{} has an invalid CRC".format(path, number)
            ) from error
        target = vmlinux if fields[2] == "vmlinux" else module_exports
        target[fields[1]] = crc
    return vmlinux, module_exports


def collect_vendor_exports(modules, nm):
    exports = collections.defaultdict(list)
    for module in modules:
        result = subprocess.run(
            [nm, "-P", module["path"]],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            errors="replace",
        )
        for line in result.stdout.splitlines():
            fields = line.split()
            if (
                len(fields) < 3
                or not fields[0].startswith("__crc_")
                or fields[1].upper() != "A"
            ):
                continue
            exports[fields[0][6:]].append(
                (int(fields[2], 16), module["filename"])
            )
    return exports


def format_crc(value):
    return "0x{:08x}".format(value)


def compare(module_dir, symvers, nm):
    paths = sorted(module_dir.glob("*.ko"))
    if not paths:
        raise ModuleFormatError("no .ko files found in {}".format(module_dir))

    modules = []
    for path in paths:
        module = parse_module(path)
        module["path"] = str(path)
        modules.append(module)

    vmlinux, reference_module_exports = parse_symvers(symvers)
    vendor_exports = collect_vendor_exports(modules, nm)
    core_matches = collections.defaultdict(list)
    core_mismatches = collections.defaultdict(list)
    vendor_matches = collections.defaultdict(list)
    vendor_mismatches = collections.defaultdict(list)
    reference_module_only = collections.defaultdict(list)
    unresolved = collections.defaultdict(list)

    for module in modules:
        for symbol, expected in module["versions"].items():
            filename = module["filename"]
            if symbol in vmlinux:
                if expected == vmlinux[symbol]:
                    core_matches[symbol].append((filename, expected))
                else:
                    core_mismatches[symbol].append(
                        (filename, expected, vmlinux[symbol])
                    )
            elif symbol in vendor_exports:
                available = {crc for crc, unused in vendor_exports[symbol]}
                if expected in available:
                    vendor_matches[symbol].append((filename, expected))
                else:
                    vendor_mismatches[symbol].append(
                        (filename, expected, sorted(available))
                    )
            elif symbol in reference_module_exports:
                reference_module_only[symbol].append((filename, expected))
            else:
                unresolved[symbol].append((filename, expected))

    return {
        "modules": modules,
        "vmlinux": vmlinux,
        "reference_module_exports": reference_module_exports,
        "vendor_exports": vendor_exports,
        "core_matches": core_matches,
        "core_mismatches": core_mismatches,
        "vendor_matches": vendor_matches,
        "vendor_mismatches": vendor_mismatches,
        "reference_module_only": reference_module_only,
        "unresolved": unresolved,
    }


def record_count(mapping):
    return sum(len(items) for items in mapping.values())


def render(result, module_dir, symvers):
    modules = result["modules"]
    all_imports = set()
    for module in modules:
        all_imports.update(module["versions"])

    output = []
    add = output.append
    add("H.40 vendor module MODVERSIONS comparison")
    add("=========================================\n")
    add("module_directory: {}".format(module_dir))
    add("module_count: {}".format(len(modules)))
    add("reference_symvers: {}".format(symvers))
    add("reference_symvers_sha256: {}".format(sha256(symvers)))
    add("import_records: {}".format(sum(len(m["versions"]) for m in modules)))
    add("unique_import_symbols: {}".format(len(all_imports)))
    add("")

    vermagic = collections.Counter(module["vermagic"] for module in modules)
    add("Vermagic")
    add("--------")
    for value, count in sorted(vermagic.items()):
        add("{} module(s): {}".format(count, value))
    add("")

    compilers = collections.Counter(
        comment for module in modules for comment in module["comments"]
    )
    add("Compiler comments")
    add("-----------------")
    for value, count in sorted(compilers.items()):
        add("{} occurrence(s): {}".format(count, value))
    add("")

    add("Comparison summary")
    add("------------------")
    for label, key in (
        ("core_match_records", "core_matches"),
        ("core_match_unique", "core_matches"),
        ("core_mismatch_records", "core_mismatches"),
        ("core_mismatch_unique", "core_mismatches"),
        ("vendor_match_records", "vendor_matches"),
        ("vendor_match_unique", "vendor_matches"),
        ("vendor_mismatch_records", "vendor_mismatches"),
        ("vendor_mismatch_unique", "vendor_mismatches"),
        ("reference_module_only_records", "reference_module_only"),
        ("reference_module_only_unique", "reference_module_only"),
        ("unresolved_records", "unresolved"),
        ("unresolved_unique", "unresolved"),
    ):
        value = record_count(result[key]) if label.endswith("records") else len(result[key])
        add("{}: {}".format(label, value))
    add("")

    add("Core CRC mismatches")
    add("-------------------")
    for symbol, items in sorted(
        result["core_mismatches"].items(), key=lambda item: (-len(item[1]), item[0])
    ):
        expected = sorted({item[1] for item in items})
        actual = sorted({item[2] for item in items})
        filenames = ",".join(item[0] for item in items)
        add(
            "{}\texpected={}\treference={}\tmodules={}\t{}".format(
                symbol,
                ",".join(format_crc(value) for value in expected),
                ",".join(format_crc(value) for value in actual),
                len(items),
                filenames,
            )
        )
    add("")

    add("Vendor-set CRC mismatches")
    add("-------------------------")
    if not result["vendor_mismatches"]:
        add("none")
    else:
        for symbol, items in sorted(result["vendor_mismatches"].items()):
            add("{}\t{}".format(symbol, items))
    add("")

    add("Unresolved imports")
    add("------------------")
    if not result["unresolved"]:
        add("none")
    else:
        for symbol, items in sorted(result["unresolved"].items()):
            add("{}\t{}".format(symbol, items))
    add("")

    add("Per-module summary")
    add("------------------")
    for module in modules:
        versions = module["versions"]
        filename = module["filename"]
        core_match = sum(
            1
            for symbol, expected in versions.items()
            if result["vmlinux"].get(symbol) == expected
        )
        core_mismatch = sum(
            1
            for symbol, expected in versions.items()
            if symbol in result["vmlinux"]
            and result["vmlinux"][symbol] != expected
        )
        add(
            "{}\tname={}\timports={}\tcore_match={}\tcore_mismatch={}\tsha256={}".format(
                filename,
                module["name"],
                len(versions),
                core_match,
                core_mismatch,
                module["sha256"],
            )
        )
    return "\n".join(output) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("module_dir", type=Path)
    parser.add_argument("symvers", type=Path)
    parser.add_argument("--nm", default="nm", help="nm executable (default: nm)")
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--strict",
        action="store_true",
        help="return nonzero when a core, vendor, or unresolved mismatch exists",
    )
    args = parser.parse_args()

    try:
        result = compare(args.module_dir, args.symvers, args.nm)
        report = render(result, args.module_dir, args.symvers)
    except (ModuleFormatError, OSError, subprocess.CalledProcessError) as error:
        print("error: {}".format(error), file=sys.stderr)
        return 2

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report)
    else:
        sys.stdout.write(report)

    if args.strict and (
        result["core_mismatches"]
        or result["vendor_mismatches"]
        or result["unresolved"]
    ):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
