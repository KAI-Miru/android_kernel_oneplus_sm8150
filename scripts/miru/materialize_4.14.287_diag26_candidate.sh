#!/usr/bin/env bash
set -Eeuo pipefail
set -x

: "${PRODUCTION_SHA:?}"
: "${SOURCE_SHA:?}"
: "${SOURCE_BRANCH:?}"
: "${STABLE_287_SHA:?}"
: "${DIAG25_HEAD:?}"
: "${TARGET_BRANCH:?}"
: "${FIXED_EXTCON_BLOB:?}"
: "${EARLY_RANDOM_BLOB:?}"

EVIDENCE="${GITHUB_WORKSPACE}/candidate-287-evidence"
mkdir -p "${EVIDENCE}"
trigger_sha="$(git rev-parse HEAD)"

test "$(git ls-remote origin refs/heads/miru-h40 | awk '{print $1}')" = "${PRODUCTION_SHA}"
test "$(git ls-remote origin "refs/heads/${SOURCE_BRANCH}" | awk '{print $1}')" = "${SOURCE_SHA}"
test -z "$(git ls-remote origin "refs/heads/${TARGET_BRANCH}")"

git fetch --no-tags origin "${PRODUCTION_SHA}" "${SOURCE_SHA}" "${DIAG25_HEAD}"
if ! git remote get-url android-common >/dev/null 2>&1; then
  git remote add android-common https://github.com/aosp-mirror/kernel_common.git
fi
git fetch --no-tags android-common "${STABLE_287_SHA}"

test "$(git rev-parse "${SOURCE_SHA}^1")" = b581c659db87713eb2df1c29e4f28e337e5e908c
test "$(git rev-parse "${SOURCE_SHA}^2")" = "${STABLE_287_SHA}"
test "$(git show "${SOURCE_SHA}:Makefile" | sed -n 's/^SUBLEVEL = //p' | head -n1)" = 287

test "$(git show "${SOURCE_SHA}:drivers/extcon/extcon.c" | git hash-object --stdin)" = 117da8393690b281f87680bc4ea81b3984f1c24c
test "$(git show "${SOURCE_SHA}:drivers/soc/qcom/early_random.c" | git hash-object --stdin)" = 73fd17290964803ccfd2784cf27ec718ff3de23a
test "$(git show "${SOURCE_SHA}:lib/vsprintf.c" | git hash-object --stdin)" = ad1d198627f1c31e0e3135de8f2320a605a58a3f
test "$(git show "${SOURCE_SHA}:include/crypto/chacha.h" | git hash-object --stdin)" = 84a04c0845a4b0d14469583b1a7f4f62a3fd157d
test "$(git show "${SOURCE_SHA}:drivers/of/fdt.c" | git hash-object --stdin)" = 5e96a55f73b725d0aaf17c1343d380b723238645
test "$(git show "${SOURCE_SHA}:drivers/usb/host/xhci.c" | git hash-object --stdin)" = cc4b2d066f8180463562b9055a918c4a1c4fdd22
test "$(git show "${SOURCE_SHA}:drivers/usb/host/xhci.h" | git hash-object --stdin)" = 4e3554115e1b0aa804d0d36d14b8121d537f5570
test "$(git show "${SOURCE_SHA}:net/ipv4/tcp_output.c" | git hash-object --stdin)" = 4edb8f630035f2b1f12ecf498d13b6953573056c

test "$(git show "${DIAG25_HEAD}:drivers/extcon/extcon.c" | git hash-object --stdin)" = "${FIXED_EXTCON_BLOB}"
test "$(git show "${DIAG25_HEAD}:drivers/soc/qcom/early_random.c" | git hash-object --stdin)" = "${EARLY_RANDOM_BLOB}"

wt="${RUNNER_TEMP}/miru-287-diag26-candidate"
rm -rf "${wt}"
git worktree add --detach "${wt}" "${SOURCE_SHA}"
git -C "${wt}" config user.name github-actions[bot]
git -C "${wt}" config user.email 41898282+github-actions[bot]@users.noreply.github.com

git show "${DIAG25_HEAD}:drivers/extcon/extcon.c" > "${wt}/drivers/extcon/extcon.c"
git show "${DIAG25_HEAD}:drivers/soc/qcom/early_random.c" > "${wt}/drivers/soc/qcom/early_random.c"
git show "${DIAG25_HEAD}:.github/workflows/miru-h40-build.yml" > "${wt}/.github/workflows/miru-h40-build.yml"

