#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import subprocess

STABLE = "d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac"
INLINE = pathlib.Path("fs/crypto/inline_crypt.c")
KEYRING = pathlib.Path("fs/crypto/keyring.c")
CHECKPOINT = pathlib.Path("fs/f2fs/checkpoint.c")
INCFS = pathlib.Path("fs/incfs/data_mgmt.c")
LEDGER = pathlib.Path("Documentation/miru/lts-4.14.190-conflicts.md")

EXPECTED_HASHES = {
    INLINE: "58fe5086f012d9232df1483695c9623584f6d185",
    KEYRING: "58613db575a74bb576d3e3c28b07fccc5c3429eb",
    CHECKPOINT: "1cfcc328fca2629f6c7cb94d59b7a174a2052476",
    INCFS: "e0705be44fb2280fb65df30472368882fef136e3",
    LEDGER: "52a2ed1428c6789c3c20030e76eb331b951bbf72",
}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def replace_exact(text: str, old: str, new: str, expected_count: int = 1) -> str:
    count = text.count(old)
    if count != expected_count:
        raise SystemExit(
            f"replacement guard failed: expected {expected_count}, found {count}: {old!r}"
        )
    return text.replace(old, new, expected_count)


def verify_hashes() -> None:
    for path, expected in EXPECTED_HASHES.items():
        actual = git("hash-object", str(path)).strip()
        if actual != expected:
            raise SystemExit(f"{path}: expected blob {expected}, found {actual}")


def stable_file(path: pathlib.Path) -> str:
    return git("show", f"{STABLE}:{path}")


def resolve_inline_crypt() -> None:
    text = INLINE.read_text()
    old = """\t/* The filesystem must be mounted with -o inlinecrypt */
\tif (!sb->s_cop->inline_crypt_enabled ||
\t    !sb->s_cop->inline_crypt_enabled(sb))
\t\treturn 0;

\t/*
\t * The needed encryption settings must be supported either by
"""
    new = """\t/* The filesystem must be mounted with -o inlinecrypt */
\tif (!sb->s_cop->inline_crypt_enabled ||
\t    !sb->s_cop->inline_crypt_enabled(sb))
\t\treturn 0;

\t/*
\t * When a page contains multiple logically contiguous filesystem blocks,
\t * some filesystem code only calls fscrypt_mergeable_bio() for the first
\t * block in the page. This is fine for most of fscrypt's IV generation
\t * strategies, where contiguous blocks imply contiguous IVs. But it
\t * doesn't work with IV_INO_LBLK_32. For now, simply exclude
\t * IV_INO_LBLK_32 with blocksize != PAGE_SIZE from inline encryption.
\t */
\tif ((fscrypt_policy_flags(&ci->ci_policy) &
\t     FSCRYPT_POLICY_FLAG_IV_INO_LBLK_32) &&
\t    sb->s_blocksize != PAGE_SIZE)
\t\treturn 0;

\t/*
\t * The needed encryption settings must be supported either by
"""
    text = replace_exact(text, old, new)

    required_h40 = (
        "static int fscrypt_find_storage_type(char **device)",
        "FSCRYPT_MODE_PRIVATE",
        'char *s_type = "ufs";',
        '!strcmp(s_type, "sdhci")',
        "bio->bi_crypt_context->is_ext4 = true;",
        "const struct fscrypt_info *ci = inode->i_crypt_info;",
        "With IV_INO_LBLK_32 and sub-page blocks",
    )
    for token in required_h40:
        if token not in text:
            raise SystemExit(f"inline_crypt lost H.40 behavior: {token}")
    if text.count("When a page contains multiple logically contiguous") != 1:
        raise SystemExit("stable inline-crypto safety gate missing or duplicated")

    INLINE.write_text(text)


