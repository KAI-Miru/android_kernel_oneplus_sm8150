#!/usr/bin/env bash
set -Eeuo pipefail

BASE=scripts/miru/lts305_apply_virtio_id_resolution.sh
EXPECTED_BASE_BLOB=f3a5172fedff43f7a882318d495ca4ee818c560d

test "$(git rev-parse "HEAD:${BASE}")" = "${EXPECTED_BASE_BLOB}"
TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

python3 - "${BASE}" "${TMP}" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
replacements = {
    '"${KERNEL_WORKTREE}/scripts/config" --file "${OUT_DIR}/.config" --enable VIRTIO\n':
        '"${KERNEL_WORKTREE}/scripts/config" --file "${OUT_DIR}/.config" --enable VIRTIO_MMIO\n',
    '  echo "consumer_compile_overlay=CONFIG_VIRTIO=y"\n':
        '  echo "consumer_compile_overlay=CONFIG_VIRTIO_MMIO=y selects CONFIG_VIRTIO=y"\n',
    'using the pinned H.40 toolchain and a compile-only `CONFIG_VIRTIO=y` overlay derived from the stock configuration.':
        'using the pinned H.40 toolchain and a compile-only `CONFIG_VIRTIO_MMIO=y` transport overlay, which selects `CONFIG_VIRTIO=y`, derived from the stock configuration.',
}
for old, new in replacements.items():
    if source.count(old) != 1:
        raise SystemExit(f"expected exactly one driver fragment: {old!r}")
    source = source.replace(old, new, 1)
Path(sys.argv[2]).write_text(source)
PY

bash -n "${TMP}"
grep -Fq -- '--enable VIRTIO_MMIO' "${TMP}"
grep -Fq 'CONFIG_VIRTIO_MMIO=y selects CONFIG_VIRTIO=y' "${TMP}"
grep -Fq 'transport overlay, which selects `CONFIG_VIRTIO=y`' "${TMP}"
exec bash "${TMP}"
