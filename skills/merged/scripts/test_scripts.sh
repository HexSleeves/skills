#!/usr/bin/env bash
# Tests for classify.sh, delete_head.sh and wait_merged.sh. Stubs gh and sleep
# on PATH and builds throwaway git repos; makes no network calls.
# Usage: scripts/test_scripts.sh
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bin=$work/bin; mkdir -p "$bin" "$work/home/.t3/worktrees/repo"
export GH_COUNT=$work/gh-count GH_LOG=$work/gh-log
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=$work/gitconfig
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false

printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/sleep"

cat >"$bin/gh" <<'EOS'
#!/usr/bin/env bash
args="$*"
echo "$args" >>"$GH_LOG"
n=$(( $(cat "$GH_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$GH_COUNT"
case ${GH_STUB:-} in
nogh) echo 'error connecting to api.github.com' >&2; exit 1 ;;
classify)
  case $args in
    "repo view --json name") echo '{"name":"repo"}' ;;
    *"pr list --state open"*) printf '%s\n' ${OPEN_BASES:-} ;;
    *"pr list"*) : ;;
    *) echo "stub gh: unexpected: $args" >&2; exit 1 ;;
  esac ;;
delete)
  case $args in
    "pr view "*) printf '{"state":"%s","headRefName":"%s","headRefOid":"%s","isCrossRepository":%s}\n' \
      "${DH_STATE:-MERGED}" "$DH_HEAD" "${DH_OID:-aaaa1111aaaa1111}" "${DH_FORK:-false}" ;;
    "repo view "*"defaultBranchRef"*) echo "${DH_DEFAULT:-main}" ;;
    "pr list "*"--state open --base"*) echo "${DH_OPEN:-0}" ;;
    "api repos/"*"/git/ref/heads/"*)
      if [ "${DH_TIP:-}" = 404 ]; then echo 'gh: Not Found (HTTP 404)' >&2; exit 1; fi
      echo "${DH_TIP:-aaaa1111aaaa1111}" ;;
    "api -X DELETE "*) : ;;
    *) echo "stub gh: unexpected: $args" >&2; exit 1 ;;
  esac ;;
wait)
  set -- $WM_SEQ
  [ "$n" -le "$#" ] && eval "step=\${$n}" || step=${!#}
  case $step in
    fail) echo 'dial tcp: i/o timeout' >&2; exit 1 ;;
    open) echo '{"state":"OPEN","mergedAt":null,"mergeCommit":null,"headRefName":"feat-x"}' ;;
    closed) echo '{"state":"CLOSED","mergedAt":null,"mergeCommit":null,"headRefName":"feat-x"}' ;;
    merged) echo '{"state":"MERGED","mergedAt":"2026-10-23T10:00:00Z","mergeCommit":{"oid":"cafe1234"},"headRefName":"feat-x"}' ;;
  esac ;;
*) echo "stub gh: no scenario" >&2; exit 1 ;;
esac
EOS
chmod +x "$bin/gh" "$bin/sleep"
export PATH="$bin:$PATH"

fail=0
check() { # check <name> <expected exit> <actual exit> <output> <grep pattern>...
  local name=$1 want=$2 got=$3 out=$4 ok=1; shift 4
  [ "$got" = "$want" ] || ok=0
  for pat in "$@"; do grep -Eq -- "$pat" <<<"$out" || ok=0; done
  if [ "$ok" = 1 ]; then echo "PASS $name"
  else echo "FAIL $name (exit $got, want $want)"; printf '%s\n' "$out" | sed 's/^/    /'; fail=1
  fi
}
refute() { # refute <name> <output> <pattern>
  if grep -Eq -- "$3" <<<"$2"; then echo "FAIL $1: matched $3"; printf '%s\n' "$2" | sed 's/^/    /'; fail=1
  else echo "PASS $1"; fi
}
reset() { rm -f "$GH_COUNT" "$GH_LOG"; }

# ---------- classify.sh ----------
q() { git -C "$@" >/dev/null 2>&1; }
git init -q --bare "$work/origin.git"
git clone -q "$work/origin.git" "$work/main" 2>/dev/null
q "$work/main" commit --allow-empty -m init
q "$work/main" push -u origin main
q "$work/origin.git" symbolic-ref HEAD refs/heads/main
q "$work/main" remote set-head origin main
# A finished branch: pushed, fast-forwarded into origin/main, remote deleted.
finished() {
  q "$work/main" switch -c "$1" main
  q "$work/main" commit --allow-empty -m "$1"
  q "$work/main" push -u origin "$1"
  q "$work/main" push origin "$1:main"
  q "$work/main" push origin --delete "$1"
  q "$work/main" switch main
}
for b in feat-a dev release/1.0 feat-base wt-a wt-b wt-c wt-d wt-e wt-f; do finished "$b"; done
t3=$work/home/.t3/worktrees/repo
q "$work/main" worktree add "$work/wt-a" wt-a
q "$work/main" worktree add "$work/wt-b" wt-b
q "$work/main" worktree add "$t3/wt-c" wt-c
q "$work/main" worktree add "$work/wt-d" wt-d
q "$work/main" worktree add "$t3/wt-e" wt-e
q "$work/main" worktree add "$t3/wt-f" wt-f
# T3's state: wt-c is bound to a live thread, wt-f only to an archived one.
mkdir -p "$work/home/.t3/userdata"
sqlite3 "$work/home/.t3/userdata/statev2.sqlite" "
  create table orchestration_v2_projection_threads (thread_id text, title text, archived_at text, deleted_at text, payload_json text);
  insert into orchestration_v2_projection_threads values
    ('t1', 'Fix #230', null, null, '{\"worktreePath\":\"$t3/wt-c\"}'),
    ('t2', 'Old', '2026-10-01', null, '{\"worktreePath\":\"$t3/wt-f\"}'),
    ('t3', 'Root', null, null, '{\"worktreePath\":null}');"

