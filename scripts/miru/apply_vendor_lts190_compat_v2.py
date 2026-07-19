#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import pathlib
import re

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

    pattern = re.compile(
        r"^#define DUMMY_ENCRYPTION_ENABLED\(sbi\)[^\n]*"
        r"(?:\\\n[^\n]*)?",
        re.M,
    )
    candidates = [
        match for match in pattern.finditer(text)
        if "test_dummy_encryption" in match.group(0)
    ]
    if len(candidates) != 1:
        raise SystemExit(
            "expected one enabled of2fs dummy-encryption macro, "
            f"found {len(candidates)}"
        )
    match = candidates[0]
    replacement = (
        "#define DUMMY_ENCRYPTION_ENABLED(sbi) \\\n"
        "\t(F2FS_OPTION(sbi).dummy_enc_ctx.ctx != NULL)"
    )
    text = text[:match.start()] + replacement + text[match.end():]

    definitions = pattern.findall(text)
    if len(definitions) != 2:
        raise SystemExit(
            f"expected enabled and disabled dummy-encryption macros, found {len(definitions)}"
        )
    if "#define DUMMY_ENCRYPTION_ENABLED(sbi) (0)" not in text:
        raise SystemExit("CONFIG_FS_ENCRYPTION=n fallback was not preserved")
    path.write_text(text)


base.patch_of2fs_header = patch_of2fs_header_scoped
base.main()
