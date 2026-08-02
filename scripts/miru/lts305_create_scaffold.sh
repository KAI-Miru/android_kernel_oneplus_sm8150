#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_BRANCH=miru-h40
INTEGRATION_BRANCH=miru-h40-lts305-integration
PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
PREVIOUS_TARGET=0eec6f6001d15bb1108835a642ec4637d75eef19
TAG_NAME=ASB-2023-02-05_4.14-stable
TAG_OBJECT=fb7d1aa1e00554d9ac07b2a6267f58e585569b81
TARGET_COMMIT=4415bf5e08942aee6487946a3e0a50956ef68f1e
TARGET_TREE=b13cdb6b1f31e75df2d2dddeed15b04dceeed939
LEDGER=Documentation/miru/lts-4.14.305-conflicts.md
DIAG=lts305-scaffold

readarray -t EXPECTED_CONFLICTS <<'EOF'
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

rm -rf "${DIAG}"
mkdir -p "${DIAG}"

pre_head="$(git rev-parse HEAD)"
remote_production="$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')"
remote_integration="$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')"
test "${remote_production}" = "${PRODUCTION_SHA}"
test "${remote_integration}" = "${pre_head}"
git merge-base --is-ancestor "${PRODUCTION_SHA}" "${pre_head}"

# A synchronize event caused by the scaffold push itself is a no-op.
if git merge-base --is-ancestor "${TARGET_COMMIT}" "${pre_head}" 2>/dev/null; then
  {
    echo "status=already-scaffolded"
    echo "head=${pre_head}"
    echo "parent1=$(git rev-parse HEAD^1)"
    echo "parent2=$(git rev-parse HEAD^2)"
  } | tee "${DIAG}/already-scaffolded.txt"
  exit 0
fi

grep -Fq -- '- Reconnaissance: **complete**' "${LEDGER}"
grep -Fq -- '- Target object verification: **PASS**' "${LEDGER}"
grep -Fq -- '- Authentic merge preview: **complete**' "${LEDGER}"
grep -Fq -- '- Initial authentic conflicts: **33**' "${LEDGER}"
grep -Fq -- '- Remaining semantic conflicts: **33**' "${LEDGER}"
grep -Fq -- 'GitHub Actions run `30233833545`' "${LEDGER}"
grep -Fq -- 'Artifact ID: `8641000034`' "${LEDGER}"

git remote add android-common https://android.googlesource.com/kernel/common
git fetch --force --no-tags android-common \
  "refs/tags/${TAG_NAME}:refs/tags/${TAG_NAME}"
resolved_tag="$(git rev-parse "refs/tags/${TAG_NAME}")"
peeled="$(git rev-parse "refs/tags/${TAG_NAME}^{}")"
tree="$(git rev-parse "${peeled}^{tree}")"
tag_rehash="$(git cat-file tag "${resolved_tag}" | git hash-object -t tag --stdin)"
commit_rehash="$(git cat-file commit "${peeled}" | git hash-object -t commit --stdin)"
test "${resolved_tag}" = "${TAG_OBJECT}"
test "$(git cat-file -t "${resolved_tag}")" = tag
test "${tag_rehash}" = "${TAG_OBJECT}"
test "${peeled}" = "${TARGET_COMMIT}"
test "$(git cat-file -t "${peeled}")" = commit
test "${commit_rehash}" = "${TARGET_COMMIT}"
test "${tree}" = "${TARGET_TREE}"
test "$(git show "${peeled}:Makefile" | sed -n 's/^SUBLEVEL = //p' | head -n1)" = 305
git merge-base --is-ancestor "${PREVIOUS_TARGET}" "${TARGET_COMMIT}"
! git merge-base --is-ancestor "${TARGET_COMMIT}" "${PRODUCTION_SHA}"

git config user.name "Miru LTS Integration Bot"
git config user.email "miru-lts-integration@users.noreply.github.com"

git status --porcelain=v2 --branch > "${DIAG}/pre-status-v2.txt"
test -z "$(git status --porcelain --untracked-files=no)"
pre_tree="$(git write-tree)"

set +e
git merge --no-commit --no-ff "${TARGET_COMMIT}" \
  >"${DIAG}/merge.stdout" 2>"${DIAG}/merge.stderr"
merge_rc=$?
set -e
test "${merge_rc}" -ne 0

git diff --name-only --diff-filter=U | LC_ALL=C sort > "${DIAG}/actual-conflicts.txt"
printf '%s\n' "${EXPECTED_CONFLICTS[@]}" | LC_ALL=C sort > "${DIAG}/expected-conflicts.txt"
diff -u "${DIAG}/expected-conflicts.txt" "${DIAG}/actual-conflicts.txt"
test "$(wc -l < "${DIAG}/actual-conflicts.txt" | tr -d ' ')" = 33

