#!/usr/bin/env bash
set -Eeuo pipefail

OUT=diag29-probe
mkdir -p "${OUT}"
exec > >(tee "${OUT}/probe.log") 2>&1
set -x

PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
SOURCE_291_SHA=a79859d15ae0025897791a77654bcebeedc708ab
STABLE_291_SHA=e548869f356fead9fdcb3562f52d2226574f4f41
STABLE_292_SHA=65640c873dcf9c9736c071807b371c487bc6377f
FDT_292_SHA=3c2ae48eceaa40f1ecb18ba31dda3f6fe755796c

{
  echo "launch_head=$(git rev-parse HEAD)"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "source_291=${SOURCE_291_SHA}"
  echo "stable_291=${STABLE_291_SHA}"
  echo "stable_292=${STABLE_292_SHA}"
  echo "fdt_292=${FDT_292_SHA}"
} | tee "${OUT}/inputs.txt"

test "$(git ls-remote origin refs/heads/miru-h40 | awk '{print $1}')" = "${PRODUCTION_SHA}"
git fetch --no-tags origin "${PRODUCTION_SHA}" "${SOURCE_291_SHA}" "${STABLE_291_SHA}" "${STABLE_292_SHA}" "${FDT_292_SHA}"
git merge-base --is-ancestor "${PRODUCTION_SHA}" HEAD
git merge-base --is-ancestor "${SOURCE_291_SHA}" HEAD
git merge-base --is-ancestor "${STABLE_291_SHA}" HEAD
! git merge-base --is-ancestor "${STABLE_292_SHA}" HEAD
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 291

git config user.name github-actions[bot]
git config user.email 41898282+github-actions[bot]@users.noreply.github.com

set +e
git merge --no-ff --no-commit "${STABLE_292_SHA}"
merge_rc=$?
set -e

echo "merge_rc=${merge_rc}" | tee "${OUT}/merge-result.txt"
git diff --name-only --diff-filter=U | sort -u | tee "${OUT}/conflicts.txt"
git ls-files -u | tee "${OUT}/unmerged-index.txt"
git status --short | tee "${OUT}/status.txt"

while IFS= read -r path; do
  [ -n "${path}" ] || continue
  safe="${path//\//__}"
  git diff --cc -- "${path}" > "${OUT}/conflict-${safe}.diff" || true
  {
    echo "=== ${path} ==="
    git ls-files -u -- "${path}"
  } >> "${OUT}/conflict-summary.txt"
done < "${OUT}/conflicts.txt"

conflict_count="$(wc -l < "${OUT}/conflicts.txt")"
{
  echo "probe_result=COMPLETE"
  echo "merge_rc=${merge_rc}"
  echo "conflict_count=${conflict_count}"
  echo "conflicts=$(paste -sd, "${OUT}/conflicts.txt")"
} | tee "${OUT}/SUMMARY.txt"

# This is a source probe only. Always leave the job successful so logs and the
# exact conflict evidence remain available through the PR workflow API.
exit 0
