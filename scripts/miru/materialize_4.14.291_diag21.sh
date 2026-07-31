#!/usr/bin/env bash
set -Eeuo pipefail
set -x

: "${PRODUCTION_SHA:?}"
: "${SCAFFOLD_283_SHA:?}"
: "${COMMON_283_SHA:?}"
: "${GOOD_FIRST_PARENT_SHA:?}"
: "${COMMON_305_MERGE_SHA:?}"
: "${DIRECT_305_REFERENCE_SHA:?}"
: "${STABLE_291_SHA:?}"
: "${STABLE_305_SHA:?}"
: "${FDT_292_SHA:?}"
: "${TARGET_BRANCH:?}"

EVIDENCE="${GITHUB_WORKSPACE}/source-generation-evidence"
mkdir -p "${EVIDENCE}"
trigger_sha="$(git rev-parse HEAD)"

test "$(git ls-remote origin refs/heads/miru-h40 | awk '{print $1}')" = "${PRODUCTION_SHA}"
test -z "$(git ls-remote origin "refs/heads/${TARGET_BRANCH}")"

git fetch --no-tags origin \
  "${PRODUCTION_SHA}" "${SCAFFOLD_283_SHA}" "${COMMON_283_SHA}" \
  "${GOOD_FIRST_PARENT_SHA}" "${COMMON_305_MERGE_SHA}" \
  "${DIRECT_305_REFERENCE_SHA}"
if ! git remote get-url android-common >/dev/null 2>&1; then
  git remote add android-common https://github.com/aosp-mirror/kernel_common.git
fi
git fetch --no-tags android-common \
  "${STABLE_291_SHA}" "${STABLE_305_SHA}" "${FDT_292_SHA}"

# Immutable provenance and pre-FDT boundary gates.
test "$(git rev-parse "${SCAFFOLD_283_SHA}^1")" = "${PRODUCTION_SHA}"
test "$(git rev-parse "${SCAFFOLD_283_SHA}^2")" = "${COMMON_283_SHA}"
test "$(git rev-parse "${COMMON_305_MERGE_SHA}^2")" = "${STABLE_305_SHA}"
git merge-base --is-ancestor "${PRODUCTION_SHA}" "${SCAFFOLD_283_SHA}"
git merge-base --is-ancestor "${COMMON_305_MERGE_SHA}" "${DIRECT_305_REFERENCE_SHA}"
git merge-base --is-ancestor "${STABLE_291_SHA}" "${STABLE_305_SHA}"
git merge-base --is-ancestor "${STABLE_291_SHA}" "${FDT_292_SHA}"
! git merge-base --is-ancestor "${FDT_292_SHA}" "${STABLE_291_SHA}"
test "$(git show -s --format=%s "${STABLE_291_SHA}")" = 'Linux 4.14.291'
test "$(git show "${STABLE_291_SHA}:Makefile" | sed -n 's/^SUBLEVEL = //p' | head -n1)" = 291
test "$(git rev-list --count "${STABLE_291_SHA}" --not b8f3be299d5176348b15cc59d55b85faa3dece68)" = 874

common_wt="${RUNNER_TEMP}/common-291"
common_ref_wt="${RUNNER_TEMP}/common-305-downgraded"
direct_ref_wt="${RUNNER_TEMP}/miru-305-downgraded"
source_wt="${RUNNER_TEMP}/miru-291"
rm -rf "${common_wt}" "${common_ref_wt}" "${direct_ref_wt}" "${source_wt}"

# Reconstruct the exact Android Common 4.14.291 semantic merge.
git worktree add --detach "${common_wt}" "${GOOD_FIRST_PARENT_SHA}"
git -C "${common_wt}" config user.name github-actions[bot]
git -C "${common_wt}" config user.email 41898282+github-actions[bot]@users.noreply.github.com
set +e
git -C "${common_wt}" merge --no-commit --no-ff "${STABLE_291_SHA}" \
  > "${EVIDENCE}/common-291-merge.log" 2>&1
common_rc=$?
set -e
test "${common_rc}" = 1
git -C "${common_wt}" diff --name-only --diff-filter=U | sort -u \
  > "${EVIDENCE}/common-291-conflicts.txt"
