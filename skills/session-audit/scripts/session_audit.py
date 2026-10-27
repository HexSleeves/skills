#!/usr/bin/env python3
"""Mine local Claude Code transcripts into masked digests and usage counts.

Run with `python3 -I`. Every subcommand writes only under --out, which must be
an existing directory outside any git work tree, and prints counts and paths,
never transcript text. Every string copied out of a transcript passes mask().

Subcommands:
  extract     one digest per main session + index.tsv     (friction cut)
  stats       stats.md from index.tsv and digests/         (friction cut)
  bundle      bundles/bundle-N.md, chronological, ~650 KB  (friction cut)
  usage       mains.json, subs.json, usage.md              (usage cut)
  skills      skills.md: Skill-tool calls, slash commands  (usage cut)
  mcp         mcp.md: MCP calls per server                 (usage cut)
  user-turns  user_turns.txt: user turns matching a regex  (usage cut)
  scan        exit 1 if a file still holds a secret shape
"""
import argparse, collections, csv, fnmatch, glob, json, os, re, statistics as st, sys
from multiprocessing import Pool

HOME = os.path.expanduser('~')
HOME_SLUG = HOME.replace('/', '-') + '-'

SECRET_PATTERNS = [
    ('private-key', re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----.*?(-----END [A-Z ]*PRIVATE KEY-----|$)', re.S)),
    ('github-token', re.compile(r'\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})')),
    ('api-key', re.compile(r'\bsk-[A-Za-z0-9_-]{16,}')),
    ('slack-token', re.compile(r'\bxox[abprs]-[A-Za-z0-9-]{10,}')),
    ('aws-key-id', re.compile(r'\b(AKIA|ASIA)[0-9A-Z]{16}\b')),
    ('jwt', re.compile(r'\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}')),
    ('auth-header', re.compile(r'\b(Bearer|Basic|token)\s+(?!\*\*\*)[A-Za-z0-9._~+/=-]{16,}', re.I)),
    ('url-credentials', re.compile(r'(\w+://)[^\s/:@]+:[^\s/@]+@')),
    ('secret-assignment', re.compile(r'\b([A-Za-z0-9_]*(?:key|token|secret|passw(?:or)?d|pwd|auth|cred(?:ential)?s?|session|cookie)[A-Za-z0-9_]*)(\s*[=:]\s*)(?!\*\*\*)("[^"]*"|\'[^\']*\'|[^\s,;]+)', re.I)),
    ('secret-flag', re.compile(r'(--?[A-Za-z0-9_-]*(?:key|token|secret|passw(?:or)?d|pwd|auth|cred)[A-Za-z0-9_-]*)(\s+|=)(?!\*\*\*)(?!-)("[^"]*"|\'[^\']*\'|\S+)', re.I)),
    ('env-export', re.compile(r'\b(export\s+[A-Za-z_][A-Za-z0-9_]*=)(?!\*\*\*)("[^"]*"|\'[^\']*\'|\S+)')),
    # Long mixed letter-digit runs (pasted tokens, session keys); MCP tool names hold "__" and are kept.
    ('opaque-string', re.compile(r'(?<![A-Za-z0-9+/_=])(?![A-Za-z0-9+/_=]*__)(?=[A-Za-z0-9+/_=]*[0-9])(?=[A-Za-z0-9+/_=]*[A-Za-z])[A-Za-z0-9+/_=]{32,}')),
]

REPLACE = {
    'private-key': lambda m: '[masked private key]',
    'url-credentials': lambda m: m.group(1) + '***@',
    'secret-assignment': lambda m: m.group(1) + m.group(2) + '***',
    'env-export': lambda m: m.group(1) + '***',
    'secret-flag': lambda m: m.group(1) + m.group(2) + '***',
}


def mask(s):
    for name, pat in SECRET_PATTERNS:
        s = pat.sub(REPLACE.get(name, lambda m, n=name: f'[masked {n}]'), s)
    return s


def clip(s, n):
    s = re.sub(r'\s+', ' ', s).strip()
    return s if len(s) <= n else s[:n] + '…'


def clean(s, n):
    # Mask before the final clip, and drop a word cut at the pre-clip boundary, so no
    # truncated secret too short for its pattern survives.
    s = re.sub(r'\s+', ' ', s).strip()
    if len(s) > 2 * n:
        s = s[:2 * n].rsplit(' ', 1)[0]
    return clip(mask(s), n)


def txt(cont):
    if isinstance(cont, str):
        return cont
    if isinstance(cont, list):
        return '\n'.join(b.get('text', '') for b in cont if isinstance(b, dict) and b.get('type') == 'text')
    return ''


def records(f):
    with open(f, errors='replace') as fh:
        for line in fh:
            try:
                yield json.loads(line)
            except ValueError:
                continue


def first_ts(f):
    for o in records(f):
        if o.get('timestamp'):
            return o['timestamp']
    return ''


def short_proj(d):
    return d[len(HOME_SLUG):] if d.startswith(HOME_SLUG) else d.lstrip('-')


def in_git_tree(path):
    p = os.path.realpath(path)
    while True:
        if os.path.exists(os.path.join(p, '.git')):
            return True
        parent = os.path.dirname(p)
        if parent == p:
            return False
        p = parent


def check_out(out):
    if not os.path.isdir(out):
        sys.exit(f'--out {out} is not an existing directory; create it with mktemp -d')
    if in_git_tree(out):
        sys.exit(f'--out {out} is inside a git work tree; use a mktemp -d directory outside any checkout')
    os.umask(0o077)
    return out


def fresh_subdir(out, name):
    d = os.path.join(out, name)
    os.makedirs(d, exist_ok=True)
    if os.listdir(d):
        sys.exit(f'{d} already has files from an earlier run; start again in a fresh mktemp -d directory')
    return d


def write(path, text):
    with open(path, 'w') as fh:
        fh.write(text)


class Scope:
    """Main and subagent transcripts selected by project glob, date range and exclusions."""

    def __init__(self, a):
        self.root = os.path.expanduser(a.root)
        self.projects, self.since, self.until = a.projects, a.since, a.until
        self.exclude = a.exclude or []

    def _proj_ok(self, proj):
        return fnmatch.fnmatch(proj, self.projects) or fnmatch.fnmatch(short_proj(proj), self.projects)

    def _sid_ok(self, sid):
        return not any(sid.startswith(x) for x in self.exclude)

    def _date_ok(self, ts):
        d = ts[:10]
        return bool(d) and (not self.since or d >= self.since) and (not self.until or d <= self.until)

    def mains(self):
        out = []
        for f in sorted(glob.glob(os.path.join(glob.escape(self.root), '*', '*.jsonl'))):
            proj = os.path.basename(os.path.dirname(f))
            if self._proj_ok(proj) and self._sid_ok(os.path.basename(f)[:-6]) and self._date_ok(first_ts(f)):
                out.append(f)
        return out

    def subs(self, mains=None):
        # Agent subagents sit at <proj>/<sid>/subagents/agent-*.jsonl; Workflow agents one level
        # deeper under subagents/workflows/wf_*/, so the glob is recursive.
        keep = {os.path.basename(f)[:-6] for f in (mains if mains is not None else self.mains())}
        out = []
        for f in glob.glob(os.path.join(glob.escape(self.root), '*', '*', 'subagents', '**', 'agent-*.jsonl'), recursive=True):
            parts = f.split(os.sep)
            sid = parts[parts.index('subagents') - 1]
            if sid in keep:
                out.append(f)
        return sorted(out)


def sub_ids(f):
    parts = f.split(os.sep)
    i = parts.index('subagents')
    return parts[i - 2], parts[i - 1]


# ---------------------------------------------------------------- friction cut

CONTINUATION = r'\s*(This session is being continued|Context handoff|Note: the T3 server restarted|\[User attached|Delegated task node)'
ERROR_CLASSES = [
    ('hook refusal/guard', r'hook|guard|refus|blocked'),
    ('permission denied', r'denied|permission'),
    ('timeout', r'timed out|timeout'),
    ('IP allow list / network', r'allow list|socks|could not resolve|connection'),
    ('file not read/modified', r'has not been read|modified since|file has been'),
    ('string not found (Edit)', r'string to replace|not found in file'),
    ('exit code nonzero', r'exit code'),
    ('interrupted', r'interrupt'),
]


ERROR_LINE = re.compile(r'- \S+ (\S+?): .* \[(' + '|'.join(re.escape(k) for k, _ in ERROR_CLASSES) + r'|other)\] => ')


def error_class(r):
    e = r.lower()
    for k, pat in ERROR_CLASSES:
        if re.search(pat, e):
            return k
    return 'other'


def digest(f):
    proj = short_proj(os.path.basename(os.path.dirname(f)))
    sid = os.path.basename(f)[:-6]
    prompts, errors, tools, toolcount = [], [], {}, collections.Counter()
    ntools = nerr = deny = intr = compact = 0
    cost, ts, last_asst, cwd = None, [], '', None
    for o in records(f):
        t = o.get('type')
        if o.get('timestamp'):
            ts.append(o['timestamp'])
        if t == 'cost-state':
            cost = o.get('totalCostUSD')
        if t == 'system' and 'compact' in str(o.get('subtype', '')):
            compact += 1
        if o.get('isSidechain'):
            continue
        m = o.get('message') or {}
        c = m.get('content')
        if t == 'assistant' and isinstance(c, list):
            cwd = cwd or o.get('cwd')
            for b in c:
                if not isinstance(b, dict):
                    continue
                if b.get('type') == 'text' and b.get('text', '').strip():
                    last_asst = b['text']
                if b.get('type') == 'tool_use':
                    ntools += 1
                    n = b.get('name')
                    toolcount[n] += 1
                    inp = b.get('input') or {}
                    desc = inp.get('command') or inp.get('skill') or inp.get('file_path') or inp.get('description') or inp.get('prompt') or ''
                    tools[b.get('id')] = f'{n}: {clean(str(desc), 160)}'
        if t != 'user':
            continue
        if isinstance(c, list) and any(isinstance(b, dict) and b.get('type') == 'tool_result' for b in c):
            for b in c:
                if isinstance(b, dict) and b.get('type') == 'tool_result' and b.get('is_error'):
                    nerr += 1
                    r = txt(b.get('content'))
                    if re.search(r'denied|hook|refus', r, re.I):
                        deny += 1
                    if len(errors) < 40:
                        first_line = next((x for x in r.splitlines() if x.strip()), '')
                        errors.append((o.get('timestamp', '')[:16], tools.get(b.get('tool_use_id'), '?'), error_class(r), clean(first_line, 200)))
            continue
        if o.get('isMeta'):
            continue
        s = txt(c)
        if '[Request interrupted' in s:
            intr += 1
        if not s.strip() or s.lstrip().startswith(('<system-reminder>', '<local-command')):
            continue
        s = re.sub(r'<system-reminder>.*?</system-reminder>', '', s, flags=re.S)
        lim = 160 if re.match(CONTINUATION, s) else 400 if s.lstrip().startswith('<command-') else 900
        prompts.append((o.get('timestamp', '')[:16], clean(s, lim), clean(last_asst, 280)))
        last_asst = ''
    if not prompts or not ts:
        return None
    ts.sort()
    hdr = (f'# session {sid}\nproject: {proj}  cwd: {cwd}\n'
           f'span: {ts[0][:16]} -> {ts[-1][:16]}  cost_usd: {cost}  user_prompts: {len(prompts)}  tool_calls: {ntools}  '
           f'tool_errors: {nerr}  denials/hook-refusals: {deny}  interrupts: {intr}  compactions: {compact}\n'
           f'top tools: {toolcount.most_common(8)}\n')
    body = ['\n## user turns (each with the assistant text just before it)']
    for tm, p, a in prompts:
        if a:
            body.append(f'  [assistant before] {a}')
        body.append(f'- {tm} USER: {p}')
    body.append('\n## tool errors (first 40; class, then first line of the masked error)')
    for e in errors:
        body.append(f'- {e[0]} {e[1]} [{e[2]}] => {e[3]}')
    name = f"{ts[0][:10]}_{re.sub(r'[^A-Za-z0-9._-]', '_', proj)[:80]}_{sid[:8]}.md"
    row = (ts[0][:16], proj, sid[:8], len(prompts), ntools, nerr, deny, intr, compact, cost)
    return name, hdr + '\n'.join(body) + '\n', row


def cmd_extract(a):
    out = check_out(a.out)
    fresh_subdir(out, 'digests')
    mains = Scope(a).mains()
    with Pool(a.jobs) as p:
        res = [r for r in p.map(digest, mains, chunksize=2) if r]
    for name, text, _ in res:
        write(os.path.join(out, 'digests', name), text)
    rows = sorted(r[2] for r in res)
    write(os.path.join(out, 'index.tsv'),
          'start\tproject\tsid\tprompts\ttools\terrors\tdenials\tinterrupts\tcompactions\tcost\n'
          + ''.join('\t'.join(map(str, r)) + '\n' for r in rows))
    size = sum(len(t) for _, t, _ in res)
    print(f'transcripts={len(mains)} digests={len(rows)} digest_bytes={size} user_turns={sum(r[3] for r in rows)} out={out}')


def cmd_stats(a):
    out = check_out(a.out)
    rows = list(csv.DictReader(open(os.path.join(out, 'index.tsv')), delimiter='\t'))
    P = collections.defaultdict(collections.Counter)
    for r in rows:
        c = P[r['project']]
        for k in ('prompts', 'tools', 'errors', 'denials', 'interrupts', 'compactions'):
            c[k] += int(r[k])
        c['sessions'] += 1
        c['cost'] += float(r['cost']) if r['cost'] not in ('', 'None') else 0
    span = f"{min(r['start'] for r in rows)[:10]}..{max(r['start'] for r in rows)[:10]}" if rows else 'none'
    lines = [f'# Quantitative summary ({len(rows)} sessions, {span})', '', '## per project']
    lines += [f'- {p}: {dict(c)}' for p, c in sorted(P.items(), key=lambda x: -x[1]['cost'])]
    cmd, short, err, errtool = (collections.Counter() for _ in range(4))
    cont = collections.Counter()
    notices = [('compaction-continuations', 'This session is being continued'), ('context-handoffs', 'Context handoff'),
               ('T3-server-restart-notices', 'Note: the T3 server restarted')]
    for f in glob.glob(os.path.join(glob.escape(out), 'digests', '*.md')):
        for line in open(f):
            m = re.match(r'- \S+ USER: (.*)', line)
            if m:
                u = m.group(1)
                c = re.search(r'<command-name>/?([\w:-]+)</command-name>', u) or re.search(r'<command-message>([\w:-]+)</command-message>', u)
                if c:
                    cmd[c.group(1)] += 1
                elif len(u) <= 12:
                    short[u.lower().strip('. !')] += 1
                for k, prefix in notices:
                    if u.startswith(prefix):
                        cont[k] += 1
                continue
            m = ERROR_LINE.match(line)
            if m:
                errtool[m.group(1)] += 1
                err[m.group(2)] += 1
    lines += ['', '## slash commands invoked (count)'] + [f'- {k}: {v}' for k, v in cmd.most_common(40)]
    lines += ['', '## short replies (<=12 chars; approvals, picks)'] + [f'- {k!r}: {v}' for k, v in short.most_common(30)]
    lines += ['', '## continuity: ' + ' '.join(f'{k}={cont[k]}' for k, _ in notices)]
    lines += ['', '## tool errors by tool (sampled, first 40/session)'] + [f'- {k}: {v}' for k, v in errtool.most_common(15)]
    lines += ['', '## tool errors by rough class'] + [f'- {k}: {v}' for k, v in err.most_common()]
    write(os.path.join(out, 'stats.md'), '\n'.join(lines) + '\n')
    print(f'sessions={len(rows)} stats={os.path.join(out, "stats.md")}')


def cmd_bundle(a):
    out = check_out(a.out)
    fresh_subdir(out, 'bundles')
    bundles, cur, size = [], [], 0
    for f in sorted(glob.glob(os.path.join(glob.escape(out), 'digests', '*.md'))):
        t = open(f).read()
        if cur and size + len(t) > a.size:
            bundles.append(cur)
            cur, size = [], 0
        cur.append(t)
        size += len(t)
    if cur:
        bundles.append(cur)
    for i, b in enumerate(bundles, 1):
        write(os.path.join(out, 'bundles', f'bundle-{i}.md'), '\n'.join(b))
    print(f'bundles={len(bundles)} max_bytes={max((sum(map(len, b)) for b in bundles), default=0)} dir={os.path.join(out, "bundles")}')


# ------------------------------------------------------------------- usage cut

DELEGATION_TOOLS = ('Agent', 'Task', 'Workflow', 'SendMessage')
DELEGATION_SUBSTR = ('delegate_task', 't3_thread_launch', 'create_threads')
PURPOSES = [
    ('comment-gate', r'comment'),
    ('slop-gate', r'slop|claims? check|pr[- ]body'),
    ('review', r'review|council|audit|verify|check|second opinion|critique'),
    ('explore/search', r'explore|find|search|locate|map|survey|look'),
    ('research', r'research|investigat|docs|web'),
    ('implement/fix', r'implement|fix|build|write|add|refactor|migrat|port|create|update'),
    ('read/summarize', r'read|summar|digest|extract'),
]
TOKEN_KEYS = ('input_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens', 'output_tokens')


def usage_of(f):
    # Usage repeats on every streamed chunk of one message, so count each message.id once.
    u, tools, first, last, final = {}, collections.Counter(), None, None, ''
    for o in records(f):
        ts = o.get('timestamp')
        if ts:
            first = first or ts
            last = ts
        m = o.get('message') or {}
        if o.get('type') == 'assistant' and isinstance(m, dict):
            if m.get('usage') and m.get('id'):
                u[m['id']] = (m.get('model'), m['usage'])
            for b in m.get('content') or []:
                if isinstance(b, dict):
                    if b.get('type') == 'tool_use':
                        tools[b.get('name')] += 1
                    if b.get('type') == 'text' and b.get('text', '').strip():
                        final = b['text']
    tot, models = collections.Counter(), collections.Counter()
    for mod, us in u.values():
        models[mod] += 1
        for k in TOKEN_KEYS:
            tot[k] += us.get(k) or 0
    return dict(tot=dict(tot), models=dict(models), tools=dict(tools), first=first, last=last, final_len=len(final), turns=len(u))


def is_delegation(name):
    return name in DELEGATION_TOOLS or any(s in name for s in DELEGATION_SUBSTR)


def main_session(f):
    r = usage_of(f)
    calls = []
    for o in records(f):
        if o.get('isSidechain') or o.get('type') != 'assistant':
            continue
        for b in (o.get('message') or {}).get('content') or []:
            if isinstance(b, dict) and b.get('type') == 'tool_use' and is_delegation(b.get('name', '')):
                i = b.get('input') or {}
                calls.append(dict(name=b['name'], type=i.get('subagent_type'), model=i.get('model'), bg=i.get('run_in_background'),
                                  desc=clean(str(i.get('description') or i.get('title') or ''), 100),
                                  plen=len(str(i.get('prompt') or i.get('task') or i.get('message') or i.get('script') or ''))))
    r.update(calls=calls, sid=os.path.basename(f)[:-6], proj=short_proj(os.path.basename(os.path.dirname(f))))
    return r


def sub_session(f):
    r = usage_of(f)
    try:
        meta = json.load(open(f[:-6] + '.meta.json'))
    except (OSError, ValueError):
        meta = {}
    keep = ('agentType', 'description', 'spawnDepth', 'spawnedWithWorktree', 'requestShape', 'model', 'workflowPhase')
    r['meta'] = {k: meta.get(k) for k in keep}
    if r['meta'].get('description'):
        r['meta']['description'] = clean(str(r['meta']['description']), 160)
    proj, r['sid'] = sub_ids(f)
    r['proj'] = short_proj(proj)
    r['workflow'] = 'workflows' in f.split(os.sep)
    for o in records(f):
        if o.get('type') == 'user':
            c = (o.get('message') or {}).get('content')
            r['brief_len'] = len(c if isinstance(c, str) else json.dumps(c))
            break
    return r


def weighted(t):
    # "input-equivalent" tokens: uncached input + cache write x1.25 + cache read x0.1 + output x5
    return t.get('input_tokens', 0) + 1.25 * t.get('cache_creation_input_tokens', 0) + 0.1 * t.get('cache_read_input_tokens', 0) + 5 * t.get('output_tokens', 0)


def med(xs):
    return st.median(xs) if xs else 0


def pct(xs, q):
    return sorted(xs)[int(q * len(xs))] if xs else 0


def purpose(s):
    d = (s['meta'].get('description') or '').lower() + ' ' + (s['meta'].get('agentType') or '').lower()
    return next((name for name, p in PURPOSES if re.search(p, d)), 'other')


def usage_report(M, S):
    L = []
    p = L.append
    mw = sum(weighted(m['tot']) for m in M)
    sw = sum(weighted(s['tot']) for s in S)
    p(f'# Delegation and token usage ({len(M)} main sessions, {len(S)} subagent transcripts, {sum(s["workflow"] for s in S)} of them Workflow agents)')
    p(f'weighted token share: main {mw / 1e6:.0f}M, subagents {sw / 1e6:.0f}M -> subagents {sw / (mw + sw) if mw + sw else 0:.0%}')
    p('(weights: uncached input 1, cache write 1.25, cache read 0.1, output 5; usage deduplicated by message.id)')
    calls = [c for m in M for c in m['calls']]
    ag = [c for c in calls if c['name'] in ('Agent', 'Task')]
    p(f'delegation calls by tool: {collections.Counter(c["name"] for c in calls).most_common()}')
    p(f'Agent subagent_type: {collections.Counter(c["type"] for c in ag).most_common(15)}')
    p(f'model override: {collections.Counter(c["model"] for c in ag).most_common()}')
    per = [sum(1 for c in m['calls'] if c['name'] in ('Agent', 'Task')) for m in M]
    nz = [x for x in per if x]
    p(f'agents per session: zero {per.count(0)}, median(nonzero) {med(nz)}, max {max(per, default=0)}, sessions>=20: {sum(x >= 20 for x in per)}')
    p(f'subagent agentType: {collections.Counter(s["meta"].get("agentType") for s in S).most_common(15)}')
    byt = collections.defaultdict(lambda: [0, 0.0, [], []])
    for s in S:
        b = byt[s['meta'].get('agentType')]
        b[0] += 1
        b[1] += weighted(s['tot'])
        b[2].append(sum(s['tools'].values()))
        b[3].append(s.get('final_len', 0))
    p('\ntype | n | weighted tok share | median tool calls | median result chars')
    for t, b in sorted(byt.items(), key=lambda x: -x[1][1])[:14]:
        p(f'{t} | {b[0]} | {b[1] / sw if sw else 0:.1%} | {med(b[2])} | {med(b[3])}')
    bc, bw = collections.Counter(), collections.Counter()
    for s in S:
        k = s['purpose'] = purpose(s)
        bc[k] += 1
        bw[k] += weighted(s['tot'])
    p('\npurpose (keyword bucket over description + agentType) | n | token share')
    for k, n in bc.most_common():
        p(f'{k} | {n} | {bw[k] / sw if sw else 0:.1%}')
    p(f'\nspawnDepth: {collections.Counter(s["meta"].get("spawnDepth") for s in S).most_common()}  '
      f'worktree: {sum(1 for s in S if s["meta"].get("spawnedWithWorktree"))}  '
      f'requestShape: {collections.Counter(s["meta"].get("requestShape") for s in S).most_common()}')
    bl = [s.get('brief_len', 0) for s in S]
    fl = [s.get('final_len', 0) for s in S]
    p(f'brief chars median {med(bl)} p90 {pct(bl, .9)}; result chars median {med(fl)} p90 {pct(fl, .9)}')
    p(f'subagent models: {collections.Counter(k for s in S for k in s["models"]).most_common()}')
    for label, key in (('agentType', lambda s: s['meta'].get('agentType')), ('purpose', lambda s: s['purpose'])):
        p(f'\nrepeat passes per session by {label} (only keys run >=2 times in some session): key | sessions | median | max | sessions>=3')
        g = collections.Counter((s['sid'], key(s)) for s in S)
        byk = collections.defaultdict(list)
        for (_, k), v in g.items():
            byk[k].append(v)
        for k, vs in sorted(byk.items(), key=lambda x: -max(x[1])):
            if max(vs) >= 2:
                p(f'{k} | {len(vs)} | {med(vs)} | {max(vs)} | {sum(v >= 3 for v in vs)}')
    tiny = [s for s in S if sum(s['tools'].values()) <= 2]
    p(f'\nsubagents with <=2 tool calls: {len(tiny)} ({len(tiny) / len(S) if S else 0:.0%}); types: '
      f'{collections.Counter(s["meta"].get("agentType") for s in tiny).most_common(6)}')
    p(f'sample tiny descriptions (masked): {[s["meta"].get("description") for s in tiny[:25]]}')
    return '\n'.join(L) + '\n'


def cmd_usage(a):
    out = check_out(a.out)
    sc = Scope(a)
    mains = sc.mains()
    subs = sc.subs(mains)
    with Pool(a.jobs) as p:
        M = p.map(main_session, mains, chunksize=4)
        S = p.map(sub_session, subs, chunksize=16)
    write(os.path.join(out, 'mains.json'), json.dumps(M))
    write(os.path.join(out, 'subs.json'), json.dumps(S))
    write(os.path.join(out, 'usage.md'), usage_report(M, S))
    print(f'mains={len(M)} subs={len(S)} usage={os.path.join(out, "usage.md")}')


def cmd_skills(a):
    out = check_out(a.out)
    c, slash, sess = collections.Counter(), collections.Counter(), collections.defaultdict(set)
    for f in Scope(a).mains():
        for o in records(f):
            cont = (o.get('message') or {}).get('content')
            if o.get('type') == 'assistant' and isinstance(cont, list):
                for b in cont:
                    if isinstance(b, dict) and b.get('type') == 'tool_use' and b.get('name') == 'Skill':
                        s = str((b.get('input') or {}).get('skill'))
                        c[s] += 1
                        sess[s].add(f)
            if o.get('type') == 'user' and cont:
                for x in re.findall(r'<command-name>/?([^<]{1,80})</command-name>', json.dumps(cont)):
                    slash[x] += 1
                    sess['/' + x].add(f)
    L = [f'# Skill usage', f'Skill tool calls: {sum(c.values())}', '', 'calls | sessions | skill']
    L += [f'{v} | {len(sess[k])} | {k}' for k, v in c.most_common()]
    L += ['', 'slash commands: count | sessions | command'] + [f'{v} | {len(sess["/" + k])} | {k}' for k, v in slash.most_common(40)]
    write(os.path.join(out, 'skills.md'), '\n'.join(L) + '\n')
    print(f'skill_calls={sum(c.values())} distinct_skills={len(c)} slash={sum(slash.values())} out={os.path.join(out, "skills.md")}')


def cmd_mcp(a):
    out = check_out(a.out)
    sc = Scope(a)
    mains = sc.mains()
    c, s = collections.Counter(), collections.defaultdict(set)
    for f in mains + sc.subs(mains):
        key = f.split(os.sep + 'subagents' + os.sep)[0]
        for o in records(f):
            if o.get('type') != 'assistant':
                continue
            for b in (o.get('message') or {}).get('content') or []:
                if isinstance(b, dict) and b.get('type') == 'tool_use' and b.get('name', '').startswith('mcp__'):
                    srv = b['name'].split('__')[1]
                    c[srv] += 1
                    s[srv].add(key)
    L = ['# MCP calls per server (main + subagent transcripts)', 'calls | sessions | server'] + [f'{v} | {len(s[k])} | {k}' for k, v in c.most_common()]
    write(os.path.join(out, 'mcp.md'), '\n'.join(L) + '\n')
    print(f'mcp_calls={sum(c.values())} servers={len(c)} out={os.path.join(out, "mcp.md")}')


DEFAULT_TURN_PATTERN = r'\b(sub-?agents?|agents?|fork|delegat\w*|in parallel|yourself|handoff|hand off|context|orchestrat\w*|worker|thread)\b'


def cmd_user_turns(a):
    out = check_out(a.out)
    pat = re.compile(a.pattern, re.I)
    rows = []
    for f in Scope(a).mains():
        proj = short_proj(os.path.basename(os.path.dirname(f)))
        for o in records(f):
            if o.get('type') != 'user' or o.get('isSidechain') or o.get('isMeta'):
                continue
            c = (o.get('message') or {}).get('content')
            if isinstance(c, list):
                if any(isinstance(b, dict) and b.get('type') == 'tool_result' for b in c):
                    continue
                c = txt(c)
            if not isinstance(c, str):
                continue
            s = re.sub(r'<system-reminder>.*?</system-reminder>', '', c, flags=re.S).strip()
            if not s or s.startswith('<') or re.match(CONTINUATION, s) or len(s) > 1500:
                continue
            if pat.search(s):
                rows.append(f"{o.get('timestamp', '')[:10]} {proj[:40]} {os.path.basename(f)[:8]}: {clean(s, 400)}")
    rows.sort()
    write(os.path.join(out, 'user_turns.txt'), '\n'.join(rows) + '\n')
    print(f'matching_user_turns={len(rows)} out={os.path.join(out, "user_turns.txt")}')


def plain_value(name, m):
    # mask() hides every keyword assignment; the scan ignores ones whose value is a bare word
    # or number ("per session: 3"), which prose reports are full of.
    if name not in ('secret-assignment', 'secret-flag'):
        return False
    v = m.group(m.lastindex).strip('"\'')
    return len(v) < 6 or bool(re.fullmatch(r'[A-Za-z]+|[0-9.,%]+', v))


def cmd_scan(a):
    hits = 0
    for path in a.files:
        for n, line in enumerate(open(path, errors='replace'), 1):
            for name, pat in SECRET_PATTERNS:
                if any(not plain_value(name, m) for m in pat.finditer(line)):
                    hits += 1
                    print(f'{path}:{n}: {name}')
    print(f'secret-shape hits: {hits}')
    sys.exit(1 if hits else 0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)

    def add(name, fn, scoped=True):
        p = sub.add_parser(name)
        p.set_defaults(fn=fn)
        if scoped:
            p.add_argument('--out', required=True, help='existing mktemp -d directory outside any git work tree')
            p.add_argument('--root', default='~/.claude/projects', help='transcript root (default ~/.claude/projects)')
            p.add_argument('--projects', default='*', help='glob over project dir names, full or with the home prefix stripped; pass as --projects=GLOB since names start with -')
            p.add_argument('--since', help='YYYY-MM-DD, by session start')
            p.add_argument('--until', help='YYYY-MM-DD, by session start, inclusive')
            p.add_argument('--exclude', action='append', help='session id prefix to skip (the current session); repeatable')
            p.add_argument('--jobs', type=int, default=max(1, (os.cpu_count() or 2) - 1))
        return p

    add('extract', cmd_extract)
    add('stats', cmd_stats)
    add('bundle', cmd_bundle).add_argument('--size', type=int, default=650_000, help='max bytes per bundle')
    add('usage', cmd_usage)
    add('skills', cmd_skills)
    add('mcp', cmd_mcp)
    add('user-turns', cmd_user_turns).add_argument('--pattern', default=DEFAULT_TURN_PATTERN)
    add('scan', cmd_scan, scoped=False).add_argument('files', nargs='+')
    a = ap.parse_args()
    a.fn(a)


if __name__ == '__main__':
    main()