def resolve_keyring() -> None:
    text = stable_file(KEYRING)

    old_decl = """static int add_master_key(struct super_block *sb,
\t\t\t  struct fscrypt_master_key_secret *secret,
\t\t\t  struct fscrypt_key_specifier *key_spec)
{
\tint err;

\tif (key_spec->type == FSCRYPT_KEY_SPEC_TYPE_IDENTIFIER) {
"""
    new_decl = """static int add_master_key(struct super_block *sb,
\t\t\t  struct fscrypt_master_key_secret *secret,
\t\t\t  struct fscrypt_key_specifier *key_spec)
{
\tint err;
\tint retry_count = 0;

\tif (key_spec->type == FSCRYPT_KEY_SPEC_TYPE_IDENTIFIER) {
"""
    text = replace_exact(text, old_decl, new_decl)

    old_derive = """\t\tif (secret->is_hw_wrapped) {
\t\t\tkdf_key = _kdf_key;
\t\t\tkdf_key_size = RAW_SECRET_SIZE;
\t\t\terr = fscrypt_derive_raw_secret(sb, secret->raw,
\t\t\t\t\t\t\tsecret->size,
\t\t\t\t\t\t\tkdf_key, kdf_key_size);
\t\t\tif (err)
\t\t\t\treturn err;
\t\t}
"""
    new_derive = """\t\tif (secret->is_hw_wrapped) {
\t\t\tkdf_key = _kdf_key;
\t\t\tkdf_key_size = RAW_SECRET_SIZE;
\t\t\tdo {
\t\t\t\terr = fscrypt_derive_raw_secret(sb, secret->raw,
\t\t\t\t\t\t\t\tsecret->size,
\t\t\t\t\t\t\t\tkdf_key,
\t\t\t\t\t\t\t\tkdf_key_size);
\t\t\t\tif (err)
\t\t\t\t\treturn err;
\t\t\t} while (kdf_key[10] == 0 && kdf_key[11] == 0 &&
\t\t\t\t kdf_key[12] == 0 && kdf_key[13] == 0 &&
\t\t\t\t kdf_key[14] == 0 && kdf_key[15] == 0 &&
\t\t\t\t kdf_key[16] == 0 && kdf_key[17] == 0 &&
\t\t\t\t retry_count++ <= 3);
\t\t}
"""
    text = replace_exact(text, old_derive, new_derive)

    required = (
        "#include <linux/random.h>",
        "static int do_add_master_key(",
        "int fscrypt_add_test_dummy_key(",
        "get_random_once(test_key, FSCRYPT_MAX_KEY_SIZE);",
        "fscrypt_destroy_prepared_key(&mk->mk_iv_ino_lblk_32_keys[i]);",
        "int retry_count = 0;",
        "retry_count++ <= 3",
        "secret.is_hw_wrapped = true;",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"keyring missing required behavior: {token}")
    if "fscrypt_err(NULL" in text:
        raise SystemExit("temporary H.40 debug logging survived keyring refactor")

    KEYRING.write_text(text)


def resolve_checkpoint() -> None:
    text = CHECKPOINT.read_text()

    replacements = (
        (
            """\tsbi->ckpt = f2fs_kzalloc(sbi, array_size(blk_size, cp_blks),
\t\t\t\t GFP_KERNEL);
""",
            """\tsbi->ckpt = f2fs_kvzalloc(sbi, array_size(blk_size, cp_blks),
\t\t\t\t  GFP_KERNEL);
""",
        ),
        (
            """\tint err = 0, cnt = 0;

retry_flush_quotas:
""",
            """\tint err = 0, cnt = 0;

\t/*
\t * Let's flush inline_data in dirty node pages.
\t */
\tf2fs_flush_inline_data(sbi);

retry_flush_quotas:
""",
        ),
        (
            """\t\tif (unlikely(f2fs_cp_error(sbi)))
\t\t\tbreak;

\t\tio_schedule_timeout(DEFAULT_IO_TIMEOUT);
""",
            """\t\tif (unlikely(f2fs_cp_error(sbi)))
\t\t\tbreak;

\t\tif (type == F2FS_DIRTY_META)
\t\t\tf2fs_sync_meta_pages(sbi, META, LONG_MAX,
\t\t\t\t\t\t\tFS_CP_META_IO);
\t\tio_schedule_timeout(DEFAULT_IO_TIMEOUT);
""",
        ),
        (
            """\tmutex_lock(&sbi->cp_mutex);
#if defined(VENDOR_EDIT) && defined(CONFIG_UFSTW)
\tbdev_set_turbo_write(sbi->sb->s_bdev);
#endif
""",
            """\tif (cpc->reason != CP_RESIZE)
\t\tmutex_lock(&sbi->cp_mutex);
#if defined(VENDOR_EDIT) && defined(CONFIG_UFSTW)
\tbdev_set_turbo_write(sbi->sb->s_bdev);
#endif
""",
        ),
        (
            """#if defined(VENDOR_EDIT) && defined(CONFIG_UFSTW)
\tbdev_clear_turbo_write(sbi->sb->s_bdev);
#endif
\tmutex_unlock(&sbi->cp_mutex);
\treturn err;
""",
            """#if defined(VENDOR_EDIT) && defined(CONFIG_UFSTW)
\tbdev_clear_turbo_write(sbi->sb->s_bdev);
#endif
\tif (cpc->reason != CP_RESIZE)
\t\tmutex_unlock(&sbi->cp_mutex);
\treturn err;
""",
        ),
    )
    for old, new in replacements:
        text = replace_exact(text, old, new)

    required = (
        "#include <linux/ufstw.h>",
        "bdev_set_turbo_write(sbi->sb->s_bdev);",
        "bdev_clear_turbo_write(sbi->sb->s_bdev);",
        "f2fs_kvzalloc(sbi, array_size(blk_size, cp_blks)",
        "f2fs_flush_inline_data(sbi);",
        "f2fs_sync_meta_pages(sbi, META, LONG_MAX,",
        "if (cpc->reason != CP_RESIZE)",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"checkpoint missing required behavior: {token}")
    if text.count("CONFIG_UFSTW") != 3:
        raise SystemExit("UFSTW guards changed unexpectedly")
    if text.count("bdev_set_turbo_write") != 1 or text.count("bdev_clear_turbo_write") != 1:
        raise SystemExit("UFSTW checkpoint hooks missing or duplicated")

    CHECKPOINT.write_text(text)