cat > "${EVIDENCE}/expected-common-291-conflicts.txt" <<'EOF'
crypto/chacha20_generic.c
drivers/char/random.c
drivers/nfc/st21nfca/se.c
drivers/of/fdt.c
fs/ext4/namei.c
include/crypto/chacha20.h
lib/chacha20.c
EOF
diff -u "${EVIDENCE}/expected-common-291-conflicts.txt" \
  "${EVIDENCE}/common-291-conflicts.txt"
mapfile -t common_conflicts < "${EVIDENCE}/common-291-conflicts.txt"

git worktree add --detach "${common_ref_wt}" "${COMMON_305_MERGE_SHA}"
git diff --binary --full-index "${STABLE_305_SHA}" "${STABLE_291_SHA}" -- \
  "${common_conflicts[@]}" > "${EVIDENCE}/common-305-to-291.patch"
sha256sum "${EVIDENCE}/common-305-to-291.patch" \
  > "${EVIDENCE}/common-305-to-291.patch.sha256"
git -C "${common_ref_wt}" apply --3way --index \
  "${EVIDENCE}/common-305-to-291.patch" \
  > "${EVIDENCE}/common-downgrade-apply.log" 2>&1
test -z "$(git -C "${common_ref_wt}" diff --name-only --diff-filter=U)"
test -z "$(git -C "${common_ref_wt}" ls-files -u)"

for rel in "${common_conflicts[@]}"; do
  if [ -e "${common_ref_wt}/${rel}" ] || [ -L "${common_ref_wt}/${rel}" ]; then
    mkdir -p "$(dirname "${common_wt}/${rel}")"
    rm -rf "${common_wt:?}/${rel}"
    cp -a "${common_ref_wt}/${rel}" "${common_wt}/${rel}"
    git -C "${common_wt}" add -- "${rel}"
  else
    git -C "${common_wt}" rm -f --ignore-unmatch -- "${rel}"
  fi
done
test -z "$(git -C "${common_wt}" ls-files -u)"
test "$(sed -n 's/^SUBLEVEL = //p' "${common_wt}/Makefile" | head -n1)" = 291
export GIT_AUTHOR_DATE='2026-07-31T07:50:00Z'
export GIT_COMMITTER_DATE='2026-07-31T07:50:00Z'
git -C "${common_wt}" commit -m 'Merge Linux 4.14.291 stable endpoint for Miru diagnostic'
common_291_sha="$(git -C "${common_wt}" rev-parse HEAD)"
test "$(git -C "${common_wt}" rev-parse 'HEAD^1')" = "${GOOD_FIRST_PARENT_SHA}"
test "$(git -C "${common_wt}" rev-parse 'HEAD^2')" = "${STABLE_291_SHA}"

# Downgrade the audited Miru 4.14.305 conflict-resolution files to 4.14.291.
miru_nodrift_paths=(drivers/char/Kconfig lib/Makefile)
miru_drift_paths=(drivers/usb/host/xhci.c drivers/usb/host/xhci.h net/ipv4/tcp_output.c)
miru_paths=("${miru_nodrift_paths[@]}" "${miru_drift_paths[@]}")
git diff --name-only "${STABLE_291_SHA}" "${STABLE_305_SHA}" -- \
  "${miru_nodrift_paths[@]}" > "${EVIDENCE}/post-291-nodrift-check.txt"
test ! -s "${EVIDENCE}/post-291-nodrift-check.txt"
git diff --name-only "${STABLE_291_SHA}" "${STABLE_305_SHA}" -- \
  "${miru_drift_paths[@]}" | sort -u > "${EVIDENCE}/post-291-miru-drift.txt"
cat > "${EVIDENCE}/expected-post-291-miru-drift.txt" <<'EOF'
drivers/usb/host/xhci.c
drivers/usb/host/xhci.h
net/ipv4/tcp_output.c
EOF
diff -u "${EVIDENCE}/expected-post-291-miru-drift.txt" \
  "${EVIDENCE}/post-291-miru-drift.txt"

git worktree add --detach "${direct_ref_wt}" "${DIRECT_305_REFERENCE_SHA}"
git diff --binary --full-index "${STABLE_305_SHA}" "${STABLE_291_SHA}" -- \
  "${miru_drift_paths[@]}" > "${EVIDENCE}/miru-305-to-291.patch"
