#!/usr/bin/env bash
set -Eeuo pipefail

LINEAGE_MERGE=9be6616473e5ecc83915ba3390d4c6751b1c4876
OPENELA_TARGET=1e6347375d088ecc896aabb067131d0f9e3c0575

lineage_parents="$(git rev-list --parents -n 1 "${LINEAGE_MERGE}")"
read -r merge parent1 parent2 extra <<<"${lineage_parents}"
test "${merge}" = "${LINEAGE_MERGE}"
test -n "${parent1}"
test -n "${parent2}"
test -z "${extra:-}"
test "${parent2}" = "${OPENELA_TARGET}"

{
  echo "lineage_merge=${LINEAGE_MERGE}"
  echo "lineage_parent_1=${parent1}"
  echo "lineage_parent_2=${parent2}"
} | tee audit/LINEAGE-PARENTS.txt

for path_file in audit/stage-*/files/*/path.txt; do
  [ -f "${path_file}" ] || continue
  bundle="$(dirname "${path_file}")"
  path="$(cat "${path_file}")"
  git diff --binary "${parent1}" "${LINEAGE_MERGE}" -- "${path}" \
    > "${bundle}/05-lineage-openela-merge.delta" || true
  git diff --numstat "${parent1}" "${LINEAGE_MERGE}" -- "${path}" \
    > "${bundle}/05-lineage-openela-merge.numstat" || true
  git diff --check "${parent1}" "${LINEAGE_MERGE}" -- "${path}" \
    > "${bundle}/05-lineage-openela-merge.check" || true

done

{
  echo
  echo "## LineageOS merge parents"
  echo
  echo "- first parent: \`${parent1}\`"
  echo "- second parent: \`${parent2}\` (exact OpenELA 4.14.357 target)"
  echo "- per-conflict first-parent merge deltas: \`05-lineage-openela-merge.delta\`"
} >> audit/README.md
