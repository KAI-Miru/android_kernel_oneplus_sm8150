#!/usr/bin/env bash
set -Eeuo pipefail
TMP_DRIVER="$(mktemp)"
trap 'rm -f "${TMP_DRIVER}"' EXIT
sed 's#python3 scripts/miru/lts305_resolve_arm64.py#python3 scripts/miru/lts305_resolve_arm64_v2.py#' \
  scripts/miru/lts305_apply_arm64_resolution.sh > "${TMP_DRIVER}"
bash "${TMP_DRIVER}"
