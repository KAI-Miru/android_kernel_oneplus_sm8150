#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TAG_NAME=ASB-2023-02-05_4.14-stable
TAG_OBJECT=fb7d1aa1e00554d9ac07b2a6267f58e585569b81
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
SCAFFOLD=b92a77e96dd54fd30f8f39c7eef23e76f211c515
OUT=lts305-conflict-history

readarray -t PATHS <<'EOF'
Documentation/arm64/silicon-errata.txt
arch/arm64/Kconfig
arch/arm64/include/asm/cpucaps.h
arch/arm64/include/asm/cputype.h
arch/arm64/kernel/cpu_errata.c
arch/arm64/kernel/setup.c
arch/arm64/mm/mmu.c
drivers/char/Kconfig
drivers/clk/qcom/clk-rcg2.c
drivers/edac/edac_device.c
drivers/mailbox/mailbox.c
drivers/mmc/core/host.c
drivers/mmc/core/mmc_ops.c
drivers/mmc/host/sdhci.c
drivers/net/ethernet/stmicro/stmmac/stmmac_hwtstamp.c
drivers/rpmsg/qcom_glink_native.c
drivers/usb/core/quirks.c
drivers/usb/dwc3/core.c
drivers/usb/gadget/function/f_fs.c
drivers/usb/gadget/function/rndis.c
drivers/usb/host/xhci.c
drivers/usb/host/xhci.h
fs/fat/fatent.c
include/net/netfilter/nf_queue.h
include/net/sock.h
include/uapi/linux/virtio_ids.h
kernel/exit.c
kernel/panic.c
lib/Makefile
mm/memory.c
net/ipv4/tcp_output.c
net/ipv6/ip6_output.c
net/netfilter/nf_conntrack_irc.c
EOF

rm -rf "${OUT}"
mkdir -p "${OUT}/target-logs" "${OUT}/target-patches" \
         "${OUT}/target-diffs" "${OUT}/downstream-logs" \
         "${OUT}/scaffold-files"

test "$(git rev-parse HEAD)" = "$(git ls-remote origin refs/heads/miru-h40-lts305-integration | awk '{print $1}')"
test "$(git ls-remote origin refs/heads/miru-h40 | awk '{print $1}')" = "${PRODUCTION_SHA}"
git merge-base --is-ancestor "${SCAFFOLD}" HEAD
git merge-base --is-ancestor "${PRODUCTION_SHA}" HEAD
git merge-base --is-ancestor "${TARGET_COMMIT}" HEAD

git remote add android-common https://android.googlesource.com/kernel/common
git fetch --force --no-tags android-common \
  "refs/tags/${TAG_NAME}:refs/tags/${TAG_NAME}"
test "$(git rev-parse refs/tags/${TAG_NAME})" = "${TAG_OBJECT}"
test "$(git rev-parse refs/tags/${TAG_NAME}^{})" = "${TARGET_COMMIT}"

for path in "${PATHS[@]}"; do
  mkdir -p "${OUT}/target-logs/$(dirname "${path}")" \
           "${OUT}/target-patches/$(dirname "${path}")" \
           "${OUT}/target-diffs/$(dirname "${path}")" \
           "${OUT}/downstream-logs/$(dirname "${path}")" \
           "${OUT}/scaffold-files/$(dirname "${path}")"

  git log --reverse --format='%H%x09%ad%x09%s' --date=short \
    "${PREVIOUS_TARGET}..${TARGET_COMMIT}" -- "${path}" \
    > "${OUT}/target-logs/${path}.log"
  git log --reverse --format=fuller -p --find-renames \
    "${PREVIOUS_TARGET}..${TARGET_COMMIT}" -- "${path}" \
    > "${OUT}/target-patches/${path}.patch"
  git diff --histogram --find-renames "${PREVIOUS_TARGET}" "${TARGET_COMMIT}" -- "${path}" \
    > "${OUT}/target-diffs/${path}.diff"
  git log --reverse --format='%H%x09%ad%x09%s' --date=short \
    "${PREVIOUS_TARGET}..${PRODUCTION_SHA}" -- "${path}" \
    > "${OUT}/downstream-logs/${path}.log"
  git show "${SCAFFOLD}:${path}" > "${OUT}/scaffold-files/${path}"
done

{
  echo "source_head=$(git rev-parse HEAD)"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "previous_target=${PREVIOUS_TARGET}"
  echo "target_commit=${TARGET_COMMIT}"
  echo "scaffold=${SCAFFOLD}"
  echo "path_count=${#PATHS[@]}"
  echo "target_range_commit_count=$(git rev-list --count "${PREVIOUS_TARGET}..${TARGET_COMMIT}")"
} | tee "${OUT}/summary.txt"

find "${OUT}" -type f -print0 | sort -z | xargs -0 sha256sum > "${OUT}/SHA256SUMS"
