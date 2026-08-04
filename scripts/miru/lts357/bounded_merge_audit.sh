#!/usr/bin/env bash
set -Eeuo pipefail

IMMUTABLE_PRODUCTION=eb9451c0a1639e1aa49ee094681f98df0545f797
OPENELA_BASE=c31e35278ea8f04f1dceadd77dca4dd7d47932a3
OPENELA_340=9b7ef2749ffa187d86acd0033327338c0fc299bf
OPENELA_344=7a22fc46cc7a72d72b6dfdcbbc46e18c9f2caab0
OPENELA_348=ef4cb0aa8addc73e6257039a17061cb1766b7477
OPENELA_352=6da009d8de389742d55219ebed50378f53937a5b
OPENELA_356=a76b6a6556353484f6f29572989cd37b6cff90cc
OPENELA_357=1e6347375d088ecc896aabb067131d0f9e3c0575
LINEAGE_MERGE=9be6616473e5ecc83915ba3390d4c6751b1c4876
MODULES_SHA=3216c08bb3f97f865eb055296ea8034e1744caef
MODULES_BRANCH=oneplus/sm8150_s_12.1_op7pro

repo="${GITHUB_REPOSITORY:-KAI-Miru/android_kernel_oneplus_sm8150}"
branch="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-miru-h40-lts357-integration}}"
test "${branch}" = miru-h40-lts357-integration

git merge-base --is-ancestor "${IMMUTABLE_PRODUCTION}" HEAD
live_production="$(git ls-remote "https://github.com/${repo}.git" refs/heads/miru-h40 | awk 'NR==1{print $1}')"
test "${live_production}" = "${IMMUTABLE_PRODUCTION}"
live_modules="$(git ls-remote https://github.com/KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150.git "refs/heads/${MODULES_BRANCH}" | awk 'NR==1{print $1}')"
test "${live_modules}" = "${MODULES_SHA}"

if ! git remote get-url openela >/dev/null 2>&1; then
  git remote add openela https://github.com/openela/kernel-lts.git
fi
if ! git remote get-url lineage >/dev/null 2>&1; then
  git remote add lineage https://github.com/LineageOS/android_kernel_oneplus_sm8150.git
fi
git fetch --no-tags openela \
  "${OPENELA_BASE}" "${OPENELA_340}" "${OPENELA_344}" \
  "${OPENELA_348}" "${OPENELA_352}" "${OPENELA_356}" "${OPENELA_357}"
git fetch --no-tags lineage "${LINEAGE_MERGE}"

for pair in \
  "${OPENELA_BASE}:${OPENELA_340}" \
  "${OPENELA_340}:${OPENELA_344}" \
  "${OPENELA_344}:${OPENELA_348}" \
  "${OPENELA_348}:${OPENELA_352}" \
  "${OPENELA_352}:${OPENELA_356}" \
  "${OPENELA_356}:${OPENELA_357}"; do
  base="${pair%%:*}"
  head="${pair##*:}"
  git merge-base --is-ancestor "${base}" "${head}"
done

test "$(git show "${OPENELA_357}":Makefile | sed -n 's/^SUBLEVEL = //p' | head -n1)" = 357
test "$(git show "${OPENELA_357}":.elts/config.yaml | sed -n 's/^version: //p')" = 4.14.357
test "$(git show "${OPENELA_357}":.elts/config.yaml | sed -n 's/^base: //p')" = 4.14.336
test "$(git show "${OPENELA_357}":.elts/config.yaml | sed -n 's/^upstream_version: //p')" = 4.19.323

git config user.name 'Miru H.40 Integration Bot'
git config user.email '110590275+KAI-Miru@users.noreply.github.com'
rm -rf audit
mkdir -p audit
cat > audit/README.md <<EOF
# Miru H.40 OpenELA 4.14.357 bounded merge audit

