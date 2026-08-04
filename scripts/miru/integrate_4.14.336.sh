#!/usr/bin/env bash
set -Eeuo pipefail

PRODUCTION_HEAD=a97fcbe96ab6d8392a0a0acf91da46ccb37fdaee
PRODUCTION_MERGE_305=489177590738e082a37e17fc9ef9290e4f168058
PRISTINE_H40=180d787684d5965be5145bcfbf666ed427b4ea18
ROLLBACK_269=61371a1024e341f434deaf61b79a05f73827260a
ANDROID_COMMON_305=4415bf5e08942aee6487946a3e0a50956ef68f1e
ANDROID_COMMON_336=014241ad77dda0eafbdf671d5b8e86917d8ec97e
ANDROID_COMMON_336_PARENT_1=bc841b804f61c5918bd950ccb15e63c36f5bd0b5
ANDROID_COMMON_336_PARENT_2=c31e35278ea8f04f1dceadd77dca4dd7d47932a3
ANDROID_COMMON_BRANCH=deprecated/android-4.14-stable
RELEASE_BRANCH=miru-h40-lts336-release
REPLAY_COMMIT=c10f24a63e3175db2ddf59231175a0fab4e3c8b6
REPLAY_RUN=30748527303
REPLAY_ARTIFACT_ID=8833712206
REPLAY_ARTIFACT_SHA256=60747de0d01c0b0e1dadafbed72d2787ce7e8dac653d6b3687b4cfc43475d9b9
REPLAY_STAGE_SHA256=2969b2e787bfd3e98fc5fe6768eef686aa39030b3783fe3da8436d7bfc5d2143
REPLAY_FINAL_SHA256=2494ea2e93551dbc89f3c98be8577ce3d3b7acf66b27db217df908f1c6383ca8
REPLAY_REPORT_SHA256=c84b3d9b14c13d37a57759f8da096b760c60652585fd48fc8042c162b954c01f
REPLAY_PATCH_SHA256=8ab87ab2ea79c342d61590e842aba8a8b5de452dbd60fbb5dc78681d6627d810
LEDGER=Documentation/miru/lts-4.14.336-conflicts.md
RESULT_TSV=Documentation/miru/lts-4.14.336-resolution-results.tsv
RESOLVER=scripts/miru/resolve_4.14.336.py
SEMANTIC_AUDIT=scripts/miru/audit_4.14.336_semantics.py

mode="${1:-}"
SOURCE_SHA="${SOURCE_SHA:?SOURCE_SHA must be provided by the workflow}"
mkdir -p audit

read_ref() {
    git ls-remote origin "$1" | awk 'NR == 1 {value=$1} END {print value}'
}

check_eq() {
    local label="$1" actual="$2" expected="$3"
    printf '%s.actual=%s\n%s.expected=%s\n' \
        "$label" "$actual" "$label" "$expected" | tee -a audit/provenance.txt
    test "$actual" = "$expected"
}

set_output() {
    local key="$1" value="$2"
    printf '%s=%s\n' "$key" "$value" >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is unavailable}"
}

verify_live_refs() {
    check_eq live_candidate "$(read_ref "refs/heads/${RELEASE_BRANCH}")" "$SOURCE_SHA"
    check_eq live_production "$(read_ref refs/heads/miru-h40)" "$PRODUCTION_HEAD"
    check_eq live_h40 \
        "$(read_ref refs/heads/oneplus/sm8150_s_12.1_op7pro)" \
        "$PRISTINE_H40"

    local live_rollback
    live_rollback="$(read_ref 'refs/tags/miru-h40-4.14.269-final^{}')"
    if [ -z "$live_rollback" ]; then
        live_rollback="$(read_ref refs/tags/miru-h40-4.14.269-final)"
    fi
    check_eq live_rollback "$live_rollback" "$ROLLBACK_269"
}