def resolve_incfs() -> None:
    text = stable_file(INCFS)
    required = (
        "bfc = incfs_alloc_bfc(bf);",
        "static int validate_hash_tree(struct file *bf, struct file *f,",
        "result = incfs_kread(bf, dst.data, bytes_to_read, pos);",
        "struct file *bf = df->df_backing_file_context->bc_file;",
        'pr_debug("incfs: %s %d error: %d\\n", __func__,',
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"IncFS stable API missing: {token}")
    forbidden = (
        "incfs_alloc_bfc(mi, bf)",
        "incfs_kread(bfc,",
        "kfree(df->df_signature);",
    )
    for token in forbidden:
        if token in text:
            raise SystemExit(f"IncFS retained obsolete API/ownership: {token}")
    INCFS.write_text(text)


def validate_tree_dependencies() -> None:
    grep = git("grep", "-n", "fscrypt_add_test_dummy_key", "--", "fs/crypto")
    if len(grep.splitlines()) < 2:
        raise SystemExit("fscrypt dummy-key declaration/callsite is missing")

    grep = git("grep", "-n", "f2fs_kvzalloc", "--", "fs/f2fs")
    if len(grep.splitlines()) < 2:
        raise SystemExit("f2fs_kvzalloc helper is missing from the merged tree")

    grep = git("grep", "-n", "incfs_alloc_bfc", "--", "fs/incfs")
    if "incfs_alloc_bfc(mi, bf)" in grep:
        raise SystemExit("IncFS still contains the obsolete mount-info allocation call")

    grep = git("grep", "-n", "incfs_kread", "--", "fs/incfs")
    if "incfs_kread(bfc," in grep or "incfs_kread(df->df_backing_file_context," in grep:
        raise SystemExit("IncFS still contains obsolete backing-context read calls")


def update_ledger() -> None:
    text = LEDGER.read_text()
    replacements = {
        "- Resolved conflicts: 11": "- Resolved conflicts: 15",
        "- Remaining conflicts: 17": "- Remaining conflicts: 13",
        "fs/crypto/inline_crypt.c\n": "",
        "fs/crypto/keyring.c\n": "",
        "fs/f2fs/checkpoint.c\n": "",
        "fs/incfs/data_mgmt.c\n": "",
    }
    for old, new in replacements.items():
        text = replace_exact(text, old, new)

    marker = "## Remaining deferred conflicts\n"
    if text.count(marker) != 1:
        raise SystemExit("remaining-conflicts marker missing or duplicated")

    section = """## Resolved in Step 4

The fscrypt, F2FS and IncFS conflicts were resolved as one storage-consistency
unit:

```text
fs/crypto/inline_crypt.c
fs/crypto/keyring.c
fs/f2fs/checkpoint.c
fs/incfs/data_mgmt.c
```

`inline_crypt.c` preserves H.40's private-mode UFS/SDHCI DUN sizing, ext4
crypto-context flag and defensive direct-I/O check. It adds Android stable's
IV_INO_LBLK_32/sub-page exclusion before inline encryption is selected.

`keyring.c` uses Android stable's separated `do_add_master_key()` flow,
hardware-wrapped-key validation and per-boot test-dummy key support. H.40's
five-attempt raw-secret derivation workaround is retained without its temporary
error-path debug spam.

`checkpoint.c` adopts `f2fs_kvzalloc()`, inline-data flushing, active metadata
writeback while waiting, and CP_RESIZE mutex handling. H.40's UFSTW checkpoint
turbo-write hooks remain active.

`data_mgmt.c` matches Android 4.14.190's IncFS file-based backing-I/O API and
signature ownership. This aligns it with the already merged IncFS headers and
support code.

Resolution commit:

```text
lts: resolve fscrypt f2fs and incfs conflicts
```

"""
    LEDGER.write_text(text.replace(marker, section + marker, 1))


def main() -> None:
    verify_hashes()
    resolve_inline_crypt()
    resolve_keyring()
    resolve_checkpoint()
    resolve_incfs()
    validate_tree_dependencies()
    update_ledger()
    print("Step 4 guarded resolution completed.")


if __name__ == "__main__":
    main()
