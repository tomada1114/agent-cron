#!/usr/bin/env bash
# Tests for scripts/clean-run-state.sh. Each case builds a throwaway repository
# with an origin remote of acme/widget and points AGENT_SKILL_STATE_DIR at its own
# temp directory, so neither the real checkout nor the real run state is touched.
set -euo pipefail
# shellcheck source=scripts/tests/lib.sh
. "$(dirname "$0")/lib.sh"
trap cleanup_temp EXIT

SCRIPT="${REPO_ROOT}/scripts/clean-run-state.sh"

# Sets REPO and STATE (the run-state root) and fills it with holding entries, an
# orphaned worktree dir, a registered worktree, and files that must survive.
setup_state() {
    REPO=$(make_temp_repo)
    git -C "${REPO}" commit -q --allow-empty -m init
    git -C "${REPO}" remote add origin git@github.com:acme/widget.git
    AGENT_SKILL_STATE_DIR=$(make_temp_dir)
    export AGENT_SKILL_STATE_DIR
    STATE="${AGENT_SKILL_STATE_DIR}/shipping-issues/acme__widget"
    mkdir -p "${STATE}/holding/42/sub" "${STATE}/worktrees/orphan" "${STATE}/ci" \
        "${STATE}/verify" "${STATE}/bodies"
    touch "${STATE}/holding/.hidden" "${STATE}/run.md"
    git -C "${REPO}" worktree add -q "${STATE}/worktrees/live" -b live
    cd "${REPO}"
}

assert_kept_files() {
    local p
    for p in run.md ci verify bodies worktrees/live; do
        [ -e "${STATE}/${p}" ] || _fail "expected ${p} to survive"
    done
}

case_dry_run_removes_nothing() {
    setup_state
    capture "${BASH}" "${SCRIPT}" --dry-run
    assert_exit 0
    assert_stdout_contains "would remove"
    assert_stdout_contains "dry run; nothing removed"
    [ -d "${STATE}/holding/42" ] || _fail "holding/42 removed on dry run"
    [ -d "${STATE}/worktrees/orphan" ] || _fail "orphan removed on dry run"
    assert_kept_files
}

case_holding_contents_removed() {
    setup_state
    capture "${BASH}" "${SCRIPT}"
    assert_exit 0
    assert_stdout_contains "holding/42"
    [ ! -e "${STATE}/holding/42" ] || _fail "holding/42 still present"
    [ ! -e "${STATE}/holding/.hidden" ] || _fail "holding/.hidden still present"
    [ -d "${STATE}/holding" ] || _fail "holding/ itself was removed"
    assert_kept_files
}

case_orphan_worktree_removed_registered_kept() {
    setup_state
    capture "${BASH}" "${SCRIPT}"
    assert_exit 0
    assert_stdout_contains "worktrees/orphan"
    assert_stdout_not_contains "worktrees/live"
    [ ! -e "${STATE}/worktrees/orphan" ] || _fail "orphan still present"
    [ -d "${STATE}/worktrees/live" ] || _fail "registered worktree removed"
    git -C "${REPO}" worktree list --porcelain | grep -q "worktrees/live" \
        || _fail "registered worktree no longer listed"
}

case_refuses_outside_git_repo() {
    cd "$(make_temp_dir)"
    capture "${BASH}" "${SCRIPT}" --dry-run
    assert_exit 1
    assert_stderr_contains "ERR_CLEAN_NOT_A_REPO"
    assert_stderr_contains "Next:"
}

case_refuses_symlinked_root() {
    setup_state
    local elsewhere
    elsewhere=$(make_temp_dir)
    mkdir -p "${elsewhere}/holding/keep"
    rm -rf "${STATE}/holding" "${STATE}/worktrees/orphan"
    # The run-state root itself is a symlink that resolves outside shipping-issues/.
    mv "${STATE}" "${STATE}.real"
    ln -s "${elsewhere}" "${STATE}"
    capture "${BASH}" "${SCRIPT}"
    assert_exit 1
    assert_stderr_contains "ERR_CLEAN_UNSAFE_ROOT"
    [ -d "${elsewhere}/holding/keep" ] || _fail "removed through an unsafe root"
}

case_refuses_without_origin() {
    cd "$(make_temp_repo)"
    capture "${BASH}" "${SCRIPT}"
    assert_exit 1
    assert_stderr_contains "ERR_CLEAN_NO_ORIGIN"
}

case_rejects_unknown_argument() {
    cd "$(make_temp_repo)"
    capture "${BASH}" "${SCRIPT}" --force
    assert_exit 1
    assert_stderr_contains "ERR_CLEAN_USAGE"
}

run_case "dry run removes nothing" case_dry_run_removes_nothing
run_case "removes holding contents, keeps the rest" case_holding_contents_removed
run_case "removes an orphan worktree dir, keeps a registered one" case_orphan_worktree_removed_registered_kept
run_case "refuses outside a git repository" case_refuses_outside_git_repo
run_case "refuses a root that resolves elsewhere" case_refuses_symlinked_root
run_case "refuses without an origin remote" case_refuses_without_origin
run_case "rejects an unknown argument" case_rejects_unknown_argument
finish