verify_target() {
    local remote_branch="refs/heads/${ANDROID_COMMON_BRANCH}"
    local local_branch="refs/remotes/android-common/${ANDROID_COMMON_BRANCH}"
    local advertised
    advertised="$(git ls-remote https://android.googlesource.com/kernel/common \
        "$remote_branch" | awk 'NR == 1 {value=$1} END {print value}')"
    check_eq android_common_advertised "$advertised" "$ANDROID_COMMON_336"

    git fetch --no-tags --force https://android.googlesource.com/kernel/common \
        "+${remote_branch}:${local_branch}"
    check_eq android_common_fetched \
        "$(git rev-parse "${local_branch}^{commit}")" \
        "$ANDROID_COMMON_336"

    mapfile -t target_parents < <(
        git cat-file -p "$ANDROID_COMMON_336" | sed -n 's/^parent //p'
    )
    test "${#target_parents[@]}" -eq 2
    check_eq android_common_parent_1 \
        "${target_parents[0]}" "$ANDROID_COMMON_336_PARENT_1"
    check_eq android_common_parent_2 \
        "${target_parents[1]}" "$ANDROID_COMMON_336_PARENT_2"

    git show "${ANDROID_COMMON_336}:Makefile" > audit/android-common-Makefile
    check_eq target_version \
        "$(awk '$1 == "VERSION" && $2 == "=" {value=$3} END {print value}' audit/android-common-Makefile)" \
        4
    check_eq target_patchlevel \
        "$(awk '$1 == "PATCHLEVEL" && $2 == "=" {value=$3} END {print value}' audit/android-common-Makefile)" \
        14
    check_eq target_sublevel \
        "$(awk '$1 == "SUBLEVEL" && $2 == "=" {value=$3} END {print value}' audit/android-common-Makefile)" \
        336
    git merge-base --is-ancestor "$ANDROID_COMMON_305" "$ANDROID_COMMON_336"
}

verify_candidate_ancestry() {
    local ancestor
    for ancestor in \
        "$PRODUCTION_HEAD" \
        "$PRODUCTION_MERGE_305" \
        "$PRISTINE_H40" \
        "$ROLLBACK_269" \
        "$ANDROID_COMMON_305" \
        "$REPLAY_COMMIT"; do
        git cat-file -e "${ancestor}^{commit}"
        git merge-base --is-ancestor "$ancestor" HEAD
        echo "candidate_ancestor.${ancestor}=PASS" | tee -a audit/provenance.txt
    done
}

verify_replay_boundary() {
    printf '%s\n' \
        .github/workflows/miru-h40-build.yml \
        scripts/miru/audit_4.14.336_semantics.py \
        scripts/miru/integrate_4.14.336.sh \
        | sort > audit/expected-post-replay-paths.txt
    git diff --name-only "$REPLAY_COMMIT" HEAD | sort -u \
        > audit/actual-post-replay-paths.txt
    cmp audit/expected-post-replay-paths.txt audit/actual-post-replay-paths.txt

    check_eq resolver_after_replay \
        "$(git rev-parse "HEAD:${RESOLVER}")" \
        "$(git rev-parse "${REPLAY_COMMIT}:${RESOLVER}")"
    check_eq ledger_after_replay \
        "$(git rev-parse "HEAD:${LEDGER}")" \
        "$(git rev-parse "${REPLAY_COMMIT}:${LEDGER}")"

    python3 -m py_compile "$RESOLVER" "$SEMANTIC_AUDIT"
    bash -n scripts/miru/integrate_4.14.336.sh
    echo replay_boundary=PASS | tee -a audit/provenance.txt
}

validate_existing_merge() {
    local found=''
    local commit
    while IFS= read -r commit; do
        mapfile -t parents < <(git cat-file -p "$commit" | sed -n 's/^parent //p')
        if [ "${#parents[@]}" -eq 2 ] && \
           [ "${parents[1]}" = "$ANDROID_COMMON_336" ]; then
            found="$commit"
            break
        fi
    done < <(git rev-list --merges --first-parent HEAD)

    test -n "$found"
    git merge-base --is-ancestor "$PRODUCTION_HEAD" "$found"
    git merge-base --is-ancestor "$ANDROID_COMMON_336" "$found"
    test "$(awk '$1 == "SUBLEVEL" && $2 == "=" {value=$3} END {print value}' Makefile)" = 336
    grep -Fq 'Integration status: **COMPLETE' "$LEDGER"
    grep -Fq 'Semantic resolutions: **14 of 14 complete**' "$LEDGER"
    grep -Fq 'Replay result: **PASS — six of six byte-identical**' "$LEDGER"
    test "$(wc -l < "$RESULT_TSV")" -eq 15
    test -z "$(git ls-files -u)"
    printf 'existing_authentic_merge=%s\nproduction_write=NONE\n' "$found" \
        | tee audit/existing-integration.txt
    set_output created false
    set_output merge_head "$found"
}

