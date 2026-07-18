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
    count = text.count(legacy)
    if count != 2:
        raise SystemExit(
            f"expected parser and display legacy references, found {count}"
        )
    display_pos = text.rfind(legacy)
    text = (
        text[:display_pos]
        + "F2FS_OPTION(sbi).dummy_enc_ctx.ctx"
        + text[display_pos + len(legacy):]
    )
    path.write_text(text)
    base.patch_of2fs_super(path)


base.patch_of2fs_header = patch_of2fs_header_scoped
base.patch_of2fs_super = patch_of2fs_super_scoped
base.main()
