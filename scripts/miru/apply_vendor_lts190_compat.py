#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import pathlib
import re
import subprocess

EXPECTED_GIT_BLOBS = {
    "oplus/kernel/of2fs/f2fs.h": "99becfe7e6b8f229bf8e06718416e49b521ebc41",
    "oplus/kernel/of2fs/super.c": "794f542a718f874ab732d09bd350acac123bc80e",
    "oplus/kernel_4.14/ext4/ext4.h": "229363f46bd0022d96368891bf3a117eb61c8900",
    "oplus/kernel_4.14/ext4/super.c": "95c37611847681e6ba128dbf589748917b81ebb8",
}


def git_blob(path: pathlib.Path) -> str:
    return subprocess.check_output(["git", "hash-object", str(path)], text=True).strip()


def replace_exact(text: str, old: str, new: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(
            f"guarded replacement expected {expected}, found {count}: {old!r}"
        )
    return text.replace(old, new, expected)


def replace_regex(text: str, pattern: str, replacement: str, expected: int = 1) -> str:
    text, count = re.subn(pattern, replacement, text, flags=re.M)
    if count != expected:
        raise SystemExit(
            f"guarded regex replacement expected {expected}, found {count}: {pattern!r}"
        )
    return text


def patch_of2fs_header(path: pathlib.Path) -> None:
    text = path.read_text()
    text = replace_exact(
        text,
        "\tbool test_dummy_encryption;\t/* test dummy encryption */",
        "\tstruct fscrypt_dummy_context dummy_enc_ctx; /* test dummy encryption */",
    )
    text = replace_exact(
        text,
        "#define CP_PAUSE\t0x00000040\n",
        "#define CP_PAUSE\t0x00000040\n#define CP_RESIZE\t0x00000080\n",
    )
    text = replace_exact(
        text,
        "\tFS_DATA_READ_IO,\t\t/* data read IOs */\n\tFS_NODE_READ_IO,",
        "\tFS_DATA_READ_IO,\t\t/* data read IOs */\n"
        "\tFS_GDATA_READ_IO,\t\t/* data read IOs from background gc */\n"
        "\tFS_CDATA_READ_IO,\t\t/* compressed data read IOs */\n"
        "\tFS_NODE_READ_IO,",
    )
    text = replace_regex(
        text,
        r"^#define DUMMY_ENCRYPTION_ENABLED\(sbi\).*?$",
        "#define DUMMY_ENCRYPTION_ENABLED(sbi) \\\n\t(F2FS_OPTION(sbi).dummy_enc_ctx.ctx != NULL)",
    )
    path.write_text(text)


def patch_of2fs_super(path: pathlib.Path) -> None:
    text = path.read_text()
    text = replace_exact(
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
    text = replace_exact(text, marker, helper)

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
    text = replace_exact(text, old_case, new_case)

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
    text = replace_exact(text, old_getter, new_getter)
    text = replace_exact(
        text,
        "\t.dummy_context\t\t= f2fs_dummy_context,",
        "\t.get_dummy_context\t= f2fs_get_dummy_context,",
    )

    text = replace_exact(
        text,
        "#endif\n\tdestroy_percpu_info(sbi);\n",
        "#endif\n\tfscrypt_free_dummy_context(&F2FS_OPTION(sbi).dummy_enc_ctx);\n"
        "\tdestroy_percpu_info(sbi);\n",
    )

    old_show = """\tif (F2FS_OPTION(sbi).test_dummy_encryption)
\t\tseq_puts(seq, ",test_dummy_encryption");
"""
    if old_show in text:
        text = replace_exact(
            text,
            old_show,
            "\tfscrypt_show_test_dummy_encryption(seq, ',', sbi->sb);\n",
        )

    legacy = (
        ".dummy_context",
        "f2fs_dummy_context",
        "F2FS_OPTION(sbi).test_dummy_encryption",
    )
    for token in legacy:
        if token in text:
            raise SystemExit(f"legacy of2fs fscrypt token remains: {token}")
    path.write_text(text)


def patch_oext4_header(path: pathlib.Path) -> None:
    text = path.read_text()
    text = replace_exact(
        text,
        "#define DUMMY_ENCRYPTION_ENABLED(sbi) (unlikely((sbi)->s_mount_flags & \\\n\t\t\t\t\t\tEXT4_MF_TEST_DUMMY_ENCRYPTION))",
        "#define DUMMY_ENCRYPTION_ENABLED(sbi) ((sbi)->s_dummy_enc_ctx.ctx != NULL)",
    )
    text = replace_exact(
        text,
        "\tstruct ratelimit_state s_msg_ratelimit_state;\n\n\t/*\n"
        "\t * Barrier between writepages ops and changing any inode's JOURNAL_DATA\n",
        "\tstruct ratelimit_state s_msg_ratelimit_state;\n\n"
        "\t/* Encryption context for '-o test_dummy_encryption' */\n"
        "\tstruct fscrypt_dummy_context s_dummy_enc_ctx;\n\n"
        "\t/*\n"
        "\t * Barrier between writepages ops and changing any inode's JOURNAL_DATA\n",
    )
    path.write_text(text)


def patch_oext4_super(path: pathlib.Path) -> None:
    text = path.read_text()
    text = replace_exact(
        text,
        '\t{Opt_test_dummy_encryption, "test_dummy_encryption"},\n',
        '\t{Opt_test_dummy_encryption, "test_dummy_encryption=%s"},\n'
        '\t{Opt_test_dummy_encryption, "test_dummy_encryption"},\n',
    )

    old_getter = """static bool ext4_dummy_context(struct inode *inode)
{
\treturn DUMMY_ENCRYPTION_ENABLED(EXT4_SB(inode->i_sb));
}
"""
    new_getter = """static const union fscrypt_context *
ext4_get_dummy_context(struct super_block *sb)
{
\treturn EXT4_SB(sb)->s_dummy_enc_ctx.ctx;
}
"""
    text = replace_exact(text, old_getter, new_getter)
    text = replace_exact(
        text,
        "\t.dummy_context\t\t= ext4_dummy_context,",
        "\t.get_dummy_context\t= ext4_get_dummy_context,",
    )

    helper_marker = "static int handle_mount_opt(struct super_block *sb, char *opt, int token,\n"
    helper = """static int ext4_set_test_dummy_encryption(struct super_block *sb,
\t\t\t\t\t  const char *opt,
\t\t\t\t\t  const substring_t *arg,
\t\t\t\t\t  bool is_remount)
{
#ifdef CONFIG_FS_ENCRYPTION
\tstruct ext4_sb_info *sbi = EXT4_SB(sb);
\tint err;

\tif (is_remount && !sbi->s_dummy_enc_ctx.ctx) {
\t\text4_msg(sb, KERN_WARNING,
\t\t\t "Can't set test_dummy_encryption on remount");
\t\treturn -1;
\t}
\terr = fscrypt_set_test_dummy_encryption(sb, arg, &sbi->s_dummy_enc_ctx);
\tif (err) {
\t\tif (err == -EEXIST)
\t\t\text4_msg(sb, KERN_WARNING,
\t\t\t\t "Can't change test_dummy_encryption on remount");
\t\telse if (err == -EINVAL)
\t\t\text4_msg(sb, KERN_WARNING,
\t\t\t\t "Value of option \"%s\" is unrecognized", opt);
\t\telse
\t\t\text4_msg(sb, KERN_WARNING,
\t\t\t\t "Error processing option \"%s\" [%d]", opt, err);
\t\treturn -1;
\t}
\text4_msg(sb, KERN_WARNING, "Test dummy encryption mode enabled");
#else
\text4_msg(sb, KERN_WARNING,
\t\t "Test dummy encryption mount option ignored");
#endif
\treturn 1;
}

static int handle_mount_opt(struct super_block *sb, char *opt, int token,
"""
    text = replace_exact(text, helper_marker, helper)

    old_case = """\t} else if (token == Opt_test_dummy_encryption) {
#ifdef CONFIG_FS_ENCRYPTION
\t\tsbi->s_mount_flags |= EXT4_MF_TEST_DUMMY_ENCRYPTION;
\t\text4_msg(sb, KERN_WARNING,
\t\t\t "Test dummy encryption mode enabled");
#else
\t\text4_msg(sb, KERN_WARNING,
\t\t\t "Test dummy encryption mount option ignored");
#endif
"""
    new_case = """\t} else if (token == Opt_test_dummy_encryption) {
\t\treturn ext4_set_test_dummy_encryption(sb, opt, &args[0],
\t\t\t\t\t\t      is_remount);
"""
    text = replace_exact(text, old_case, new_case)

    text = replace_exact(
        text,
        "\tkfree(sbi->s_blockgroup_lock);\n\tfs_put_dax(sbi->s_daxdev);\n",
        "\tkfree(sbi->s_blockgroup_lock);\n\tfs_put_dax(sbi->s_daxdev);\n"
        "\tfscrypt_free_dummy_context(&sbi->s_dummy_enc_ctx);\n",
    )

    old_show = """\tif (unlikely(sbi->s_mount_flags & EXT4_MF_TEST_DUMMY_ENCRYPTION))
\t\tSEQ_OPTS_PUTS("test_dummy_encryption");
"""
    if old_show in text:
        text = replace_exact(
            text,
            old_show,
            "\tfscrypt_show_test_dummy_encryption(seq, ',', sb);\n",
        )

    legacy = (
        ".dummy_context",
        "ext4_dummy_context",
        "s_mount_flags |= EXT4_MF_TEST_DUMMY_ENCRYPTION",
    )
    for token in legacy:
        if token in text:
            raise SystemExit(f"legacy oext4 fscrypt token remains: {token}")
    path.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("vendor_root", type=pathlib.Path)
    parser.add_argument("--report", type=pathlib.Path)
    args = parser.parse_args()

    root = args.vendor_root.resolve()
    paths = {rel: root / rel for rel in EXPECTED_GIT_BLOBS}
    for rel, path in paths.items():
        if not path.is_file():
            raise SystemExit(f"missing vendor file: {path}")
        actual = git_blob(path)
        expected = EXPECTED_GIT_BLOBS[rel]
        if actual != expected:
            raise SystemExit(f"{rel}: expected original blob {expected}, found {actual}")

    patch_of2fs_header(paths["oplus/kernel/of2fs/f2fs.h"])
    patch_of2fs_super(paths["oplus/kernel/of2fs/super.c"])
    patch_oext4_header(paths["oplus/kernel_4.14/ext4/ext4.h"])
    patch_oext4_super(paths["oplus/kernel_4.14/ext4/super.c"])

    report_lines = [
        "Miru H.40 Android 4.14.190 vendor filesystem compatibility patch",
        "",
        "Original source commit: 993439581252cf872cd3c184ed3eb9e0f286f4c3",
        "",
    ]
    for rel, path in paths.items():
        data = path.read_bytes()
        report_lines.append(
            f"{rel}: git_blob={git_blob(path)} sha256={hashlib.sha256(data).hexdigest()}"
        )

    # Final semantic guards shared by the compiler-visible vendor forks.
    f2fs_h = paths["oplus/kernel/of2fs/f2fs.h"].read_text()
    f2fs_c = paths["oplus/kernel/of2fs/super.c"].read_text()
    ext4_h = paths["oplus/kernel_4.14/ext4/ext4.h"].read_text()
    ext4_c = paths["oplus/kernel_4.14/ext4/super.c"].read_text()
    required = {
        "of2fs/f2fs.h": (
            "struct fscrypt_dummy_context dummy_enc_ctx;",
            "#define CP_RESIZE",
            "FS_GDATA_READ_IO",
            "FS_CDATA_READ_IO",
        ),
        "of2fs/super.c": (
            "fscrypt_set_test_dummy_encryption",
            "f2fs_get_dummy_context",
            ".get_dummy_context",
            "fscrypt_free_dummy_context",
        ),
        "oext4/ext4.h": (
            "struct fscrypt_dummy_context s_dummy_enc_ctx;",
            "s_dummy_enc_ctx.ctx != NULL",
        ),
        "oext4/super.c": (
            "fscrypt_set_test_dummy_encryption",
            "ext4_get_dummy_context",
            ".get_dummy_context",
            "fscrypt_free_dummy_context",
        ),
    }
    contents = {
        "of2fs/f2fs.h": f2fs_h,
        "of2fs/super.c": f2fs_c,
        "oext4/ext4.h": ext4_h,
        "oext4/super.c": ext4_c,
    }
    for name, tokens in required.items():
        for token in tokens:
            if token not in contents[name]:
                raise SystemExit(f"semantic guard failed: {name} lacks {token}")

    report = "\n".join(report_lines) + "\n"
    print(report, end="")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(report)


if __name__ == "__main__":
    main()
