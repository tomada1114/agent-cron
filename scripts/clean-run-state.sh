#!/usr/bin/env bash
# Clear this repository's disposable shipping-issues run state:
#
#   scripts/clean-run-state.sh [--dry-run]
#
# The run state lives at
#   ${AGENT_SKILL_STATE_DIR:-$HOME/.local/state/agent-skills}/shipping-issues/<owner>__<repo>/
# with <owner>/<repo> read from the `origin` remote the same way the
# shipping-issues skill's issue_digest.py computes it. Only two things are removed:
#   - every entry inside holding/ (what a run moved aside instead of deleting);
#   - each directory directly under worktrees/ that is not a registered git
#     worktree of this repository (`git worktree list --porcelain`). A registered
#     worktree is never touched.
# Nothing else is deleted: not run.md, ci/, verify/, bodies/, or the root itself.
# Each removed path is printed; --dry-run prints them without removing anything.
#
# Git work tree: required — the owner/repo and the registered worktrees come from
# it, so the script refuses outside one.
#
# Safety guard: the root is resolved to a physical path (`pwd -P`) and must not be
# empty, `/`, or $HOME, and must still end in shipping-issues/<owner>__<repo>; a
# symlinked or `..`-laden root that resolves elsewhere is refused.
#
# Errors (each followed by Expected:/Actual:/Next: lines, exit 1):
#   ERR_CLEAN_USAGE          an unknown argument
#   ERR_CLEAN_NOT_A_REPO     not inside a git work tree
#   ERR_CLEAN_NO_ORIGIN      no `origin` remote, or its URL names no owner/repo
#   ERR_CLEAN_UNSAFE_ROOT    the computed run-state root failed the safety guard
set -euo pipefail

fail() {
    printf '%s: %s\nExpected: %s\nActual: %s\nNext: %s\n' "$1" "$2" "$3" "$4" "$5" >&2
    exit 1
}

DRY_RUN=0
for arg in "$@"; do
    case "${arg}" in
        --dry-run) DRY_RUN=1 ;;
        *) fail ERR_CLEAN_USAGE "unknown argument '${arg}'" \
            "no arguments, or --dry-run" "'${arg}'" \
            "run \`scripts/clean-run-state.sh --dry-run\`" ;;
    esac
done

if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null || true)" != "true" ]; then
    fail ERR_CLEAN_NOT_A_REPO "not inside a git work tree" \
        "run from a checkout of this repository" "$(pwd) is not a git work tree" \
        "cd into the repository and rerun \`just clean-run-state\`"
fi

url=$(git remote get-url origin 2>/dev/null || true)
slug=${url%/}
slug=${slug%.git}
repo=${slug##*/}
rest=${slug%/*}
owner=${rest##*[:/]}
if [ -z "${url}" ] || [ "${rest}" = "${slug}" ] || [ -z "${owner}" ] || [ -z "${repo}" ] \
    || [ "${owner}" = "${rest}" ]; then
    fail ERR_CLEAN_NO_ORIGIN "cannot read owner/repo from the origin remote" \
        "an origin URL ending in <owner>/<repo>[.git]" "origin is '${url}'" \
        "add the remote with \`git remote add origin <url>\`"
fi

suffix="shipping-issues/${owner}__${repo}"
base=${AGENT_SKILL_STATE_DIR:-${HOME}/.local/state/agent-skills}
root="${base}/${suffix}"

if [ ! -d "${root}" ]; then
    echo "clean-run-state: no run state at ${root}; nothing to remove."
    exit 0
fi

physical=$(cd "${root}" && pwd -P)
home_physical=$(cd "${HOME}" 2>/dev/null && pwd -P || echo "${HOME}")
case "${owner}${repo}" in
    *..* | .* | *' '*) bad_name=1 ;;
    *) bad_name=0 ;;
esac
if [ -z "${physical}" ] || [ "${physical}" = "/" ] || [ "${physical}" = "${home_physical}" ] \
    || [ "${bad_name}" = 1 ] || [ "${physical%/"${suffix}"}" = "${physical}" ]; then
    fail ERR_CLEAN_UNSAFE_ROOT "the run-state root failed the safety guard" \
        "a real directory ending in ${suffix}, not empty, /, or \$HOME" \
        "'${root}' resolves to '${physical}'" \
        "check AGENT_SKILL_STATE_DIR and the origin remote, then rerun with --dry-run"
fi

remove() {
    if [ "${DRY_RUN}" = 1 ]; then
        echo "would remove ${1}"
    else
        echo "removing ${1}"
        rm -rf -- "${1}"
    fi
}

if [ -d "${physical}/holding" ]; then
    for entry in "${physical}/holding"/* "${physical}/holding"/.[!.]* "${physical}/holding"/..?*; do
        if [ -e "${entry}" ] || [ -L "${entry}" ]; then
            remove "${entry}"
        fi
    done
fi

if [ -d "${physical}/worktrees" ]; then
    registered=""
    while IFS= read -r line; do
        case "${line}" in
            "worktree "*)
                path=${line#worktree }
                if [ -d "${path}" ]; then
                    path=$(cd "${path}" && pwd -P)
                fi
                registered="${registered}${path}"$'\n'
                ;;
        esac
    done <<<"$(git worktree list --porcelain)"
    for dir in "${physical}/worktrees"/* "${physical}/worktrees"/.[!.]*; do
        if [ -d "${dir}" ] && [ ! -L "${dir}" ]; then
            if ! grep -qxF -- "${dir}" <<<"${registered}"; then
                remove "${dir}"
            fi
        fi
    done
fi

if [ "${DRY_RUN}" = 1 ]; then
    echo "clean-run-state: dry run; nothing removed."
fi
