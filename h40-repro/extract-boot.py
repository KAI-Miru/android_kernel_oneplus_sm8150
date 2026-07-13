#!/usr/bin/env python3
"""Extract Android boot image v0-v2 components without modifying the input."""

from __future__ import annotations

import argparse
import bz2
import gzip
import hashlib
import json
import lzma
import shutil
import struct
import subprocess
from pathlib import Path


BOOT_MAGIC = b"ANDROID!"
FDT_MAGIC = b"\xd0\x0d\xfe\xed"
DT_TABLE_MAGIC = 0xD7B7AB1E


def align(value: int, page_size: int) -> int:
    return (value + page_size - 1) // page_size * page_size


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def valid_fdt_size(data: bytes, offset: int) -> int | None:
    if offset + 40 > len(data) or data[offset : offset + 4] != FDT_MAGIC:
        return None
    fields = struct.unpack_from(">10I", data, offset)
    total, off_struct, off_strings, off_mem, version, last = fields[1:7]
    if not 40 <= total <= len(data) - offset:
        return None
    if not (16 <= version <= 17 and last <= version):
        return None
    if any(value >= total for value in (off_struct, off_strings, off_mem)):
        return None
    return total


def fdt_chain_from(data: bytes, start: int) -> list[tuple[int, int]] | None:
    result: list[tuple[int, int]] = []
    pos = start
    while pos < len(data):
        while pos < len(data) and data[pos] == 0:
            pos += 1
        if pos == len(data):
            return result
        size = valid_fdt_size(data, pos)
        if size is None:
            return None
        result.append((pos, size))
        pos += size
    return result


def find_appended_fdt_chain(data: bytes) -> list[tuple[int, int]]:
    cursor = 0
    while True:
        cursor = data.find(FDT_MAGIC, cursor)
        if cursor < 0:
            return []
        chain = fdt_chain_from(data, cursor)
        if chain:
            return chain
        cursor += 1


def write_fdt_chain(data: bytes, output: Path, prefix: str) -> list[dict]:
    output.mkdir(parents=True, exist_ok=True)
    result = []
    chain = fdt_chain_from(data, 0) or []
    for number, (offset, size) in enumerate(chain, 1):
        path = output / f"{prefix}-{number:03d}.dtb"
        blob = data[offset : offset + size]
        path.write_bytes(blob)
        result.append(
            {"file": str(path), "offset": offset, "size": size, "sha256": sha256(blob)}
        )
    return result


def write_dt_table(data: bytes, output: Path) -> list[dict]:
    if len(data) < 32:
        return []
    header = struct.unpack_from(">8I", data, 0)
    magic, total, header_size, entry_size, count, entries_offset, _, _ = header
    if magic != DT_TABLE_MAGIC or total > len(data) or header_size < 32 or entry_size < 32:
        return []
    output.mkdir(parents=True, exist_ok=True)
    result = []
    for number in range(count):
        entry_at = entries_offset + number * entry_size
        size, offset, ident, revision, *custom = struct.unpack_from(">8I", data, entry_at)
        if offset + size > total:
            raise ValueError(f"DT table entry {number} extends beyond total_size")
        blob = data[offset : offset + size]
        path = output / f"dtbo-{number:03d}.dtb"
        path.write_bytes(blob)
        result.append(
            {
                "file": str(path),
                "offset": offset,
                "size": size,
                "id": ident,
                "revision": revision,
                "custom": custom,
                "sha256": sha256(blob),
            }
        )
    return result


def decompress_kernel(data: bytes, output: Path) -> str:
    if data.startswith(b"\x1f\x8b"):
        output.write_bytes(gzip.decompress(data))
        return "gzip"
    if data.startswith(b"\xfd7zXZ\x00"):
        output.write_bytes(lzma.decompress(data, format=lzma.FORMAT_XZ))
        return "xz"
    if data.startswith(b"BZh"):
        output.write_bytes(bz2.decompress(data))
        return "bzip2"
    if data.startswith(b"\x28\xb5\x2f\xfd"):
        command = shutil.which("zstd")
        if command is None:
            raise RuntimeError("zstd-compressed kernel requires the zstd executable")
        with output.open("wb") as stream:
            subprocess.run([command, "-dc"], input=data, stdout=stream, check=True)
        return "zstd"
    if data.startswith((b"\x04\x22\x4d\x18", b"\x02\x21\x4c\x18")):
        command = shutil.which("lz4")
        if command is None:
            raise RuntimeError("LZ4-compressed kernel requires the lz4 executable")
        with output.open("wb") as stream:
            subprocess.run([command, "-dc"], input=data, stdout=stream, check=True)
        return "lz4"
    output.write_bytes(data)
    return "raw"


