#!/usr/bin/env bash
set -Eeuo pipefail

: "${EXPECTED_HEAD:?EXPECTED_HEAD is required}"
: "${IMMUTABLE_PRODUCTION:?IMMUTABLE_PRODUCTION is required}"
: "${STAGE356_MERGE:?STAGE356_MERGE is required}"
: "${OPENELA_BASE:?OPENELA_BASE is required}"
: "${OPENELA_356:?OPENELA_356 is required}"
: "${OPENELA_357:?OPENELA_357 is required}"
: "${MODULES_BRANCH:?MODULES_BRANCH is required}"
: "${MODULES_SHA:?MODULES_SHA is required}"
: "${FORBIDDEN_MODULES_SHA:?FORBIDDEN_MODULES_SHA is required}"
: "${DWC3_REPAIR:?DWC3_REPAIR is required}"

evidence="${RUNNER_TEMP}/stage-357-executor"
mkdir -p "${evidence}"
step() {
  printf '%s\n' "$1" | tee "${evidence}/LAST_STEP.txt"
}
trap 'rc=$?; git status --porcelain=v1 > "${evidence}/status-at-exit.txt" 2>/dev/null || true; printf "exit_code=%s\nproduction_write=NONE\n" "${rc}" > "${evidence}/EXIT.txt"; exit "${rc}"' EXIT

step verify-immutable-boundaries
test "$(git rev-parse HEAD)" = "${EXPECTED_HEAD}"
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40-lts357-integration | awk 'NR==1{print $1}')" = "${EXPECTED_HEAD}"
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40 | awk 'NR==1{print $1}')" = "${IMMUTABLE_PRODUCTION}"
live_modules="$(git ls-remote https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git refs/heads/${MODULES_BRANCH} | awk 'NR==1{print $1}')"
test "${live_modules}" = "${MODULES_SHA}"
test "${live_modules}" != "${FORBIDDEN_MODULES_SHA}"
git merge-base --is-ancestor "${STAGE356_MERGE}" HEAD
git merge-base --is-ancestor "${DWC3_REPAIR}" HEAD

step fetch-and-verify-openela357
git config user.name 'Miru H.40 OpenELA Integration'
git config user.email '110590275+KAI-Miru@users.noreply.github.com'
git remote add openela https://github.com/openela/kernel-lts.git
git fetch --no-tags openela "${OPENELA_BASE}" "${OPENELA_356}" "${OPENELA_357}" refs/tags/v4.14.357-openela:refs/tags/v4.14.357-openela
test "$(git rev-parse "${OPENELA_357}^{commit}")" = "${OPENELA_357}"
test "$(git rev-parse 'refs/tags/v4.14.357-openela^{commit}')" = "${OPENELA_357}"
git merge-base --is-ancestor "${OPENELA_BASE}" "${OPENELA_356}"
git merge-base --is-ancestor "${OPENELA_356}" "${OPENELA_357}"
test "$(git show ${OPENELA_357}:Makefile | sed -n 's/^SUBLEVEL = //p' | head -n1)" = 357
test "$(git show ${OPENELA_357}:.elts/config.yaml | sed -n 's/^version: //p')" = 4.14.357
test "$(git show ${OPENELA_357}:.elts/config.yaml | sed -n 's/^base: //p')" = 4.14.336

if git merge-base --is-ancestor "${OPENELA_357}" HEAD; then
  step already-complete
  stage357_merge="$(git rev-list --parents HEAD | awk -v target="${OPENELA_357}" 'NF == 3 && $3 == target {print $1; exit}')"
  test -n "${stage357_merge}"
  {
    echo result=ALREADY_COMPLETE
    echo "stage357_merge=${stage357_merge}"
    echo "current_head=${EXPECTED_HEAD}"
    echo "openela_second_parent=${OPENELA_357}"
    echo "modules_sha=${MODULES_SHA}"
    echo production_write=NONE
    echo exit_code=0
  } | tee "${evidence}/SUMMARY.txt"
  exit 0
fi

step verify-single-purpose-executor-commit
test "$(git rev-parse HEAD^)" = "${PRE_EXECUTOR_HEAD}"
test "$(git diff-tree --no-commit-id --name-only -r HEAD)" = '.github/workflows/miru-lts357-stage357-executor.yml'

cat > "${evidence}/expected-merge-paths.txt" <<'EOF'
.elts/config.yaml
Makefile
drivers/clk/clk-devres.c
fs/ocfs2/quota_global.c
fs/ocfs2/quota_local.c
include/linux/skbuff.h
net/core/sock_destructor.h
net/ipv4/inet_fragment.c
net/ipv4/ip_fragment.c
net/ipv6/netfilter/nf_conntrack_reasm.c
security/integrity/ima/ima_api.c
security/integrity/ima/ima_template_lib.c
EOF

step merge-openela357-no-commit
set +e
git merge --no-ff --no-commit "${OPENELA_357}" > "${evidence}/merge.stdout" 2> "${evidence}/merge.stderr"
merge_rc=$?
set -e
test "${merge_rc}" = 0
git diff --name-only --diff-filter=U | sort > "${evidence}/initial-conflicts.txt"
test ! -s "${evidence}/initial-conflicts.txt"
git diff --cached --name-only | sort > "${evidence}/actual-merge-paths.txt"
diff -u "${evidence}/expected-merge-paths.txt" "${evidence}/actual-merge-paths.txt"

