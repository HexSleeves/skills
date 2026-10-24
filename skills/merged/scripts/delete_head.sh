#!/usr/bin/env bash
# Deletes a merged PR's head branch on origin, when that is provably safe: the PR
# is MERGED, the head is in this repo, it is not a long-lived branch, and its tip
# is still the head GitHub merged. Never deletes anything else.
#
# Usage: delete_head.sh <pr> [--repo OWNER/REPO]
#
# Prints one tab-separated row and exits 0:
#   deleted  <branch>  <sha it pointed at>
#   gone     <branch>  <reason>   already deleted; a long-lived one gets a restore command
#   kept     <branch>  <reason>   long-lived, or in a fork
#   ask      <branch>  <reason>   the tip moved after the merge; ask the user
# Exit 3: the PR is not merged. Exit 2: GitHub could not be read. Exit 1: usage.
set -euo pipefail

[ "$#" -ge 1 ] || { echo "usage: $0 <pr> [--repo OWNER/REPO]" >&2; exit 1; }
pr=$1; shift
repo=
while [ "$#" -gt 0 ]; do
  case $1 in
    --repo) repo=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done
fail() { echo "delete_head: $*" >&2; exit 2; }
err=$(mktemp); trap 'rm -f "$err"' EXIT

[ -n "$repo" ] || repo=$(gh repo view --json nameWithOwner -q .nameWithOwner) || fail "cannot resolve the repo; pass --repo"
info=$(gh pr view "$pr" -R "$repo" --json state,headRefName,headRefOid,isCrossRepository) || fail "cannot read PR #$pr"
state=$(jq -r .state <<<"$info")
head=$(jq -r .headRefName <<<"$info")
oid=$(jq -r .headRefOid <<<"$info")
[ "$state" = MERGED ] || { echo "delete_head: PR #$pr is $state, not MERGED" >&2; exit 3; }
if [ "$(jq -r .isCrossRepository <<<"$info")" = true ]; then
  printf 'kept\t%s\thead is in a fork\n' "$head"; exit 0
fi

default=$(gh repo view "$repo" --json defaultBranchRef -q .defaultBranchRef.name) || fail "cannot read the default branch"
open_on_head=$(gh pr list -R "$repo" --state open --base "$head" --json number -q 'length') || fail "cannot list open PRs"
why=
case $head in
  "$default") why="the repo's default branch" ;;
  dev | develop | development | stage | staging | main | master | release/*) why="long-lived branch name" ;;
  *) if [ "${open_on_head:-0}" -gt 0 ]; then why="base of $open_on_head open PR(s)"; fi ;;
esac

if tip=$(gh api "repos/$repo/git/ref/heads/$head" -q .object.sha 2>"$err"); then :
elif grep -q 'HTTP 404\|Not Found' "$err"; then tip=
else fail "cannot read refs/heads/$head: $(cat "$err")"
fi

if [ -z "$tip" ]; then
  if [ -n "$why" ]; then
    printf 'gone\t%s\t%s deleted from origin; restore: gh api -X POST repos/%s/git/refs -f ref=refs/heads/%s -f sha=%s\n' \
      "$head" "$why" "$repo" "$head" "$oid"
  else
    printf 'gone\t%s\talready deleted on origin\n' "$head"
  fi
  exit 0
fi
[ -z "$why" ] || { printf 'kept\t%s\t%s\n' "$head" "$why"; exit 0; }
if [ "$tip" != "$oid" ]; then
  printf 'ask\t%s\ttip moved since the merge: origin %s, merged %s\n' "$head" "${tip:0:12}" "${oid:0:12}"; exit 0
fi

if gh api -X DELETE "repos/$repo/git/refs/heads/$head" >/dev/null 2>"$err"; then
  printf 'deleted\t%s\t%s\n' "$head" "${oid:0:12}"
elif grep -q 'HTTP 422\|Reference does not exist' "$err"; then
  printf 'gone\t%s\talready deleted on origin\n' "$head"
else
  fail "delete refs/heads/$head failed: $(cat "$err")"
fi
