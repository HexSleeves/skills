#!/usr/bin/env bash
# Offline test for scripts/upstream: a local repo stands in for GitHub through a pre-seeded cache.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export XDG_CACHE_HOME="$t/cache" GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

up="$t/up"
mkdir -p "$up/s/clean" "$up/s/merge" "$up/s/clash"
git -C "$up" init -q -b main
printf 'a\nb\nc\nd\ne\n' | tee "$up/s/clean/SKILL.md" "$up/s/merge/SKILL.md" "$up/s/clash/SKILL.md" >/dev/null
git -C "$up" add . && git -C "$up" commit -qm base
base=$(git -C "$up" rev-parse HEAD)

root="$t/repo"
mkdir -p "$root/scripts"
cp "$here/upstream" "$root/scripts/"
for s in clean merge clash; do mkdir -p "$root/skills/$s" && cp "$up/s/$s/SKILL.md" "$root/skills/$s/"; done
printf '{"clean":{"repo":"o/up","path":"s/clean","ref":"%s"},"merge":{"repo":"o/up","path":"s/merge","ref":"%s"},"clash":{"repo":"o/up","path":"s/clash","ref":"%s"}}\n' "$base" "$base" "$base" >"$root/upstreams.json"

sed -i 's/^e$/E/' "$up/s/clean/SKILL.md" "$up/s/merge/SKILL.md"
sed -i 's/^b$/upstream b/' "$up/s/clash/SKILL.md"
echo new >"$up/s/clean/extra.md"
git -C "$up" add . && git -C "$up" commit -qm change
new=$(git -C "$up" rev-parse HEAD)
mkdir -p "$XDG_CACHE_HOME/skills-upstream"
git clone -q "$up" "$XDG_CACHE_HOME/skills-upstream/o_up"

sed -i 's/^a$/fork a/' "$root/skills/merge/SKILL.md"
sed -i 's/^b$/fork b/' "$root/skills/clash/SKILL.md"

"$root/scripts/upstream" check | grep -q '^clash: 1 upstream commit'
out=$("$root/scripts/upstream" pull clean merge clash)
echo "$out"

fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(cat "$root/skills/clean/SKILL.md")" = "$(printf 'a\nb\nc\nd\nE')" ] || fail "clean did not take upstream"
[ "$(cat "$root/skills/clean/extra.md")" = new ] || fail "new upstream file not added"
[ "$(cat "$root/skills/merge/SKILL.md")" = "$(printf 'fork a\nb\nc\nd\nE')" ] || fail "merge lost a side"
grep -q '^<<<<<<< fork' "$root/skills/clash/SKILL.md" || fail "clash has no conflict markers"
pins=$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["clean"]["ref"], d["merge"]["ref"], d["clash"]["ref"])' "$root/upstreams.json")
[ "$pins" = "$new $new $base" ] || fail "pins wrong: $pins"
"$root/scripts/upstream" pin clash "$new"
"$root/scripts/upstream" check clash | grep -q 'clash: up to date' || fail "pin did not clear clash"
echo PASS