step record-clean-stage357-ledger
cat >> Documentation/miru/lts-4.14.357-conflicts.md <<'EOF'

## Stage 6 — 4.14.356 to 4.14.357

OpenELA parent: `1e6347375d088ecc896aabb067131d0f9e3c0575`

The exact guarded dry merge at source `4be40f4c3db1bc53fe0e75622d2132e00ca56989`
completed with exit code 0, twelve expected merge paths, zero metadata conflicts,
zero source conflicts and zero remaining unmerged entries. No manual source
resolution was required.

The stage checkpoint compiles direct consumers for the clock, OCFS2 quota,
SKB/socket destructor, IPv4/IPv6 fragment-reassembly and IMA changes, plus all
cumulative Miru H.40 regression targets from stages 352 and 356.
EOF
git add Documentation/miru/lts-4.14.357-conflicts.md

step stage-and-scan-clean-merge
git diff --name-only --diff-filter=U > "${evidence}/remaining-unmerged.txt"
git ls-files -u > "${evidence}/remaining-index-stages.txt"
test ! -s "${evidence}/remaining-unmerged.txt"
test ! -s "${evidence}/remaining-index-stages.txt"
git diff --cached --stat > "${evidence}/staged-stat.txt"
git diff --cached --check -- \
  Makefile drivers/clk/clk-devres.c fs/ocfs2/quota_global.c fs/ocfs2/quota_local.c \
  include/linux/skbuff.h net/core/sock_destructor.h net/ipv4/inet_fragment.c \
  net/ipv4/ip_fragment.c net/ipv6/netfilter/nf_conntrack_reasm.c \
  security/integrity/ima/ima_api.c security/integrity/ima/ima_template_lib.c \
  Documentation/miru/lts-4.14.357-conflicts.md \
  > "${evidence}/staged-check.txt"
: > "${evidence}/conflict-marker-scan.txt"
while IFS= read -r path; do
  grep -nE '^(<<<<<<<|\|\|\|\|\|\|\||=======|>>>>>>>)' "${path}" >> "${evidence}/conflict-marker-scan.txt" || true
done < "${evidence}/expected-merge-paths.txt"
test ! -s "${evidence}/conflict-marker-scan.txt"
find . -path './.git' -prune -o -type f \
  \( -name '*.orig' -o -name '*.rej' -o -name '*.pyc' \) -print \
  > "${evidence}/temporary-files.txt"
test ! -s "${evidence}/temporary-files.txt"

step create-and-verify-genuine-merge
git commit \
  -m 'Merge OpenELA eLTS Linux 4.14.357 into Miru H.40' \
  -m 'Second parent: 1e6347375d088ecc896aabb067131d0f9e3c0575' \
  -m 'The exact audited cumulative merge is conflict-free; compile the changed clock, quota, networking and IMA paths with cumulative Miru regression coverage.'
stage357_merge="$(git rev-parse HEAD)"
parents="$(git rev-list --parents -n1 "${stage357_merge}")"
test "$(printf '%s\n' "${parents}" | awk '{print NF-1}')" = 2
test "$(printf '%s\n' "${parents}" | awk '{print $2}')" = "${EXPECTED_HEAD}"
test "$(printf '%s\n' "${parents}" | awk '{print $3}')" = "${OPENELA_357}"
git merge-base --is-ancestor "${STAGE356_MERGE}" "${stage357_merge}"
git merge-base --is-ancestor "${DWC3_REPAIR}" "${stage357_merge}"
git status --porcelain=v1 > "${evidence}/status-after-merge-commit.txt"
test ! -s "${evidence}/status-after-merge-commit.txt"

step compile-stage357-checkpoint
STAGE357_MERGE="${stage357_merge}" EXPECTED_REMOTE_HEAD="${EXPECTED_HEAD}" \
  bash scripts/miru/lts357/run_compile_checkpoint_357.sh

step guarded-integration-push
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40 | awk 'NR==1{print $1}')" = "${IMMUTABLE_PRODUCTION}"
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40-lts357-integration | awk 'NR==1{print $1}')" = "${EXPECTED_HEAD}"
git push \
  --force-with-lease=refs/heads/miru-h40-lts357-integration:${EXPECTED_HEAD} \
  origin HEAD:refs/heads/miru-h40-lts357-integration
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40-lts357-integration | awk 'NR==1{print $1}')" = "${stage357_merge}"
test "$(git ls-remote https://github.com/${GITHUB_REPOSITORY}.git refs/heads/miru-h40 | awk 'NR==1{print $1}')" = "${IMMUTABLE_PRODUCTION}"

step complete
{
  echo result=PASS
  echo "pre_merge_head=${EXPECTED_HEAD}"
  echo "stage357_merge=${stage357_merge}"
  echo "openela_second_parent=${OPENELA_357}"
  echo conflict_count=0
  echo merge_path_count=12
  echo "modules_sha=${MODULES_SHA}"
  echo kernel_release=4.14.357-openela-miru-h40-lts357-stage6+
  echo production_write=NONE
  echo exit_code=0
} | tee "${evidence}/SUMMARY.txt"