- immutable production: \`${IMMUTABLE_PRODUCTION}\`
- OpenELA baseline: \`${OPENELA_BASE}\`
- OpenELA target: \`${OPENELA_357}\`
- LineageOS reference: \`${LINEAGE_MERGE}\`
- external modules: \`${MODULES_SHA}\`
EOF

stages=(
  "340:${OPENELA_340}:4.14.336..4.14.340"
  "344:${OPENELA_344}:4.14.340..4.14.344"
  "348:${OPENELA_348}:4.14.344..4.14.348"
  "352:${OPENELA_352}:4.14.348..4.14.352"
  "356:${OPENELA_356}:4.14.352..4.14.356"
  "357:${OPENELA_357}:4.14.356..4.14.357"
)

total=0
for spec in "${stages[@]}"; do
  label="${spec%%:*}"
  rest="${spec#*:}"
  target="${rest%%:*}"
  range="${rest#*:}"
  dir="audit/stage-${label}"
  mkdir -p "${dir}/files"
  parent="$(git rev-parse HEAD)"
  set +e
  git merge --no-ff --no-commit "${target}" >"${dir}/merge.stdout" 2>"${dir}/merge.stderr"
  rc=$?
  set -e
  git diff --name-only --diff-filter=U | sort > "${dir}/conflicts.txt"
  count="$(wc -l < "${dir}/conflicts.txt")"
  total=$((total + count))
  {
    echo "# Stage ${range}"
    echo
    echo "- Miru parent: \`${parent}\`"
    echo "- OpenELA parent: \`${target}\`"
    echo "- merge return code: \`${rc}\`"
    echo "- textual conflicts: \`${count}\`"
    echo
    echo '## Conflict files'
    sed 's/^/- `/' "${dir}/conflicts.txt" | sed 's/$/`/'
  } > "${dir}/SUMMARY.md"

  while IFS= read -r path; do
    [ -n "${path}" ] || continue
    safe="$(printf '%s' "${path}" | sha256sum | cut -c1-16)"
    bundle="${dir}/files/${safe}"
    mkdir -p "${bundle}"
    printf '%s\n' "${path}" > "${bundle}/path.txt"
    git show ":1:${path}" > "${bundle}/01-merge-base" 2>/dev/null || true
    git show ":2:${path}" > "${bundle}/02-miru" 2>/dev/null || true
    git show ":3:${path}" > "${bundle}/03-openela" 2>/dev/null || true
    git show "${LINEAGE_MERGE}:${path}" > "${bundle}/04-lineage" 2>/dev/null || true
    git diff --no-index -- "${bundle}/01-merge-base" "${bundle}/03-openela" > "${bundle}/openela-intent.diff" || true
    git diff --no-index -- "${bundle}/02-miru" "${bundle}/04-lineage" > "${bundle}/miru-vs-lineage.diff" || true

    case "${path}" in
      .elts/*)
        git checkout --theirs -- "${path}"
        ;;
      Makefile)
        git checkout --ours -- "${path}"
        sed -i -E "s/^SUBLEVEL = .*/SUBLEVEL = ${label}/; s/^EXTRAVERSION =.*/EXTRAVERSION =/" "${path}"
        ;;
      *)
        if git cat-file -e "${LINEAGE_MERGE}:${path}" 2>/dev/null; then
          git show "${LINEAGE_MERGE}:${path}" > "${path}"
        else
          git checkout --ours -- "${path}"
        fi
        ;;
    esac
  done < "${dir}/conflicts.txt"

  # Stage every resolved conflict and every clean merge change, including
  # paths deleted by OpenELA. This is a temporary in-run scaffold only.
  git add -A
  test -z "$(git diff --name-only --diff-filter=U)"
  git commit -m "audit scaffold: merge OpenELA ${range}" \
    -m 'Temporary in-run scaffold only; not pushed. Conflict files use LineageOS final blobs solely to expose subsequent-stage conflicts.'
  merge="$(git rev-parse HEAD)"
  git rev-list --parents -n1 HEAD > "${dir}/merge-parents.txt"
  echo "- scaffold merge: \`${merge}\`" >> "${dir}/SUMMARY.md"
  echo >> audit/README.md
  echo "- ${range}: ${count} conflicts; scaffold merge \`${merge}\`" >> audit/README.md
done

echo "total_initial_conflicts=${total}" | tee audit/TOTALS.txt
git status --short > audit/final-status.txt
git log --graph --oneline --decorate -n 30 > audit/scaffold-history.txt
