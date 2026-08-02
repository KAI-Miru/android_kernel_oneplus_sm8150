#!/usr/bin/env bash
set -Eeuo pipefail
TMP_DRIVER="$(mktemp)"
trap 'rm -f "${TMP_DRIVER}"' EXIT
sed \
  -e 's#python3 scripts/miru/lts305_resolve_core_fatal.py#python3 scripts/miru/lts305_resolve_core_fatal_v2.py#' \
  -e 's#daaae4d64d68d18986a067785e83ab3391ffdb714b8fc8a9710c385b5eb8a034#1c719cf6207dd2e93928710e6420b3d812ac7b124655151173ebcc1b63733446#g' \
  scripts/miru/lts305_apply_core_fatal_resolution.sh > "${TMP_DRIVER}"
bash "${TMP_DRIVER}"
