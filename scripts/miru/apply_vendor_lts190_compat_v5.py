#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import pathlib

BASE_PATCHER = pathlib.Path(__file__).with_name("apply_vendor_lts190_compat.py")
spec = importlib.util.spec_from_file_location("miru_vendor_lts190_base", BASE_PATCHER)
if spec is None or spec.loader is None:
    raise SystemExit("unable to load base vendor compatibility patcher")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def patch_of2fs_header_scoped(path: pathlib.Path) -> None:
    text = path.read_text()
    text = base.replace_exact(
        text,
        "\tbool test_dummy_encryption;\t/* test dummy encryption */",
        "\tstruct fscrypt_dummy_context dummy_enc_ctx; /* test dummy encryption */",
    )
    text = base.replace_exact(
        text,
        "#define CP_PAUSE\t0x00000040\n",
        "#define CP_PAUSE\t0x00000040\n#define CP_RESIZE\t0x00000080\n",
    )
    text = base.replace_exact(
        text,
        "\tFS_DATA_READ_IO,\t\t/* data read IOs */\n\tFS_NODE_READ_IO,",
        "\tFS_DATA_READ_IO,\t\t/* data read IOs */\n"
        "\tFS_GDATA_READ_IO,\t\t/* data read IOs from background gc */\n"
        "\tFS_CDATA_READ_IO,\t\t/* compressed data read IOs */\n"
        "\tFS_NODE_READ_IO,",
    )

    marker = "#ifdef CONFIG_FS_ENCRYPTION\n#define DUMMY_ENCRYPTION_ENABLED(sbi)"
    if text.count(marker) != 1:
        raise SystemExit(
            f"expected one CONFIG_FS_ENCRYPTION dummy macro, found {text.count(marker)}"
        )
    start = text.index(marker)
    end = text.index("#else", start)
    old_block = text[start:end]
    if len(old_block) > 512 or "#define DUMMY_ENCRYPTION_ENABLED(sbi)" not in old_block:
        raise SystemExit("unexpected enabled dummy-encryption preprocessor block")
    new_block = (
        "#ifdef CONFIG_FS_ENCRYPTION\n"
        "#define DUMMY_ENCRYPTION_ENABLED(sbi) \\\n"
        "\t(F2FS_OPTION(sbi).dummy_enc_ctx.ctx != NULL)\n"
    )
    text = text[:start] + new_block + text[end:]

    if text.count("#define DUMMY_ENCRYPTION_ENABLED(sbi)") != 2:
        raise SystemExit("enabled and disabled dummy-encryption definitions not preserved")
    if "#define DUMMY_ENCRYPTION_ENABLED(sbi) (0)" not in text:
        raise SystemExit("CONFIG_FS_ENCRYPTION=n fallback was not preserved")
    path.write_text(text)


def patch_of2fs_super_scoped(path: pathlib.Path) -> None:
    text = path.read_text()
    legacy = "F2FS_OPTION(sbi).test_dummy_encryption"
    positions = []
    cursor = 0
    while True:
        pos = text.find(legacy, cursor)
        if pos < 0:
            break
        positions.append(pos)
        cursor = pos + len(legacy)
    if len(positions) < 2:
        raise SystemExit(f"expected multiple legacy references, found {len(positions)}")

    parser_start = text.index("\t\tcase Opt_test_dummy_encryption:")
    parser_end = text.index("\t\t\tbreak;", parser_start) + len("\t\t\tbreak;")
    parser_positions = [pos for pos in positions if parser_start <= pos < parser_end]
    if len(parser_positions) != 1:
        raise SystemExit(
            f"expected one parser legacy reference, found {len(parser_positions)}"
        )

    # Replace every non-parser consumer (show-options and any copied mount-state
    # checks) with the new context pointer.  Keep the parser occurrence intact
    # so the base patcher's exact old-case guard still validates its source.
    pieces = []
    last = 0
    for pos in positions:
        pieces.append(text[last:pos])
        if parser_start <= pos < parser_end:
            pieces.append(legacy)
        else:
            pieces.append("F2FS_OPTION(sbi).dummy_enc_ctx.ctx")
        last = pos + len(legacy)
    pieces.append(text[last:])
    text = "".join(pieces)
    if text.count(legacy) != 1:
        raise SystemExit("non-parser legacy F2FS references were not fully migrated")
    path.write_text(text)
    base.patch_of2fs_super(path)


base.patch_of2fs_header = patch_of2fs_header_scoped
base.patch_of2fs_super = patch_of2fs_super_scoped
base.main()
