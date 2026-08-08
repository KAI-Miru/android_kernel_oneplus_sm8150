#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <kernel-config>" >&2
  exit 2
fi

cfg="$1"
test -f "${cfg}"

# Preserve the validated Stage 2 / Stage 3B configuration while removing
# production-only debug overhead identified by the Stage 4 audit.
scripts/config --file "${cfg}" \
  --enable HAVE_USERSPACE_LOW_MEMORY_KILLER \
  --disable ANDROID_LOW_MEMORY_KILLER \
  --disable ANDROID_LOW_MEMORY_KILLER_AUTODETECT_OOM_ADJ_VALUES \
  --enable ION_DEFER_FREE_NO_SCHED_IDLE \
  --disable OPLUS_FEATURE_LOWMEM_DBG \
  --disable DEBUG_LIST

grep -Fxq 'CONFIG_HAVE_USERSPACE_LOW_MEMORY_KILLER=y' "${cfg}"
grep -Fxq '# CONFIG_ANDROID_LOW_MEMORY_KILLER is not set' "${cfg}"
grep -Fxq 'CONFIG_ION_DEFER_FREE_NO_SCHED_IDLE=y' "${cfg}"
grep -Fxq '# CONFIG_OPLUS_FEATURE_LOWMEM_DBG is not set' "${cfg}"
grep -Fxq '# CONFIG_DEBUG_LIST is not set' "${cfg}"