python3 - "${wt}/.github/workflows/miru-h40-build.yml" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
repls = [
    ('a79859d15ae0025897791a77654bcebeedc708ab', '705dd8a9d1e74a896a28d1a3efd6ff30fcc4e3b4'),
    ('e548869f356fead9fdcb3562f52d2226574f4f41', '1048779a1d7dcf0b5c150188decafa21c19821e4'),
    ('STABLE_291_SHA', 'STABLE_287_SHA'),
    ('miru-h40-lts291-source-diag25', 'miru-h40-lts287-source-diag26'),
    ('4.14.291', '4.14.287'),
    ('full291', 'full287'),
    ('diag25', 'diag26'),
]
for old, new in repls:
    count = s.count(old)
    if count < 1:
        raise SystemExit(f'missing workflow token: {old}')
    s = s.replace(old, new)
for stale in ('a79859d15ae0025897791a77654bcebeedc708ab',
              'e548869f356fead9fdcb3562f52d2226574f4f41',
              'STABLE_291_SHA', 'miru-h40-lts291-source-diag25',
              '4.14.291', 'full291', 'diag25'):
    if stale in s:
        raise SystemExit(f'stale workflow token remains: {stale}')
required = (
    'SOURCE_SHA: 705dd8a9d1e74a896a28d1a3efd6ff30fcc4e3b4',
    'STABLE_287_SHA: 1048779a1d7dcf0b5c150188decafa21c19821e4',
    'EXPECTED_RELEASE: 4.14.287-miru-h40-diag26-full287-extconfix+',
    'miru-h40-4.14.287-diag26-full287-extconfix-kernel.zip',
    'export KERNEL_LOCALVERSION=-miru-h40-diag26-full287-extconfix',
)
for token in required:
    if token not in s:
        raise SystemExit(f'required workflow token missing: {token}')
p.write_text(s)
PY

git -C "${wt}" add -- .github/workflows/miru-h40-build.yml drivers/extcon/extcon.c drivers/soc/qcom/early_random.c
test -z "$(git -C "${wt}" ls-files -u)"
git -C "${wt}" diff --check --cached

git -C "${wt}" diff --name-only --cached | sort -u > "${EVIDENCE}/candidate-delta.txt"
printf '%s\n' \
  .github/workflows/miru-h40-build.yml \
  drivers/extcon/extcon.c \
  drivers/soc/qcom/early_random.c \
  > "${EVIDENCE}/expected-candidate-delta.txt"
cmp -s "${EVIDENCE}/expected-candidate-delta.txt" "${EVIDENCE}/candidate-delta.txt"

test "$(git -C "${wt}" hash-object drivers/extcon/extcon.c)" = "${FIXED_EXTCON_BLOB}"
test "$(git -C "${wt}" hash-object drivers/soc/qcom/early_random.c)" = "${EARLY_RANDOM_BLOB}"
grep -Fq '#include <linux/random.h>' "${wt}/drivers/soc/qcom/early_random.c"
grep -Fq 'edev->bnh = kcalloc(edev->max_supported, sizeof(*edev->bnh)' "${wt}/drivers/extcon/extcon.c"
grep -Fq 'EXPECTED_RELEASE: 4.14.287-miru-h40-diag26-full287-extconfix+' "${wt}/.github/workflows/miru-h40-build.yml"

export GIT_AUTHOR_DATE='2026-07-31T15:10:00Z'
export GIT_COMMITTER_DATE='2026-07-31T15:10:00Z'
git -C "${wt}" commit -m 'diag: build Linux 4.14.287 midpoint kernel only'
candidate_sha="$(git -C "${wt}" rev-parse HEAD)"
candidate_tree="$(git -C "${wt}" rev-parse HEAD^{tree})"
test "$(git -C "${wt}" rev-parse HEAD^1)" = "${SOURCE_SHA}"
git -C "${wt}" merge-base --is-ancestor "${PRODUCTION_SHA}" HEAD
git -C "${wt}" merge-base --is-ancestor "${STABLE_287_SHA}" HEAD

{
  echo result=PASS
  echo "trigger_sha=${trigger_sha}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "source_sha=${SOURCE_SHA}"
  echo "stable_287=${STABLE_287_SHA}"
  echo "diag25_reference=${DIAG25_HEAD}"
  echo "candidate_sha=${candidate_sha}"
  echo "candidate_tree=${candidate_tree}"
  echo "fixed_extcon_blob=${FIXED_EXTCON_BLOB}"
  echo "early_random_blob=${EARLY_RANDOM_BLOB}"
  echo candidate_delta_files=3
} | tee "${EVIDENCE}/SUMMARY.txt"
sha256sum "${EVIDENCE}"/* > "${EVIDENCE}/SHA256SUMS"

git -C "${wt}" push origin "HEAD:refs/heads/${TARGET_BRANCH}"
test "$(git ls-remote origin "refs/heads/${TARGET_BRANCH}" | awk '{print $1}')" = "${candidate_sha}"
