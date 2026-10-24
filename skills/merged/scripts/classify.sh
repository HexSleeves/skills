#!/usr/bin/env bash
# Sorts a repo's local branches and linked worktrees into done and still in use,
# after a PR merge. Fetches with --prune, and the heads of recently merged PRs
# it lacks, and changes nothing else.
#
# Usage: classify.sh [--keep-worktree PATH]... [repo-dir]
#   --keep-worktree  a worktree a thread is bound to; it and its branch stay
# A worktree bound to a thread always stays, with its branch: the one holding the
# caller's working directory, and any that an unarchived T3 thread names as its
# worktreePath in T3's state database. When that database cannot be read, every
# worktree under ~/.t3/worktrees stays.
#
# Exit 3, before any fetch, when origin is an Adobe GitHub repo and gh cannot
# reach it: rerun inside ~/Projects/adobe/scripts/with-adobe-route.
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

canon() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s\n' "$1"; }
args="$*"
keep_wts=
while [ "$#" -gt 0 ]; do
  case $1 in
    --keep-worktree) keep_wts+="$(canon "$2")"$'\n'; shift 2 ;;
    -*) echo "classify.sh: unknown option $1" >&2; exit 1 ;;
    *) break ;;
  esac
done
caller_wt=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$caller_wt" ] && caller_wt=$(canon "$caller_wt")
t3_root=$(canon "$HOME/.t3/worktrees")
t3_db=$HOME/.t3/userdata/statev2.sqlite

