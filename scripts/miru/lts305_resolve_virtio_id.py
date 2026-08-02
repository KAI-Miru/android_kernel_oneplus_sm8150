#!/usr/bin/env python3
from pathlib import Path
import subprocess

PATH = Path("include/uapi/linux/virtio_ids.h")
PATCH = Path("lts305-virtio-id-resolution.patch")
INSERT_AFTER = "#define VIRTIO_ID_PMEM         27 /* virtio pmem */\n"
NEW_LINE = "#define VIRTIO_ID_MAC80211_HWSIM 29 /* virtio mac80211-hwsim */\n"

text = PATH.read_text()
if text.count(INSERT_AFTER) != 1:
    raise SystemExit("expected exactly one VIRTIO_ID_PMEM anchor")
if "VIRTIO_ID_MAC80211_HWSIM" in text:
    raise SystemExit("VIRTIO_ID_MAC80211_HWSIM already present")

required_downstream = {
    "VIRTIO_ID_CLOCK": 30,
    "VIRTIO_ID_REGULATOR": 31,
    "VIRTIO_ID_I2C": 32,
    "VIRTIO_ID_SPMI": 33,
    "VIRTIO_ID_FASTRPC": 34,
}
for name, value in required_downstream.items():
    token = f"#define {name}"
    lines = [line for line in text.splitlines() if line.startswith(token)]
    if len(lines) != 1 or not lines[0].split()[2].isdigit() or int(lines[0].split()[2]) != value:
        raise SystemExit(f"unexpected downstream ID definition for {name}")

text = text.replace(INSERT_AFTER, INSERT_AFTER + NEW_LINE, 1)
PATH.write_text(text)

updated = PATH.read_text()
if updated.count(NEW_LINE) != 1:
    raise SystemExit("failed to add exact MAC80211_HWSIM ID definition")
for name, value in required_downstream.items():
    lines = [line for line in updated.splitlines() if line.startswith(f"#define {name}")]
    if len(lines) != 1 or int(lines[0].split()[2]) != value:
        raise SystemExit(f"downstream ID changed for {name}")

patch = subprocess.check_output(
    ["git", "diff", "--binary", "--full-index", "--", str(PATH)],
    text=True,
)
if not patch.strip():
    raise SystemExit("resolver produced an empty patch")
PATCH.write_text(patch)
print(f"resolved {PATH}")