record_premerge_audit() {
    local -a kcal_paths=(
        drivers/gpu/drm/msm/sde/sde_kcal_ctrl.c
        drivers/gpu/drm/msm/sde/sde_kcal_ctrl.h
        drivers/gpu/drm/msm/sde/sde_color_processing.c
        drivers/gpu/drm/msm/sde/sde_crtc.c
        drivers/gpu/drm/msm/msm_drv.c
        drivers/gpu/drm/msm/Makefile
        h40-repro/config/GM1911_11_H.40.config
    )
    : > audit/kcal-parent-identities.tsv
    local path
    for path in "${kcal_paths[@]}"; do
        test -s "$path"
        printf '%s\t%s\n' "$(git hash-object "$path")" "$path" \
            >> audit/kcal-parent-identities.tsv
    done

    git diff --name-only "$PRISTINE_H40" "$PRODUCTION_HEAD" -- | sort -u \
        > audit/downstream-paths.txt
    git diff --name-only "$ANDROID_COMMON_305" "$ANDROID_COMMON_336" -- | sort -u \
        > audit/common-305-336-paths.txt
    comm -12 audit/downstream-paths.txt audit/common-305-336-paths.txt \
        > audit/overlap-paths.txt
    git diff --shortstat "$ANDROID_COMMON_305" "$ANDROID_COMMON_336" -- \
        > audit/common-305-336-shortstat.txt
    git diff --name-status "$ANDROID_COMMON_305" "$ANDROID_COMMON_336" -- \
        > audit/common-305-336-name-status.txt
    git log --oneline --no-merges "$ANDROID_COMMON_305..$ANDROID_COMMON_336" \
        > audit/common-305-336-commits.txt
}

perform_merge_and_resolution() {
    git config user.name github-actions[bot]
    git config user.email 41898282+github-actions[bot]@users.noreply.github.com
    git config rerere.enabled false
    git config rerere.autoupdate false
    git config merge.renormalize false
    rm -rf "$(git rev-parse --git-common-dir)/rr-cache"

    local merge_status
    set +e
    git -c rerere.enabled=false \
        -c rerere.autoupdate=false \
        -c merge.renormalize=false \
        merge --no-commit --no-ff "$ANDROID_COMMON_336" \
        > audit/merge-stdout.txt 2> audit/merge-stderr.txt
    merge_status=$?
    set -e

    git status --porcelain=v1 > audit/status-after-merge.txt
    git ls-files -u > audit/unmerged-before-resolution.tsv
    git diff --name-only --diff-filter=U | sort -u > audit/conflict-paths.txt
    local conflict_count
    conflict_count="$(wc -l < audit/conflict-paths.txt)"
    printf 'merge_exit_code=%s\nconflict_count=%s\n' \
        "$merge_status" "$conflict_count" | tee audit/merge-summary.txt
    test "$merge_status" -ne 0
    test "$conflict_count" -eq 14

    python3 "$RESOLVER" --report "$RESULT_TSV" | tee audit/resolver-output.txt
    test -z "$(git ls-files -u)"
    test "$(wc -l < "$RESULT_TSV")" -eq 15
    git diff --cached --check
    perl -c scripts/checkpatch.pl |& tee audit/checkpatch-perl.txt
    python3 "$SEMANTIC_AUDIT" | tee audit/semantic-gates.txt

    if git grep -n -E '^(<<<<<<<|=======|>>>>>>>)' -- \
        . \
        ':!Documentation/miru/lts-4.14.336-conflicts.md' \
        ':!scripts/miru/resolve_4.14.336.py'; then
        echo 'merge marker found after resolution' >&2
        return 1
    fi
}

verify_downstream_identity() {
    local expected path
    while IFS=$'\t' read -r expected path; do
        test "$(git hash-object "$path")" = "$expected"
    done < audit/kcal-parent-identities.tsv

    grep -Fq 'sde_kcal_apply_pcc' drivers/gpu/drm/msm/sde/sde_color_processing.c
    grep -Fq 'sde_kcal_ctrl_init' drivers/gpu/drm/msm/msm_drv.c
    grep -Fq 'sde/sde_kcal_ctrl.o' drivers/gpu/drm/msm/Makefile
    grep -Fq 'CONFIG_DRM_SDE_KCAL=y' h40-repro/config/GM1911_11_H.40.config

    local -a required_paths=(
        arch/arm64
        drivers/gpu/drm/msm
        drivers/input/touchscreen/oneplus_touchscreen
        drivers/power/oplus
        drivers/rpmsg
        drivers/soc/qcom
        h40-repro/config
        net/qrtr
        sound/soc
    )
    for path in "${required_paths[@]}"; do
        test -e "$path"
    done

    test "$(awk '$1 == "VERSION" && $2 == "=" {value=$3} END {print value}' Makefile)" = 4
    test "$(awk '$1 == "PATCHLEVEL" && $2 == "=" {value=$3} END {print value}' Makefile)" = 14
    test "$(awk '$1 == "SUBLEVEL" && $2 == "=" {value=$3} END {print value}' Makefile)" = 336
    echo downstream_compatibility_gate=PASS | tee audit/downstream-compatibility.txt
}

