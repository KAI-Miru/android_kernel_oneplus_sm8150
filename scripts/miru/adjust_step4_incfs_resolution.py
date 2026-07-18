#!/usr/bin/env python3

from pathlib import Path

path = Path("scripts/miru/resolve_step4.py")
text = path.read_text()

start = text.index("def resolve_incfs() -> None:\n")
end = text.index("def update_ledger() -> None:\n")

replacement = '''def resolve_incfs() -> None:
    text = INCFS.read_text()
    required = (
        "bfc = incfs_alloc_bfc(mi, bf);",
        "static int validate_hash_tree(struct backing_file_context *bfc,",
        "result = incfs_kread(bfc, dst.data, bytes_to_read, pos);",
        "kfree(df->df_signature);",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"IncFS lost required H.40 API/ownership: {token}")
    if git("hash-object", str(INCFS)).strip() != EXPECTED_HASHES[INCFS]:
        raise SystemExit("IncFS data_mgmt.c changed unexpectedly")


def validate_tree_dependencies() -> None:
    grep = git("grep", "-n", "fscrypt_add_test_dummy_key", "--", "fs/crypto")
    if len(grep.splitlines()) < 2:
        raise SystemExit("fscrypt dummy-key declaration/callsite is missing")

    grep = git("grep", "-n", "f2fs_kvzalloc", "--", "fs/f2fs")
    if len(grep.splitlines()) < 2:
        raise SystemExit("f2fs_kvzalloc helper is missing from the merged tree")

    alloc_uses = git("grep", "-n", "incfs_alloc_bfc", "--", "fs/incfs")
    required_alloc = (
        "fs/incfs/data_mgmt.c:",
        "incfs_alloc_bfc(mi, bf)",
        "fs/incfs/format.c:",
        "struct backing_file_context *incfs_alloc_bfc(struct mount_info *mi,",
        "fs/incfs/format.h:",
        "fs/incfs/vfs.c:",
        "incfs_alloc_bfc(mi, new_file)",
    )
    for token in required_alloc:
        if token not in alloc_uses:
            raise SystemExit(f"IncFS allocation API mismatch: {token}")

    read_uses = git("grep", "-n", "incfs_kread", "--", "fs/incfs")
    required_read = (
        "ssize_t incfs_kread(struct backing_file_context *bfc",
        "incfs_kread(bfc,",
        "incfs_kread(df->df_backing_file_context,",
    )
    for token in required_read:
        if token not in read_uses:
            raise SystemExit(f"IncFS backing-context read API mismatch: {token}")


'''

text = text[:start] + replacement + text[end:]

old_doc = '''`data_mgmt.c` matches Android 4.14.190's IncFS file-based backing-I/O API and
signature ownership. This aligns it with the already merged IncFS headers and
support code.
'''
new_doc = '''`data_mgmt.c` remains byte-for-byte H.40. The surrounding `format.c`,
`format.h` and `vfs.c` still use the mount-aware `backing_file_context` API, so
taking Android stable's newer file-based calls would create a source-level ABI
mismatch. H.40's signature ownership and explicit `df_signature` cleanup are
therefore retained.
'''
if text.count(old_doc) != 1:
    raise SystemExit("Step 4 ledger paragraph guard failed")
text = text.replace(old_doc, new_doc, 1)

path.write_text(text)