git ls-files -u > "${DIAG}/unmerged-index.txt"
test "$(wc -l < "${DIAG}/unmerged-index.txt" | tr -d ' ')" = 99
for path in "${EXPECTED_CONFLICTS[@]}"; do
  test "$(git ls-files -u -- "${path}" | awk '{print $3}' | sort -u | tr '\n' ' ')" = '1 2 3 '
done

# Preserve the exact stage-2/Miru identity for each conflict.
: > "${DIAG}/conflict-stage2-manifest.txt"
for path in "${EXPECTED_CONFLICTS[@]}"; do
  git ls-files -u -- "${path}" | awk '$3 == 2 { print $1, $2, $4 }' \
    >> "${DIAG}/conflict-stage2-manifest.txt"
done

# Record cleanly merged stage-0 entries before touching conflicts.
git diff --cached --name-only HEAD | LC_ALL=C sort > "${DIAG}/all-index-paths-before.txt"
comm -23 "${DIAG}/all-index-paths-before.txt" "${DIAG}/actual-conflicts.txt" \
  > "${DIAG}/cleanly-merged-paths.txt"
: > "${DIAG}/clean-index-manifest-before.txt"
while IFS= read -r path; do
  git ls-files -s -- "${path}" >> "${DIAG}/clean-index-manifest-before.txt"
done < "${DIAG}/cleanly-merged-paths.txt"

# Make the authentic two-parent scaffold representable by taking only Miru's
# stage-2 version for every authentic conflict. Semantic status stays unresolved.
for path in "${EXPECTED_CONFLICTS[@]}"; do
  git checkout --ours -- "${path}"
  git add -- "${path}"
done

test -z "$(git ls-files -u)"
: > "${DIAG}/conflict-stage0-manifest.txt"
for path in "${EXPECTED_CONFLICTS[@]}"; do
  git ls-files -s -- "${path}" >> "${DIAG}/conflict-stage0-manifest.txt"
done
awk '{print $1, $2, $3}' "${DIAG}/conflict-stage2-manifest.txt" > "${DIAG}/stage2-normalized.txt"
awk '{print $1, $2, $4}' "${DIAG}/conflict-stage0-manifest.txt" > "${DIAG}/stage0-normalized.txt"
diff -u "${DIAG}/stage2-normalized.txt" "${DIAG}/stage0-normalized.txt"

: > "${DIAG}/clean-index-manifest-after.txt"
while IFS= read -r path; do
  git ls-files -s -- "${path}" >> "${DIAG}/clean-index-manifest-after.txt"
done < "${DIAG}/cleanly-merged-paths.txt"
diff -u "${DIAG}/clean-index-manifest-before.txt" "${DIAG}/clean-index-manifest-after.txt"

git diff --cached --check
git commit -m 'Merge Android Common 4.14.305 scaffold'
scaffold="$(git rev-parse HEAD)"
parent1="$(git rev-parse HEAD^1)"
parent2="$(git rev-parse HEAD^2)"
test "${parent1}" = "${pre_head}"
test "${parent2}" = "${TARGET_COMMIT}"
git merge-base --is-ancestor "${PRODUCTION_SHA}" "${scaffold}"
git merge-base --is-ancestor "${TARGET_COMMIT}" "${scaffold}"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 305

{
  echo "status=created"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "preparation_parent=${pre_head}"
  echo "android_parent=${TARGET_COMMIT}"
  echo "scaffold_commit=${scaffold}"
  echo "scaffold_tree=$(git rev-parse HEAD^{tree})"
  echo "authentic_conflict_count=33"
  echo "conflicts_staged_from_miru_side=33"
  echo "semantic_conflicts_remaining=33"
  echo "target_sublevel=305"
} | tee "${DIAG}/scaffold-summary.txt"

git show --no-patch --format=raw "${scaffold}" > "${DIAG}/scaffold-commit.txt"
git diff-tree --no-commit-id --name-status -r -m "${scaffold}" \
  > "${DIAG}/scaffold-diff-tree.txt"
find "${DIAG}" -type f -print0 | sort -z | xargs -0 sha256sum > "${DIAG}/SHA256SUMS"

# Final exact remote-ref guards immediately before the non-force push.
test "$(git ls-remote origin "refs/heads/${PRODUCTION_BRANCH}" | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${INTEGRATION_BRANCH}" | awk '{print $1}')" = "${pre_head}"
git push origin "${scaffold}:refs/heads/${INTEGRATION_BRANCH}"