dir=$(git -C "${1:-.}" rev-parse --show-toplevel)
g() { git -C "$dir" "$@"; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sep=$'\x1f'

gh_ok=0
(cd "$dir" && gh repo view --json name >/dev/null 2>&1) && gh_ok=1
origin_url=$(g config --get remote.origin.url || true)
if [ "$gh_ok" = 0 ] &&
   printf '%s\n' "$origin_url" | grep -Eiq '^(ssh://)?git@github\.com-adobe[:/]|github\.com[:/][^/]*adobe[^/]*/'; then
  echo "classify.sh: $origin_url is Adobe GitHub and gh cannot reach it, so every verdict would be a blind keep." >&2
  echo "classify.sh: rerun as: ~/Projects/adobe/scripts/with-adobe-route --wait -- bash $0 $args" >&2
  exit 3
fi

g fetch --prune --quiet origin
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

: >"$tmp/merged_prs"
if [ "$gh_ok" = 1 ]; then
  (cd "$dir" && gh pr list --state merged --limit 50 --json number,headRefOid,mergeCommit \
    -q '.[] | select(.mergeCommit != null) | "\(.number) \(.headRefOid) \(.mergeCommit.oid)"' \
    >"$tmp/merged_prs" 2>/dev/null) || : >"$tmp/merged_prs"
  (cd "$dir" && gh pr list --state open --limit 200 --json baseRefName -q '.[].baseRefName' \
    >"$tmp/open_bases" 2>/dev/null) || : >"$tmp/open_bases"
fi
touch "$tmp/open_bases"

# Prints why a branch is long-lived (a deploy or release line), or fails.
long_lived() {
  case $1 in
    dev | develop | development | stage | staging | main | master | release/*)
      echo "long-lived branch name"; return ;;
  esac
  if grep -qxF -- "$1" "$tmp/open_bases"; then echo "base of an open PR"; return; fi
  return 1
}

have() { g cat-file -e "$1^{commit}" 2>/dev/null; }
patch_ids() {
  g -c color.ui=never log -p --no-ext-diff --format='commit %H' "$@" | g patch-id --stable | cut -d ' ' -f 1
}

# Writes the patch-ids of a merged PR's own commits to $tmp/pr-<n>.ids, or
# fails. The PR counts only when its merge commit is in $base and has the PR
# head's tree, so the squash dropped nothing the head carried.
pr_ids() {
  local n=$1 head=$2 mc=$3 f=$tmp/pr-$1
  [ -e "$f.bad" ] && return 1
  [ -e "$f.ids" ] && return 0
  if { have "$head" ||
       { g fetch --quiet origin "$head" </dev/null 2>/dev/null && have "$head"; } ||
       { g fetch --quiet origin "refs/pull/$n/head" </dev/null 2>/dev/null && have "$head"; }; } &&
     have "$mc" && g merge-base --is-ancestor "$mc" "$base" &&
     [ "$(g rev-parse "$head^{tree}")" = "$(g rev-parse "$mc^{tree}")" ] &&
     g rev-parse --verify --quiet "$mc^1" >/dev/null; then
    patch_ids "$mc^1..$head" >"$f.ids"
  else
    touch "$f.bad"; return 1
  fi
}

# A batch PR is built by cherry-picking local sub-branches and then
# squash-merged, so a sub-branch's commits never reach $base by hash. It is
# absorbed when every one of its commits has the patch-id of a commit on one
# merged PR's head.
absorbed_reason() {
  local tip=$1 n ids num head mc
  [ -s "$tmp/merged_prs" ] || return 1
  n=$(g rev-list --count "$base..$tip")
  [ "$n" -gt 0 ] && [ "$(g rev-list --count --merges "$base..$tip")" = 0 ] || return 1
  ids=$(patch_ids "$base..$tip")
  [ "$(grep -c . <<<"$ids")" = "$n" ] || return 1
  while read -r num head mc; do
    pr_ids "$num" "$head" "$mc" || continue
    if ! grep -qvxFf "$tmp/pr-$num.ids" <<<"$ids"; then
      echo "absorbed into PR #$num"; return
    fi
  done <"$tmp/merged_prs"
  return 1
}

# Prints why a branch is done, or fails. Squash merges leave the branch's own
# commits outside $base, so "done" means GitHub merged this exact tip, or the
# branch's changes are already in $base. Content alone is not enough: a branch
# just cut for new work has nothing of its own either, so that case also needs
# a merged PR or an upstream the remote deleted. Two cases need no such
# evidence: a sub-branch absorbed into a squash-merged batch PR, and a branch
# the Agent tool's worktree isolation left at an ancestor of $base.
done_reason() {
  local b=$1 tip=$2 track=$3 wt=$4 pr='' evidence='' t
  if [ "$gh_ok" = 1 ]; then
    pr=$(cd "$dir" && gh pr list --head "$b" --state merged --json number,headRefOid \
      -q "map(select(.headRefOid == \"$tip\"))[0].number // empty" 2>/dev/null) || pr=''
    if [ -n "$pr" ]; then echo "PR #$pr merged this exact tip"; return; fi
    pr=$(cd "$dir" && gh pr list --head "$b" --state merged --json number \
      -q '.[0].number // empty' 2>/dev/null) || pr=''
  fi
  if [ -n "$pr" ]; then evidence="PR #$pr merged"
  elif [ "$track" = "[gone]" ]; then evidence="upstream deleted"
  fi
  if [ -n "$evidence" ]; then
    if g merge-base --is-ancestor "$tip" "$base"; then
      echo "$evidence, commits in $base"; return
    fi
    if t=$(g merge-tree --write-tree "$base" "$tip" 2>/dev/null) && [ "$t" = "$base_tree" ]; then
      echo "$evidence, changes already in $base"; return
    fi
  fi
  case $b in
    worktree-agent-*)
      if [ -z "$wt" ] && g merge-base --is-ancestor "$tip" "$base"; then
        echo "harness branch at an ancestor of $def, no worktree"; return
      fi ;;
  esac
  absorbed_reason "$tip"
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
  if reason=$(long_lived "$b"); then v=keep
  elif reason=$(done_reason "$b" "$tip" "$track" "$wt"); then v=delete
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

# A thread whose worktree is removed cannot run again, so bound ones stay.
t3_ok=0
if [ -r "$t3_db" ] && command -v sqlite3 >/dev/null &&
   sqlite3 -cmd '.timeout 5000' -separator "$sep" "file:$t3_db?mode=ro" \
     "select json_extract(payload_json, '\$.worktreePath'), replace(title, char(9), ' ')
      from orchestration_v2_projection_threads
      where archived_at is null and deleted_at is null
        and json_extract(payload_json, '\$.worktreePath') is not null" >"$tmp/t3_bound" 2>/dev/null; then
  t3_ok=1
fi
bound_reason() {
  local c title
  c=$(canon "$1")
  if [ "$c" = "$caller_wt" ]; then echo "bound to a thread: this session runs in it"; return; fi
  if grep -qxF -- "$c" <<<"$keep_wts"; then echo "bound to a thread: --keep-worktree"; return; fi
  if [ "$t3_ok" = 1 ]; then
    title=$(awk -F "$sep" -v p="$c" -v q="$1" '$1 == p || $1 == q { t = substr($2, 1, 60); print (t == "" ? "untitled" : t); exit }' "$tmp/t3_bound")
    if [ -n "$title" ]; then echo "bound to a thread: T3 \"$title\" (archive it to free this worktree)"; return; fi
  else
    case $c/ in "$t3_root"/*) echo "bound to a thread: T3 worktree, and T3's bindings could not be read"; return ;; esac
  fi
  return 1
}

tail -n +2 "$tmp/worktrees" | while IFS=$sep read -r p b l x; do
  if [ -n "$x" ]; then v=delete; r="directory is gone; git worktree prune clears it"
  elif r=$(bound_reason "$p"); then v=keep
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
