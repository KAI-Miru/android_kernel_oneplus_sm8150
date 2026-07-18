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
    if len(old_block) > 512:
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


def patch_of2fs_super_explicit(path: pathlib.Path) -> None:
    text = path.read_text()
    if text.count("F2FS_OPTION(sbi).test_dummy_encryption") != 1:
        raise SystemExit("expected exactly one direct of2fs dummy boolean assignment")

    text = base.replace_exact(
        text,
        '\t{Opt_test_dummy_encryption, "test_dummy_encryption"},\n',
        '\t{Opt_test_dummy_encryption, "test_dummy_encryption=%s"},\n'
        '\t{Opt_test_dummy_encryption, "test_dummy_encryption"},\n',
    )

    marker = "#endif\n\nstatic int parse_options(struct super_block *sb, char *options)\n"
    helper = """#endif

static int f2fs_set_test_dummy_encryption(struct super_block *sb,
\t\t\t\t\t  const char *opt,
\t\t\t\t\t  const substring_t *arg)
{
\tstruct f2fs_sb_info *sbi = F2FS_SB(sb);
#ifdef CONFIG_FS_ENCRYPTION
\tint err;

\tif (!f2fs_sb_has_encrypt(sbi)) {
\t\tf2fs_err(sbi, "Encrypt feature is off");
\t\treturn -EINVAL;
\t}

\terr = fscrypt_set_test_dummy_encryption(
\t\tsb, arg, &F2FS_OPTION(sbi).dummy_enc_ctx);
\tif (err) {
\t\tif (err == -EEXIST)
\t\t\tf2fs_warn(sbi, "Can't change test_dummy_encryption on remount");
\t\telse if (err == -EINVAL)
\t\t\tf2fs_warn(sbi, "Value of option \"%s\" is unrecognized", opt);
\t\telse
\t\t\tf2fs_warn(sbi, "Error processing option \"%s\" [%d]",
\t\t\t\t  opt, err);
\t\treturn -EINVAL;
\t}
\tf2fs_info(sbi, "Test dummy encryption mode enabled");
#else
\tf2fs_info(sbi, "Test dummy encryption mount option ignored");
#endif
\treturn 0;
}

static int parse_options(struct super_block *sb, char *options)
"""
    text = base.replace_exact(text, marker, helper)

    old_case = """\t\tcase Opt_test_dummy_encryption:
#ifdef CONFIG_FS_ENCRYPTION
\t\t\tif (!f2fs_sb_has_encrypt(sbi)) {
\t\t\t\tf2fs_err(sbi, "Encrypt feature is off");
\t\t\t\treturn -EINVAL;
\t\t\t}

\t\t\tF2FS_OPTION(sbi).test_dummy_encryption = true;
\t\t\tf2fs_info(sbi, "Test dummy encryption mode enabled");
#else
\t\t\tf2fs_info(sbi, "Test dummy encryption mount option ignored");
#endif
\t\t\tbreak;
"""
    new_case = """\t\tcase Opt_test_dummy_encryption:
\t\t\tif (f2fs_set_test_dummy_encryption(sb, p, &args[0]))
\t\t\t\treturn -EINVAL;
\t\t\tbreak;
"""
    text = base.replace_exact(text, old_case, new_case)

    old_getter = """static bool f2fs_dummy_context(struct inode *inode)
{
\treturn DUMMY_ENCRYPTION_ENABLED(F2FS_I_SB(inode));
}
"""
    new_getter = """static const union fscrypt_context *
f2fs_get_dummy_context(struct super_block *sb)
{
\treturn F2FS_OPTION(F2FS_SB(sb)).dummy_enc_ctx.ctx;
}
"""
    text = base.replace_exact(text, old_getter, new_getter)
    text = base.replace_exact(
        text,
        "\t.dummy_context\t\t= f2fs_dummy_context,",
        "\t.get_dummy_context\t= f2fs_get_dummy_context,",
    )
    text = base.replace_exact(
        text,
        "#endif\n\tdestroy_percpu_info(sbi);\n",
        "#endif\n\tfscrypt_free_dummy_context(&F2FS_OPTION(sbi).dummy_enc_ctx);\n"
        "\tdestroy_percpu_info(sbi);\n",
    )

    if "F2FS_OPTION(sbi).test_dummy_encryption" in text:
        raise SystemExit("direct of2fs dummy boolean assignment remains")
    for token in (
        "fscrypt_set_test_dummy_encryption",
        "f2fs_get_dummy_context",
        ".get_dummy_context",
        "fscrypt_free_dummy_context",
    ):
        if token not in text:
            raise SystemExit(f"explicit of2fs migration lacks {token}")
    path.write_text(text)


base.patch_of2fs_header = patch_of2fs_header_scoped
base.patch_of2fs_super = patch_of2fs_super_explicit
base.main()