def extract_component(image: bytes, offset: int, size: int, path: Path) -> bytes:
    if size < 0 or offset < 0 or offset + size > len(image):
        raise ValueError(f"component {path.name} exceeds boot image bounds")
    data = image[offset : offset + size]
    path.write_bytes(data)
    return data


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("boot_image", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    image = args.boot_image.read_bytes()
    if image[:8] != BOOT_MAGIC:
        raise SystemExit("not an Android boot image (ANDROID! magic missing)")
    args.output_dir.mkdir(parents=True, exist_ok=True)

    values = struct.unpack_from("<10I", image, 8)
    keys = (
        "kernel_size", "kernel_addr", "ramdisk_size", "ramdisk_addr",
        "second_size", "second_addr", "tags_addr", "page_size",
        "header_version", "os_version",
    )
    header = dict(zip(keys, values))
    page = header["page_size"]
    if page == 0 or page & (page - 1):
        raise SystemExit(f"invalid page size: {page}")

    header["name"] = image[48:64].split(b"\0", 1)[0].decode(errors="replace")
    header["cmdline"] = image[64:576].split(b"\0", 1)[0].decode(errors="replace")
    header["extra_cmdline"] = image[608:1632].split(b"\0", 1)[0].decode(errors="replace")

    kernel_offset = page
    ramdisk_offset = kernel_offset + align(header["kernel_size"], page)
    second_offset = ramdisk_offset + align(header["ramdisk_size"], page)
    recovery_size = recovery_offset = header_size = 0
    if header["header_version"] >= 1:
        recovery_size, recovery_offset, header_size = struct.unpack_from("<IQI", image, 1632)
    dtb_size = dtb_addr = dtb_offset = 0
    if header["header_version"] >= 2:
        dtb_size, dtb_addr = struct.unpack_from("<IQ", image, 1648)
        base = recovery_offset if recovery_size else second_offset + align(header["second_size"], page)
        dtb_offset = base + align(recovery_size, page)

    components: dict[str, dict] = {}
    kernel = extract_component(image, kernel_offset, header["kernel_size"], args.output_dir / "kernel-payload")
    components["kernel"] = {"offset": kernel_offset, "size": len(kernel), "sha256": sha256(kernel)}
    ramdisk = extract_component(image, ramdisk_offset, header["ramdisk_size"], args.output_dir / "ramdisk")
    components["ramdisk"] = {"offset": ramdisk_offset, "size": len(ramdisk), "sha256": sha256(ramdisk)}
    if header["second_size"]:
        second = extract_component(image, second_offset, header["second_size"], args.output_dir / "second")
        components["second"] = {"offset": second_offset, "size": len(second), "sha256": sha256(second)}

    recovery_entries = []
    if recovery_size:
        recovery = extract_component(image, recovery_offset, recovery_size, args.output_dir / "recovery-dtbo.img")
        components["recovery_dtbo"] = {"offset": recovery_offset, "size": len(recovery), "sha256": sha256(recovery)}
        recovery_entries = write_dt_table(recovery, args.output_dir / "recovery-dtbo-entries")

    boot_dtbs = []
    if dtb_size:
        dtb = extract_component(image, dtb_offset, dtb_size, args.output_dir / "dtb")
        components["dtb"] = {"offset": dtb_offset, "size": len(dtb), "address": dtb_addr, "sha256": sha256(dtb)}
        boot_dtbs = write_fdt_chain(dtb, args.output_dir / "boot-dtbs", "dtb")

    appended = find_appended_fdt_chain(kernel)
    core = kernel[: appended[0][0]] if appended else kernel
    if appended:
        appended_dir = args.output_dir / "kernel-appended-dtbs"
        appended_dir.mkdir(parents=True, exist_ok=True)
        for number, (offset, size) in enumerate(appended, 1):
            (appended_dir / f"dtb-{number:03d}.dtb").write_bytes(kernel[offset : offset + size])
    core_path = args.output_dir / "kernel-payload.no-dtb"
    core_path.write_bytes(core)
    raw_image_path = args.output_dir / "Image"
    compression = decompress_kernel(core, raw_image_path)

    report = {
        "input": str(args.boot_image.resolve()),
        "input_size": len(image),
        "input_sha256": sha256(image),
        "header": header,
        "header_size": header_size,
        "components": components,
        "kernel_compression": compression,
        "raw_image_size": raw_image_path.stat().st_size,
        "raw_image_sha256": sha256(raw_image_path.read_bytes()),
        "kernel_appended_dtb_count": len(appended),
        "boot_dtb_count": len(boot_dtbs),
        "boot_dtbs": boot_dtbs,
        "recovery_dtbo_count": len(recovery_entries),
        "recovery_dtbo_entries": recovery_entries,
    }
    (args.output_dir / "extraction-report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    lines = [
        f"input={report['input']}", f"input_sha256={report['input_sha256']}",
        f"header_version={header['header_version']}", f"page_size={page}",
        f"kernel_compression={compression}", f"kernel_payload_size={len(kernel)}",
        f"kernel_payload_sha256={sha256(kernel)}", f"raw_image_size={report['raw_image_size']}",
        f"raw_image_sha256={report['raw_image_sha256']}",
        f"kernel_appended_dtb_count={len(appended)}", f"boot_dtb_count={len(boot_dtbs)}",
        f"recovery_dtbo_count={len(recovery_entries)}",
    ]
    text = "\n".join(lines) + "\n"
    (args.output_dir / "extraction-report.txt").write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
