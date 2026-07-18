#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import subprocess

DM = pathlib.Path("drivers/md/dm-default-key.c")
BLOCK = pathlib.Path("fs/block_dev.c")
FSH = pathlib.Path("include/linux/fs.h")
LEDGER = pathlib.Path("Documentation/miru/lts-4.14.190-conflicts.md")

EXPECTED_HASHES = {
    DM: "277a21d74830a462d16828c6e8f3b40f7ff338ce",
    BLOCK: "11bf35659b128619f523314213dc2db7a0062f25",
    FSH: "da4fc467e8349abd0ca455ae78554368176239cc",
    LEDGER: "2157ed35df128303184ddc2243047623451c11b4",
}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def replace_exact(text: str, old: str, new: str, expected_count: int = 1) -> str:
    count = text.count(old)
    if count != expected_count:
        raise SystemExit(
            f"replacement guard failed: expected {expected_count} copies, found {count}: {old!r}"
        )
    return text.replace(old, new, expected_count)


def verify_hashes() -> None:
    for path, expected in EXPECTED_HASHES.items():
        actual = git("hash-object", str(path)).strip()
        if actual != expected:
            raise SystemExit(f"{path}: expected blob {expected}, found {actual}")


def validate_dm_default_key() -> None:
    text = DM.read_text()
    required = (
        'bool set_dun;',
        '!strcmp(opt_string, "set_dun")',
        '!strcmp(argv[0], "AES-256-XTS")',
        'default_key_adjust_sector_size_and_iv',
        '!strcmp((*dkc)->dev->bdev->bd_disk->disk_name, "mmcblk0")',
        'blk_crypto_init_key',
        'blk_crypto_start_using_mode',
        'ti->may_passthrough_inline_crypto = true;',
        'bio_crypt_set_ctx',
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"dm-default-key lost required H.40 token: {token}")

    if git("hash-object", str(DM)).strip() != EXPECTED_HASHES[DM]:
        raise SystemExit("dm-default-key changed unexpectedly")


def update_block_dev() -> None:
    text = BLOCK.read_text()
    iomonitor_before = text.count("OPLUS_FEATURE_IOMONITOR")
    update_calls_before = text.count("iomonitor_update_rw_stats")
    if iomonitor_before != 6 or update_calls_before != 2:
        raise SystemExit(
            f"unexpected Oplus I/O monitor layout: tokens={iomonitor_before}, calls={update_calls_before}"
        )

    text = replace_exact(
        text,
        "result = blk_queue_enter(bdev->bd_queue, 0);",
        "result = blk_queue_enter(bdev->bd_queue, false);",
        expected_count=2,
    )

    text = replace_exact(
        text,
        "\t\t\tif (ret) {\n                                bdput(whole);\n\t\t\t\tgoto out_clear;\n                        }",
        "\t\t\tif (ret) {\n\t\t\t\tbdput(whole);\n\t\t\t\tgoto out_clear;\n\t\t\t}",
    )

    text = replace_exact(
        text,
        "\t\tmutex_unlock(&bdev->bd_mutex);\n\t\tbdput(whole);\n                if(res)\n                       bdput(bdev);\n\n\t}\n\n\treturn res;",
        "\t\tmutex_unlock(&bdev->bd_mutex);\n\t\tbdput(whole);\n\t}\n\n\tif (res)\n\t\tbdput(bdev);\n\n\treturn res;",
    )

    if text.count("OPLUS_FEATURE_IOMONITOR") != iomonitor_before:
        raise SystemExit("Oplus I/O monitor feature tokens changed")
    if text.count("iomonitor_update_rw_stats") != update_calls_before:
        raise SystemExit("Oplus I/O monitor calls changed")
    if text.count("blk_queue_enter(bdev->bd_queue, false);") != 2:
        raise SystemExit("block queue boolean cleanup missing")
    if "\n\tif (res)\n\t\tbdput(bdev);\n\n\treturn res;" not in text:
        raise SystemExit("blkdev_get delayed bdput fix missing")

    BLOCK.write_text(text)


def update_fs_header() -> None:
    text = FSH.read_text()

    text = replace_exact(
        text,
        "extern int sysctl_protected_regular;\ntypedef __kernel_rwf_t rwf_t;",
        "extern int sysctl_protected_regular;\n\ntypedef __kernel_rwf_t rwf_t;",
    )
    text = replace_exact(
        text,
        "unsigned char f_handle[0];",
        "unsigned char f_handle[];",
    )

    required_vendor = (
        "#ifdef CONFIG_FILE_TABLE_DEBUG",
        "struct hlist_node f_hash;",
        "extern struct dentry *vfs_tmpfile(struct vfsmount *mnt,",
        "void (*umount_end) (struct super_block *, int);",
        "int get_filesystem_list_runtime(char *buf);",
        "if (flags & RWF_APPEND)",
        "ki->ki_flags |= IOCB_APPEND;",
    )
    for token in required_vendor:
        if token not in text:
            raise SystemExit(f"fs.h lost required H.40 interface: {token}")

    if "unsigned char f_handle[0];" in text:
        raise SystemExit("zero-length file-handle array remains")
    if text.count("unsigned char f_handle[];") != 1:
        raise SystemExit("flexible file-handle array missing or duplicated")

    FSH.write_text(text)


def update_ledger() -> None:
    text = LEDGER.read_text()
    replacements = {
        "- Resolved conflicts: 8": "- Resolved conflicts: 11",
        "- Remaining conflicts: 20": "- Remaining conflicts: 17",
        "drivers/md/dm-default-key.c\n": "",
        "fs/block_dev.c\n": "",
        "include/linux/fs.h\n": "",
    }
    for old, new in replacements.items():
        text = replace_exact(text, old, new)

    marker = "## Remaining deferred conflicts\n"
    if text.count(marker) != 1:
        raise SystemExit("remaining-conflicts marker missing or duplicated")

    section = """## Resolved in Step 3

The block core and device-mapper encryption conflicts were resolved as one
boot-critical unit:

```text
drivers/md/dm-default-key.c
fs/block_dev.c
include/linux/fs.h
```

`dm-default-key.c` remains byte-for-byte H.40 because it is a strict functional
superset of the Android stable version. This preserves the legacy `AES-256-XTS`
syntax conversion, wrapped-key handling, the accepted `set_dun` option, and the
legacy `mmcblk0` 512-byte sector compatibility path.

`block_dev.c` preserves the Oplus I/O-monitor hooks while applying Android
stable commit `a43abf15844c9e5de016957b8e612f447b7fb077`'s delayed `bdput(bdev)`
placement, fixing a `blkdev_get()` error-path use-after-free. The two
`blk_queue_enter()` boolean arguments are also updated from `0` to `false`.

`fs.h` preserves H.40's `RWF_APPEND`, file-table debugging, mount-aware
tmpfile API, `umount_end`, and runtime filesystem-list interfaces. It adopts
the stable flexible-array declaration `f_handle[]` in place of the zero-length
array `f_handle[0]`.

Resolution commit:

```text
lts: resolve block core and dm-default-key conflicts
```

"""
    LEDGER.write_text(text.replace(marker, section + marker, 1))


def main() -> None:
    verify_hashes()
    validate_dm_default_key()
    update_block_dev()
    update_fs_header()
    update_ledger()
    validate_dm_default_key()
    print("Step 3 guarded resolution completed.")


if __name__ == "__main__":
    main()