reset
out=$(cd "$work/wt-d" && HOME=$work/home GH_STUB=classify OPEN_BASES=feat-base bash "$here/classify.sh" --keep-worktree "$work/wt-b" "$work/main" 2>&1); rc=$?
check "classify: runs with gh" 0 "$rc" "$out" $'^default\tmain\t.*gh=1'
check "classify: finished branch deleted" 0 "$rc" "$out" $'^branch\tfeat-a\tdelete\t'
check "classify: dev kept as long-lived" 0 "$rc" "$out" $'^branch\tdev\tkeep\tlong-lived'
check "classify: release/* kept as long-lived" 0 "$rc" "$out" $'^branch\trelease/1.0\tkeep\tlong-lived'
check "classify: base of an open PR kept" 0 "$rc" "$out" $'^branch\tfeat-base\tkeep\tbase of an open PR'
check "classify: unbound worktree deleted" 0 "$rc" "$out" $'^worktree\t[^\t]*/wt-a\tdelete\t'
check "classify: --keep-worktree kept" 0 "$rc" "$out" $'^worktree\t[^\t]*/wt-b\tkeep\tbound to a thread' $'^branch\twt-b\tkeep\t'
check "classify: T3-bound worktree kept" 0 "$rc" "$out" $'^worktree\t[^\t]*/wt-c\tkeep\tbound to a thread: T3 "Fix #230"' $'^branch\twt-c\tkeep\t'
check "classify: unbound T3 worktree deleted" 0 "$rc" "$out" $'^worktree\t[^\t]*/wt-e\tdelete\t'
check "classify: archived thread's worktree deleted" 0 "$rc" "$out" $'^worktree\t[^\t]*/wt-f\tdelete\t'
check "classify: caller's worktree kept" 0 "$rc" "$out" $'^worktree\t[^\t]*/wt-d\tkeep\tbound to a thread: this session' $'^branch\twt-d\tkeep\t'

out=$(cd "$work/main" && HOME=$work/home GH_STUB=classify bash "$here/classify.sh" "$work/main" 2>&1); rc=$?
check "classify: from the main checkout the other worktree is free" 0 "$rc" "$out" $'^worktree\t[^\t]*/wt-d\tdelete\t'

mv "$work/home/.t3/userdata/statev2.sqlite" "$work/statev2.sqlite"
out=$(cd "$work/main" && HOME=$work/home GH_STUB=classify bash "$here/classify.sh" "$work/main" 2>&1); rc=$?
check "classify: unreadable T3 state keeps every T3 worktree" 0 "$rc" "$out" \
  $'^worktree\t[^\t]*/wt-e\tkeep\tbound to a thread: T3 worktree, and T3' $'^worktree\t[^\t]*/wt-a\tdelete\t'
mv "$work/statev2.sqlite" "$work/home/.t3/userdata/statev2.sqlite"

out=$(cd "$work/main" && GH_STUB=nogh bash "$here/classify.sh" "$work/main" 2>&1); rc=$?
check "classify: non-GitHub origin without gh still classifies" 0 "$rc" "$out" 'gh=0'

git clone -q "$work/origin.git" "$work/adobe" 2>/dev/null
for url in git@github.com-adobe:Adobe-DesignTechnology/x.git https://github.com/OneAdobe/Design-Marketplace git@github.com:Adobe-Prototype/t.git; do
  q "$work/adobe" remote set-url origin "$url"
  q "$work/adobe" config "url.$work/origin.git.insteadOf" "$url"
  reset
  out=$(cd "$work/adobe" && GH_STUB=nogh bash "$here/classify.sh" "$work/adobe" 2>&1); rc=$?
  check "classify: refuses $url without the route" 3 "$rc" "$out" 'with-adobe-route'
  refute "classify: $url refused before printing verdicts" "$out" $'^(default|branch|worktree)\t'
  out=$(cd "$work/adobe" && GH_STUB=classify bash "$here/classify.sh" "$work/adobe" 2>&1); rc=$?
  check "classify: $url with gh reachable classifies" 0 "$rc" "$out" 'gh=1'
  q "$work/adobe" config --unset "url.$work/origin.git.insteadOf"