sha256sum "${EVIDENCE}/miru-305-to-291.patch" \
  > "${EVIDENCE}/miru-305-to-291.patch.sha256"
set +e
git -C "${direct_ref_wt}" apply --3way --index \
  "${EVIDENCE}/miru-305-to-291.patch" \
  > "${EVIDENCE}/miru-downgrade-apply.log" 2>&1
miru_downgrade_rc=$?
set -e
test "${miru_downgrade_rc}" = 1
git -C "${direct_ref_wt}" diff --name-only --diff-filter=U | sort -u \
  > "${EVIDENCE}/miru-downgrade-conflicts.txt"
printf '%s\n' drivers/usb/host/xhci.h \
  > "${EVIDENCE}/expected-miru-downgrade-conflicts.txt"
diff -u "${EVIDENCE}/expected-miru-downgrade-conflicts.txt" \
  "${EVIDENCE}/miru-downgrade-conflicts.txt"

# Exact semantic resolution: stable 4.14.292+ added run_graceperiod. Remove only
# that field while retaining the audited Miru xHCI extensions and layout.
git -C "${direct_ref_wt}" checkout --ours -- drivers/usb/host/xhci.h
python3 - "${direct_ref_wt}/drivers/usb/host/xhci.h" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
needle = "\tunsigned long\t\trun_graceperiod;\n"
if text.count(needle) != 1:
    raise SystemExit(f"expected exactly one run_graceperiod field, found {text.count(needle)}")
path.write_text(text.replace(needle, "", 1))
PY
git -C "${direct_ref_wt}" add -- drivers/usb/host/xhci.h
test -z "$(git -C "${direct_ref_wt}" diff --name-only --diff-filter=U)"
test -z "$(git -C "${direct_ref_wt}" ls-files -u)"
! grep -Fq 'run_graceperiod' "${direct_ref_wt}/drivers/usb/host/xhci.h"
! grep -Fq 'run_graceperiod' "${direct_ref_wt}/drivers/usb/host/xhci.c"

# Merge the stable endpoint into the proven physical 4.14.283 scaffold.
git worktree add --detach "${source_wt}" "${SCAFFOLD_283_SHA}"
git -C "${source_wt}" config user.name github-actions[bot]
git -C "${source_wt}" config user.email 41898282+github-actions[bot]@users.noreply.github.com
set +e
git -C "${source_wt}" merge --no-commit --no-ff "${STABLE_291_SHA}" \
  > "${EVIDENCE}/miru-283-to-291-merge.log" 2>&1
source_rc=$?
set -e
test "${source_rc}" = 1
git -C "${source_wt}" diff --name-only --diff-filter=U | sort -u \
  > "${EVIDENCE}/miru-291-conflicts.txt"
cat > "${EVIDENCE}/expected-miru-291-conflicts.txt" <<'EOF'
crypto/chacha20_generic.c
drivers/char/Kconfig
drivers/char/random.c
drivers/of/fdt.c
drivers/usb/host/xhci.c
drivers/usb/host/xhci.h
fs/ext4/namei.c
include/crypto/chacha20.h
lib/Makefile
lib/chacha20.c
net/ipv4/tcp_output.c
EOF
diff -u "${EVIDENCE}/expected-miru-291-conflicts.txt" \
  "${EVIDENCE}/miru-291-conflicts.txt"

for rel in crypto/chacha20_generic.c include/crypto/chacha20.h lib/chacha20.c; do
  git -C "${source_wt}" rm -f --ignore-unmatch -- "${rel}"
done
for rel in drivers/char/random.c drivers/of/fdt.c fs/ext4/namei.c; do
  mkdir -p "$(dirname "${source_wt}/${rel}")"
  rm -rf "${source_wt:?}/${rel}"
  cp -a "${common_wt}/${rel}" "${source_wt}/${rel}"
  git -C "${source_wt}" add -- "${rel}"
  test "$(git -C "${source_wt}" hash-object "${rel}")" = \
    "$(git -C "${common_wt}" hash-object "${rel}")"
done
for rel in "${miru_paths[@]}"; do
  mkdir -p "$(dirname "${source_wt}/${rel}")"
  rm -rf "${source_wt:?}/${rel}"
  cp -a "${direct_ref_wt}/${rel}" "${source_wt}/${rel}"
  git -C "${source_wt}" add -- "${rel}"
  test "$(git -C "${source_wt}" hash-object "${rel}")" = \
    "$(git -C "${direct_ref_wt}" hash-object "${rel}")"
