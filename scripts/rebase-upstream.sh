#!/bin/bash
# ============================================================================
# Script: rebase-upstream.sh
# Purpose: The rebase ritual. Fetch GNU Window Maker upstream
#          (repo.or.cz/wmaker-crm) and rebase our thin infra/patch layer onto
#          it on a fresh branch, keeping master = "upstream + our commits".
#          Never touches master; never pushes; never force-pushes.
#
# Used by humans locally (`make -f infra.mk rebase`) and by CI
# (.github/workflows/upstream-sync.yml, CI_MODE=1). The two share this one
# source of rebase truth — the workflow only adds PR/issue plumbing on top.
#
# Exit codes (a contract the workflow depends on):
#   0  rebased OK; SYNC_BRANCH is ahead of master and ready to push / PR
#   2  already up to date; upstream has no new commits (no branch created)
#   3  rebase conflict; aborted. Conflicting files written to CONFLICTS_FILE
#
# Environment:
#   UPSTREAM_URL     upstream fetch URL  (default: https — runners can't git://)
#   UPSTREAM_BRANCH  upstream branch     (default: master)
#   BASE_BRANCH      our branch to replay(default: master)
#   SYNC_BRANCH      branch to create    (default: upstream-sync/<UTC date>)
#   CONFLICTS_FILE   conflict list path  (default: .rebase-conflicts.txt)
#   CI_MODE          1 = non-interactive (abort on conflict; for CI)
# ============================================================================
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly ROOT_DIR

UPSTREAM_URL="${UPSTREAM_URL:-https://repo.or.cz/wmaker-crm.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-master}"
BASE_BRANCH="${BASE_BRANCH:-master}"
CONFLICTS_FILE="${CONFLICTS_FILE:-$ROOT_DIR/.rebase-conflicts.txt}"
CI_MODE="${CI_MODE:-0}"

log() { echo "==> $SCRIPT_NAME: $*" >&2; }
die() { echo "error: $*" >&2; exit 1; }

usage() {
	cat >&2 <<EOF
Usage: $SCRIPT_NAME [-h]

Fetch upstream Window Maker and rebase our infra/patch layer onto it on a
fresh branch. Does not push and does not modify '$BASE_BRANCH'.

Environment (see header for the full list):
  UPSTREAM_URL=$UPSTREAM_URL
  UPSTREAM_BRANCH=$UPSTREAM_BRANCH
  BASE_BRANCH=$BASE_BRANCH
  SYNC_BRANCH=<auto: upstream-sync/YYYY-MM-DD>
  CI_MODE=$CI_MODE
EOF
	exit "${1:-1}"
}

require_commands() {
	for cmd in "$@"; do
		command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
	done
}

main() {
	[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage 0
	require_commands git
	cd "$ROOT_DIR"

	[[ -z "$(git status --porcelain)" ]] || die "working tree not clean; commit or stash first"

	local sync_branch
	sync_branch="${SYNC_BRANCH:-upstream-sync/$(date -u +%Y-%m-%d)}"

	log "fetching $UPSTREAM_URL ($UPSTREAM_BRANCH)"
	git fetch --quiet "$UPSTREAM_URL" "$UPSTREAM_BRANCH"
	local upstream_tip
	upstream_tip="$(git rev-parse FETCH_HEAD)"

	local base_tip ahead
	base_tip="$(git rev-parse "$BASE_BRANCH")"
	ahead="$(git rev-list --count "$BASE_BRANCH..$upstream_tip")"
	if [[ "$ahead" -eq 0 ]]; then
		log "up to date: $BASE_BRANCH already contains upstream $UPSTREAM_BRANCH ($(git rev-parse --short "$upstream_tip"))"
		exit 2
	fi
	log "upstream has $ahead new commit(s); rebasing our layer onto $(git rev-parse --short "$upstream_tip")"

	# Replay only OUR commits (those on BASE_BRANCH but not upstream) onto the
	# new upstream tip, on a throwaway branch. master is never touched.
	git branch -f "$sync_branch" "$base_tip"
	git checkout --quiet "$sync_branch"

	if git rebase "$upstream_tip"; then
		local ours
		ours="$(git rev-list --count "$upstream_tip..$sync_branch")"
		log "rebased OK: $sync_branch = upstream + $ours of our commit(s)"
		echo "$sync_branch"   # stdout: the branch name, for callers
		exit 0
	fi

	# Conflict. Record the offending files and back out cleanly.
	git diff --name-only --diff-filter=U | sort -u > "$CONFLICTS_FILE"
	log "rebase conflict in $(wc -l < "$CONFLICTS_FILE") file(s); see $CONFLICTS_FILE"
	if [[ "$CI_MODE" == "1" ]]; then
		git rebase --abort
		git checkout --quiet "$BASE_BRANCH"
		git branch -D "$sync_branch" >/dev/null 2>&1 || true
	else
		log "left rebase in progress on $sync_branch for manual resolution"
		log "resolve, then: git rebase --continue   (or: git rebase --abort)"
	fi
	exit 3
}

main "$@"
