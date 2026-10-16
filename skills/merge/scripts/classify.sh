#!/usr/bin/env bash
# Sorts a repo's local branches and linked worktrees into done and still in use,
# after a PR merge. Fetches with --prune and changes nothing else.
#
# Usage: classify.sh [repo-dir]
#
# Prints tab-separated rows:
#   default   <branch>  <short sha of origin/branch>  gh=<0|1> local=<ahead N, behind M|missing>
#   worktree  <path>    delete|keep         <reason>  <branch or (detached)>
#   branch    <name>    delete|switch|keep  <reason>  <worktree path or ->
#   stash     <ref>     keep                <reason>
#
# switch: the branch is done, but the main checkout has it checked out. Switch
# that checkout to the default branch, then delete the branch.
set -euo pipefail

dir=$(git -C "${1:-.}" rev-parse --show-toplevel)
g() { git -C "$dir" "$@"; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sep=$'\x1f'

g fetch --prune --quiet origin
gh_ok=0
(cd "$dir" && gh repo view --json name >/dev/null 2>&1) && gh_ok=1
def=$(g symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)
def=${def#origin/}
if [ -z "$def" ] && [ "$gh_ok" = 1 ]; then
  def=$(cd "$dir" && gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
fi
def=${def:-main}
base=origin/$def
base_tree=$(g rev-parse "$base^{tree}")
local_state=missing
if g rev-parse --verify --quiet "refs/heads/$def" >/dev/null; then
  read -r ahead behind < <(g rev-list --left-right --count "$def...$base")
  local_state="ahead $ahead, behind $behind"
fi
printf 'default\t%s\t%s\tgh=%s local=%s\n' "$def" "$(g rev-parse --short "$base")" "$gh_ok" "$local_state"

# Prints why a branch is done, or fails. Squash merges leave the branch's own
# commits outside $base, so "done" means GitHub merged this exact tip, or the
# branch's changes are already in $base. Content alone is not enough: a branch
# just cut for new work has nothing of its own either, so that case also needs
# a merged PR or an upstream the remote deleted.
done_reason() {
  local b=$1 tip=$2 track=$3 pr='' evidence='' t
  if [ "$gh_ok" = 1 ]; then
    pr=$(cd "$dir" && gh pr list --head "$b" --state merged --json number,headRefOid \
      -q "map(select(.headRefOid == \"$tip\"))[0].number // empty" 2>/dev/null) || pr=''
    if [ -n "$pr" ]; then echo "PR #$pr merged this exact tip"; return; fi
    pr=$(cd "$dir" && gh pr list --head "$b" --state merged --json number \
      -q '.[0].number // empty' 2>/dev/null) || pr=''
  fi
  if [ -n "$pr" ]; then evidence="PR #$pr merged"
  elif [ "$track" = "[gone]" ]; then evidence="upstream deleted"
  else return 1
  fi
  if g merge-base --is-ancestor "$tip" "$base"; then
    echo "$evidence, commits in $base"; return
  fi
  if t=$(g merge-tree --write-tree "$base" "$tip" 2>/dev/null) && [ "$t" = "$base_tree" ]; then
    echo "$evidence, changes already in $base"; return
  fi
  return 1
}

keep_reason() {
  local tip=$1 track=$2 n
  n=$(g rev-list --count "$base..$tip")
  if [ "$n" = 0 ]; then
    echo "no commits of its own and no sign of a merge; may be new work"
  elif [ "$track" = "[gone]" ]; then
    echo "upstream deleted, but $n commits are not in $base"
  else
    echo "$n commits not in $base${track:+ $track}"
  fi
}

# Pass 1: verdict per branch from its commits alone.
fmt="%(refname:short)%1f%(objectname)%1f%(worktreepath)%1f%(upstream:track)"
g for-each-ref --format="$fmt" refs/heads | while IFS=$sep read -r b tip wt track; do
  [ "$b" = "$def" ] && continue
  if reason=$(done_reason "$b" "$tip" "$track"); then v=delete
  else v=keep; reason=$(keep_reason "$tip" "$track")
  fi
  printf '%s\n' "$b$sep$tip$sep$v$sep$reason$sep${wt:--}" >>"$tmp/branches"
done
touch "$tmp/branches" "$tmp/held"

# Pass 2: worktrees. A done branch stays when its checkout still holds work, or
# when it is locked, since another session may be using it.
g worktree list --porcelain | awk -v OFS="$sep" '
  /^worktree /  { if (p != "") print p, b, l, x; p = substr($0, 10); b = "(detached)"; l = ""; x = "" }
  /^branch /    { b = substr($0, 8); sub("^refs/heads/", "", b) }
  /^locked/     { l = "locked" }
  /^prunable/   { x = "prunable" }
  END           { if (p != "") print p, b, l, x }' >"$tmp/worktrees"

main_wt=$(head -n 1 "$tmp/worktrees" | cut -d "$sep" -f 1)
main_br=$(head -n 1 "$tmp/worktrees" | cut -d "$sep" -f 2)
dirty() { [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]; }
verdict_of() { awk -F "$sep" -v b="$1" '$1 == b { print $3 }' "$tmp/branches"; }

tail -n +2 "$tmp/worktrees" | while IFS=$sep read -r p b l x; do
  if [ -n "$x" ]; then v=delete; r="directory is gone; git worktree prune clears it"
  elif [ -n "$l" ]; then v=keep; r="locked; another session may own it"
  elif [ "$b" = "(detached)" ]; then v=keep; r="detached HEAD"
  elif [ "$(verdict_of "$b")" != delete ]; then v=keep; r="branch $b is not done"
  elif dirty "$p"; then v=keep; r="uncommitted changes"
  else v=delete; r="branch $b is done and the checkout is clean"
  fi
  [ "$v" = keep ] && [ "$b" != "(detached)" ] && printf '%s\n' "$b" >>"$tmp/held"
  printf 'worktree\t%s\t%s\t%s\t%s\n' "$p" "$v" "$r" "$b"
done

# Final branch rows, plus a rebase hint for branches stacked on a done one.
held() { grep -qxF -- "$1" "$tmp/held"; }
while IFS=$sep read -r b tip v reason wt; do
  if [ "$v" = delete ]; then
    if [ "$b" = "$main_br" ]; then
      if dirty "$main_wt"; then v=keep; reason="checked out in the main checkout, which has uncommitted changes"
      else v=switch
      fi
    elif held "$b"; then
      v=keep; reason="done, but its worktree is kept"
    fi
  fi
  printf '%s\n' "$b$sep$tip$sep$v$sep$reason$sep$wt" >>"$tmp/final"
done <"$tmp/branches"
touch "$tmp/final"

while IFS=$sep read -r b tip v reason wt; do
  if [ "$v" = keep ]; then
    while IFS=$sep read -r d dtip dv _ _; do
      [ "$dv" = keep ] && continue
      if g merge-base --is-ancestor "$dtip" "$tip" && ! g merge-base --is-ancestor "$dtip" "$base"; then
        reason="$reason; built on done branch $d: git rebase --onto $base ${dtip:0:12} $b"
      fi
    done <"$tmp/final"
  fi
  printf 'branch\t%s\t%s\t%s\t%s\n' "$b" "$v" "$reason" "$wt"
done <"$tmp/final"

# Stashes are shared by every worktree; report the ones from done branches.
g stash list --format="%gd$sep%gs" | while IFS=$sep read -r ref subject; do
  while IFS=$sep read -r b _ v _ _; do
    [ "$v" = keep ] && continue
    case $subject in
      "WIP on $b:"* | "On $b:"*) printf 'stash\t%s\tkeep\tmade on done branch %s; check before dropping\n' "$ref" "$b" ;;
    esac
  done <"$tmp/final"
done
