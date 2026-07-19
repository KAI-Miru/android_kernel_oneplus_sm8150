#!/usr/bin/env python3

from pathlib import Path
import subprocess

PATCHER = Path("scripts/miru/apply_vendor_lts190_compat_v6.py")
EXPECTED_BLOB = "044cc260e47a887d2394567a6882421199866e1f"

actual = subprocess.check_output(["git", "hash-object", str(PATCHER)], text=True).strip()
if actual != EXPECTED_BLOB:
    raise SystemExit(f"vendor v6 patcher changed: expected {EXPECTED_BLOB}, found {actual}")

lines = PATCHER.read_text().splitlines(keepends=True)
count_line = '    if text.count("F2FS_OPTION(sbi).test_dummy_encryption") != 1:\n'
raise_line = '        raise SystemExit("expected exactly one direct of2fs dummy boolean assignment")\n'
final_line = '    if "F2FS_OPTION(sbi).test_dummy_encryption" in text:\n'

if lines.count(count_line) != 1 or lines.count(raise_line) != 1:
    raise SystemExit("redundant direct-reference guard lines missing or duplicated")
count_index = lines.index(count_line)
if count_index + 1 >= len(lines) or lines[count_index + 1] != raise_line:
    raise SystemExit("redundant direct-reference guard lines are not adjacent")
del lines[count_index:count_index + 2]
if count_index < len(lines) and lines[count_index] == "\n":
    del lines[count_index]

if lines.count(final_line) != 1:
    raise SystemExit("final direct-reference guard line missing or duplicated")
final_index = lines.index(final_line)
cleanup = [
    '    text = base.replace_exact(\n',
    '        text,\n',
    '        "\\tif (F2FS_OPTION(sbi).test_dummy_encryption)\\n"\n',
    '        "\\t\\tseq_puts(seq, \\\",test_dummy_encryption\\\");\\n",\n',
    '        "\\tfscrypt_show_test_dummy_encryption(seq, \',\', sbi->sb);\\n",\n',
    '    )\n',
    '    text = base.replace_exact(\n',
    '        text,\n',
    '        "\\tF2FS_OPTION(sbi).test_dummy_encryption = false;\\n",\n',
    '        "",\n',
    '    )\n',
    '\n',
]
lines[final_index:final_index] = cleanup
PATCHER.write_text("".join(lines))

updated = PATCHER.read_text()
if count_line.rstrip("\n") in updated:
    raise SystemExit("redundant direct-reference count guard remains")
if updated.count('F2FS_OPTION(sbi).test_dummy_encryption = false;') != 1:
    raise SystemExit("default boolean cleanup was not inserted exactly once")
if updated.count('if (F2FS_OPTION(sbi).test_dummy_encryption)') != 1:
    raise SystemExit("mount-option display cleanup was not inserted exactly once")
print("Vendor v6 patcher prepared line-by-line.")