finalize_ledger() {
    python3 - "$SOURCE_SHA" <<'PY'
from pathlib import Path
import sys

path = Path("Documentation/miru/lts-4.14.336-conflicts.md")
text = path.read_text()
replacements = {
    "@INTEGRATION_STATUS@": "COMPLETE — authentic candidate merge created",
    "@CANDIDATE_PARENT@": sys.argv[1],
    "@SEMANTIC_STATUS@": "14 of 14 complete",
}
for old, new in replacements.items():
    if text.count(old) != 1:
        raise SystemExit(f"ledger placeholder {old} count is not one")
    text = text.replace(old, new)

heading = "## Deterministic replay closure\n"
if heading in text:
    raise SystemExit("deterministic replay section already present")
text += f"""
{heading}
The earlier one-off `devfreq.c` final-blob discrepancy was treated as unexplained and blocked integration. Read-only run `30748527303` then reproduced the authentic merge six times: twice at the formerly failing parent, twice at the subsequent passing parent, and twice at the replay workflow parent. All six runs used Git 2.54.0 with rerere and renormalization disabled and produced identical 14-path stage manifests, final mode/blob manifests, resolver reports, and staged patches.

- Replay commit: `c10f24a63e3175db2ddf59231175a0fab4e3c8b6`
- Replay artifact ID: `8833712206`
- Replay artifact SHA-256: `60747de0d01c0b0e1dadafbed72d2787ce7e8dac653d6b3687b4cfc43475d9b9`
- Conflict-stage manifest SHA-256: `2969b2e787bfd3e98fc5fe6768eef686aa39030b3783fe3da8436d7bfc5d2143`
- Final mode/blob manifest SHA-256: `2494ea2e93551dbc89f3c98be8577ce3d3b7acf66b27db217df908f1c6383ca8`
- Resolver report SHA-256: `c84b3d9b14c13d37a57759f8da096b760c60652585fd48fc8042c162b954c01f`
- Resolved staged patch SHA-256: `8ab87ab2ea79c342d61590e842aba8a8b5de452dbd60fbb5dc78681d6627d810`
- Replay result: **PASS — six of six byte-identical**
- Replay repository-write gate: **PASS — none**
"""
path.write_text(text)
PY
    git add -- "$LEDGER" "$RESULT_TSV"
}

create_authentic_merge_commit() {
    finalize_ledger
    git diff --cached --check
    test -z "$(git ls-files -u)"

    git commit \
        -m 'Merge Android Common Linux 4.14.336 into Miru H.40' \
        -m 'Parent 1 is the production-derived Miru H.40 4.14.305 candidate.' \
        -m 'Parent 2 is exact Android Common deprecated/android-4.14-stable commit 014241ad77dda0eafbdf671d5b8e86917d8ec97e.' \
        -m 'All 14 authentic conflicts are resolved by exact stage/blob manifests, semantic gates, and a six-run deterministic replay.'

    local merge_head actual_parents expected_parents
    merge_head="$(git rev-parse HEAD)"
    actual_parents="$(git rev-list --parents -n 1 HEAD)"
    expected_parents="${merge_head} ${SOURCE_SHA} ${ANDROID_COMMON_336}"
    test "$actual_parents" = "$expected_parents"
    git merge-base --is-ancestor "$ANDROID_COMMON_336" HEAD
    printf 'merge_commit=%s\nparent_1=%s\nparent_2=%s\n' \
        "$merge_head" "$SOURCE_SHA" "$ANDROID_COMMON_336" \
        | tee audit/authentic-merge.txt
    set_output created true
    set_output merge_head "$merge_head"
}

prepare() {
    check_eq source_head "$(git rev-parse HEAD)" "$SOURCE_SHA"
    check_eq head_ref "${GITHUB_HEAD_REF:-}" "$RELEASE_BRANCH"
    verify_live_refs
    verify_candidate_ancestry
    verify_target
    git version | tee audit/git-version.txt

    if git merge-base --is-ancestor "$ANDROID_COMMON_336" HEAD; then
        validate_existing_merge
        return
    fi

    verify_replay_boundary
    record_premerge_audit
    perform_merge_and_resolution
    verify_downstream_identity
    create_authentic_merge_commit
}

push_candidate() {
    local merge_head
    merge_head="$(git rev-parse HEAD)"
    check_eq live_candidate_before_push \
        "$(read_ref "refs/heads/${RELEASE_BRANCH}")" "$SOURCE_SHA"
    check_eq live_production_before_push \
        "$(read_ref refs/heads/miru-h40)" "$PRODUCTION_HEAD"
    test "$(git rev-list --parents -n 1 HEAD)" = \
        "${merge_head} ${SOURCE_SHA} ${ANDROID_COMMON_336}"
    git push origin "HEAD:refs/heads/${RELEASE_BRANCH}"
    check_eq live_production_after_push \
        "$(read_ref refs/heads/miru-h40)" "$PRODUCTION_HEAD"
    echo candidate_push=PASS
    echo production_write=NONE
}

case "$mode" in
    prepare)
        prepare
        ;;
    push)
        push_candidate
        ;;
    *)
        echo "usage: $0 {prepare|push}" >&2
        exit 2
        ;;
esac