done
q "$work/adobe" remote set-url origin git@github.com:HexSleeves/skills.git
q "$work/adobe" config "url.$work/origin.git.insteadOf" git@github.com:HexSleeves/skills.git
out=$(cd "$work/adobe" && GH_STUB=nogh bash "$here/classify.sh" "$work/adobe" 2>&1); rc=$?
check "classify: non-Adobe GitHub without gh is not refused" 0 "$rc" "$out" 'gh=0'

# ---------- delete_head.sh ----------
dh() { reset; out=$(GH_STUB=delete "$@" bash "$here/delete_head.sh" 7 --repo o/r 2>&1); rc=$?; }
dh env DH_HEAD=feat-x
check "delete_head: merged feature head deleted" 0 "$rc" "$out" $'^deleted\tfeat-x\t'
check "delete_head: DELETE called" 0 0 "$(cat "$GH_LOG")" 'api -X DELETE repos/o/r/git/refs/heads/feat-x'
for head in dev develop staging main release/2.0; do
  dh env DH_HEAD=$head
  check "delete_head: long-lived $head kept" 0 "$rc" "$out" $'^kept\t'"$head"$'\t'
  refute "delete_head: no DELETE for $head" "$(cat "$GH_LOG")" 'DELETE'
done
dh env DH_HEAD=trunk DH_DEFAULT=trunk
check "delete_head: default branch kept" 0 "$rc" "$out" $'^kept\ttrunk\tthe repo\'s default branch'
dh env DH_HEAD=feat-base DH_OPEN=2
check "delete_head: base of open PRs kept" 0 "$rc" "$out" $'^kept\tfeat-base\tbase of 2 open'
refute "delete_head: no DELETE for an open PR's base" "$(cat "$GH_LOG")" 'DELETE'
dh env DH_HEAD=feat-x DH_TIP=404
check "delete_head: already-deleted head is done" 0 "$rc" "$out" $'^gone\tfeat-x\talready deleted'
dh env DH_HEAD=dev DH_TIP=404 DH_OID=e888bd4e888bd4
check "delete_head: deleted long-lived head gets a restore command" 0 "$rc" "$out" \
  $'^gone\tdev\t.*restore: gh api -X POST repos/o/r/git/refs -f ref=refs/heads/dev -f sha=e888bd4e888bd4'
dh env DH_HEAD=feat-x DH_TIP=bbbb2222bbbb2222
check "delete_head: moved tip asks" 0 "$rc" "$out" $'^ask\tfeat-x\ttip moved'
refute "delete_head: no DELETE on a moved tip" "$(cat "$GH_LOG")" 'DELETE'
dh env DH_HEAD=feat-x DH_STATE=OPEN
check "delete_head: open PR refused" 3 "$rc" "$out" 'not MERGED'
dh env DH_HEAD=feat-x DH_FORK=true
check "delete_head: fork head kept" 0 "$rc" "$out" $'^kept\tfeat-x\thead is in a fork'

# ---------- wait_merged.sh ----------
wm() { reset; out=$(GH_STUB=wait WM_SEQ="$1" bash "$here/wait_merged.sh" 7 --repo o/r --interval 1 2>&1); rc=$?; }
wm "open open merged"
check "wait_merged: merged" 0 "$rc" "$out" '^MERGED #7 head=feat-x mergeCommit=cafe1234 mergedAt=2026-10-23T10:00:00Z$'
check "wait_merged: polled three times" 0 0 "$(cat "$GH_COUNT")" '^3$'
check "wait_merged: reads the PR fields" 0 0 "$(head -1 "$GH_LOG")" '^pr view 7 -R o/r --json state,mergedAt,mergeCommit,headRefName$'
wm "open closed"
check "wait_merged: closed unmerged" 3 "$rc" "$out" '^CLOSED #7 head=feat-x$'
wm "open fail fail fail fail fail fail fail fail fail merged"
check "wait_merged: rides out 9 failed polls" 0 "$rc" "$out" '^MERGED #7'
wm "open fail"
check "wait_merged: 10 failed polls in a row" 2 "$rc" "$out" 'unreachable 10 polls'
check "wait_merged: stopped at the 10th failure" 0 0 "$(cat "$GH_COUNT")" '^11$'
reset; out=$(GH_STUB=wait WM_SEQ=open bash "$here/wait_merged.sh" 7 --interval 1 --timeout 0 2>&1); rc=$?
check "wait_merged: timeout" 4 "$rc" "$out" 'still open'
check "wait_merged: no --repo uses the checkout" 0 0 "$(head -1 "$GH_LOG")" '^pr view 7 --json'

[ "$fail" = 0 ] && echo "all passed"
exit "$fail"
