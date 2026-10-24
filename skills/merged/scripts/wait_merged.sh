#!/usr/bin/env bash
# Blocks until a PR is merged or closed. Start it in the background right after
# opening the PR; it is the wait, so no sleep loop is needed. It only reads.
#
# Usage: wait_merged.sh <pr> [--repo OWNER/REPO] [--interval SECONDS] [--timeout SECONDS]
#   --interval  seconds between polls (default 60)
#   --timeout   give up after this long (default 7000, under a 2-hour background cap)
#
# Exit 0: merged. Prints: MERGED #<pr> head=<branch> mergeCommit=<sha> mergedAt=<time>
# Exit 3: closed without a merge. Prints: CLOSED #<pr> head=<branch>
# Exit 4: timed out with the PR still open: start it again.
# Exit 2: GitHub missed 10 polls in a row (route or network down): start it again.
# A shorter outage is ridden out.
set -euo pipefail

[ "$#" -ge 1 ] || { echo "usage: $0 <pr> [--repo OWNER/REPO] [--interval S] [--timeout S]" >&2; exit 1; }
pr=$1; shift
repo_args=(); interval=60; timeout=7000; max_failures=10
while [ "$#" -gt 0 ]; do
  case $1 in
    --repo) repo_args=(-R "$2"); shift 2 ;;
    --interval) interval=$2; shift 2 ;;
    --timeout) timeout=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

start=$(date +%s); failures=0
while :; do
  if info=$(gh pr view "$pr" ${repo_args[@]+"${repo_args[@]}"} --json state,mergedAt,mergeCommit,headRefName 2>/dev/null) &&
     state=$(jq -er .state <<<"$info" 2>/dev/null); then
    failures=0
    head=$(jq -r .headRefName <<<"$info")
    case $state in
      MERGED)
        printf 'MERGED #%s head=%s mergeCommit=%s mergedAt=%s\n' "$pr" "$head" \
          "$(jq -r '.mergeCommit.oid // ""' <<<"$info")" "$(jq -r '.mergedAt // ""' <<<"$info")"
        exit 0 ;;
      CLOSED) printf 'CLOSED #%s head=%s\n' "$pr" "$head"; exit 3 ;;
    esac
  else
    failures=$((failures + 1))
    [ "$failures" -lt "$max_failures" ] || { echo "wait_merged: GitHub unreachable $max_failures polls in a row" >&2; exit 2; }
  fi
  if [ $(($(date +%s) - start)) -ge "$timeout" ]; then
    echo "wait_merged: PR #$pr still open after ${timeout}s" >&2; exit 4
  fi
  sleep "$interval"
done