done

test -z "$(git -C "${source_wt}" diff --name-only --diff-filter=U)"
test -z "$(git -C "${source_wt}" ls-files -u)"
git -C "${source_wt}" diff --check
test "$(sed -n 's/^SUBLEVEL = //p' "${source_wt}/Makefile" | head -n1)" = 291
test "$(git -C "${source_wt}" hash-object drivers/extcon/extcon.c)" = \
  117da8393690b281f87680bc4ea81b3984f1c24c
! grep -Fq '#include <linux/random.h>' "${source_wt}/drivers/soc/qcom/early_random.c"
grep -Fq 'void *dt_virt = fixmap_remap_fdt(dt_phys);' \
  "${source_wt}/arch/arm64/kernel/setup.c"
! grep -Fq 'fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL)' \
  "${source_wt}/arch/arm64/kernel/setup.c"
if git -C "${source_wt}" grep -nE '^(<<<<<<< .+|>>>>>>> .+)$' -- . \
    ':!Documentation' > "${EVIDENCE}/source-conflict-markers.txt"; then
  cat "${EVIDENCE}/source-conflict-markers.txt" >&2
  exit 1
fi

export GIT_AUTHOR_DATE='2026-07-31T08:20:00Z'
export GIT_COMMITTER_DATE='2026-07-31T08:20:00Z'
git -C "${source_wt}" commit \
  -m 'Merge complete Linux 4.14.291 after proven 4.14.283 diagnostic'
source_sha="$(git -C "${source_wt}" rev-parse HEAD)"
source_tree="$(git -C "${source_wt}" rev-parse 'HEAD^{tree}')"
test "$(git -C "${source_wt}" rev-parse 'HEAD^1')" = "${SCAFFOLD_283_SHA}"
test "$(git -C "${source_wt}" rev-parse 'HEAD^2')" = "${STABLE_291_SHA}"
git -C "${source_wt}" merge-base --is-ancestor "${PRODUCTION_SHA}" HEAD
git -C "${source_wt}" merge-base --is-ancestor "${STABLE_291_SHA}" HEAD
! git -C "${source_wt}" merge-base --is-ancestor "${FDT_292_SHA}" HEAD

git -C "${source_wt}" ls-tree -r HEAD > "${EVIDENCE}/final-source-tree.txt"
git -C "${source_wt}" diff --stat "${SCAFFOLD_283_SHA}" HEAD \
  > "${EVIDENCE}/scaffold-to-source.stat"
{
  echo result=PASS
  echo "trigger_sha=${trigger_sha}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "proven_283_scaffold=${SCAFFOLD_283_SHA}"
  echo "stable_291_sha=${STABLE_291_SHA}"
  echo "excluded_fdt_292_sha=${FDT_292_SHA}"
  echo "common_291_merge_sha=${common_291_sha}"
  echo "source_sha=${source_sha}"
  echo "source_tree=${source_tree}"
  echo source_sublevel=291
  echo source_extcon_blob=117da8393690b281f87680bc4ea81b3984f1c24c
  echo early_random_include=absent_requires_compatibility_repair
  echo unresolved_conflicts=0
  echo miru_conflict_count=11
  echo common_conflict_count=7
  echo post_291_miru_drift_count=3
  echo xhci_header_resolution=remove_only_run_graceperiod
} | tee "${EVIDENCE}/SOURCE-SUMMARY.txt"
find "${EVIDENCE}" -maxdepth 1 -type f ! -name SHA256SUMS.txt -print0 \
  | sort -z | xargs -0 sha256sum > "${EVIDENCE}/SHA256SUMS.txt"

test "$(git ls-remote origin refs/heads/miru-h40 | awk '{print $1}')" = "${PRODUCTION_SHA}"
test -z "$(git ls-remote origin "refs/heads/${TARGET_BRANCH}")"
git -C "${source_wt}" push origin "${source_sha}:refs/heads/${TARGET_BRANCH}"
test "$(git ls-remote origin "refs/heads/${TARGET_BRANCH}" | awk '{print $1}')" = "${source_sha}"
