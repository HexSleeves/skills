export const meta = {
  name: 'session-audit-friction',
  description: 'Fan readers out over chronological transcript-digest bundles, then synthesize a friction audit with grep-verified counts',
  whenToUse: 'After session_audit.py extract, stats and bundle have filled args.dir',
  phases: [
    { title: 'Read', detail: 'one reader per digest bundle, plus one over recorded observations and existing controls when args.controls is set' },
    { title: 'Synthesize', detail: 'merge themes, verify counts with grep over the digests, rank by cost, propose structural fixes' },
  ],
}

// args: { dir: '<mktemp dir>', bundles: <N from `bundle`>, context: '<who the user is and how they work, from their CLAUDE.md/AGENTS.md>',
//         controls: ['<observation log dir>', '<CLAUDE.md>', '<hooks dir>', ...] (optional), question: '<what the user asked>' (optional) }
const DIR = args.dir
const N = args.bundles
const CONTEXT = args.context || ''
const CONTROLS = args.controls || []
const QUESTION = args.question || 'audit my workflows for friction'

const RULES = `HARD RULES: read-only. Create, edit or delete no file anywhere; use shell pipes only. Run no git, gh or network command and touch no project checkout. Quote only USER turns, masked as they appear in the digests; describe tool errors by tool name and error class only, never by their output text, command lines or tool inputs; never quote env values. If any quoted text still looks like a token, key, password or session id, paraphrase it. Your final structured output is your only deliverable.`

const THEMES = {
  type: 'object',
  properties: {
    themes: { type: 'array', items: { type: 'object', properties: {
      theme: { type: 'string', description: 'short name of the friction point' },
      category: { type: 'string', enum: ['approval-overhead', 'environment-access', 'context-continuity', 'agent-error-rework', 'review-gate-churn', 'tooling-failure', 'communication-mismatch', 'planning-scope', 'cost-time', 'other'] },
      description: { type: 'string', description: 'what happens, concretely, and what it costs the user (attention, wall-clock, money, rework)' },
      root_cause: { type: 'string' },
      occurrences: { type: 'integer', description: 'how many times you saw it in this slice' },
      sessions: { type: 'array', items: { type: 'string' }, description: 'session id prefixes (8 chars) where seen' },
      evidence: { type: 'array', items: { type: 'string' }, description: 'up to 5 short items with timestamp and session prefix: a verbatim USER-turn quote, or "<tool>: <error class>"' },
      grep_pattern: { type: 'string', description: 'an extended regex that would count this pattern in the digests, if one exists' },
    }, required: ['theme', 'category', 'description', 'root_cause', 'occurrences', 'sessions', 'evidence'] } },
    working_well: { type: 'array', items: { type: 'string' }, description: 'workflows that clearly worked, with evidence' },
    user_frustration_quotes: { type: 'array', items: { type: 'string' }, description: 'verbatim USER lines showing frustration, confusion or repetition' },
  },
  required: ['themes', 'working_well', 'user_frustration_quotes'],
}

const readerPrompt = (i) => `You are auditing the user's own past agent sessions to answer: "${QUESTION}". ${CONTEXT}

Read ${DIR}/bundles/bundle-${i}.md in full, paging with offset/limit until the last line. It holds per-session digests: a header with counts (cost, prompts, tool errors, hook refusals, interrupts, compactions), every user turn with the assistant text just before it, and up to 40 tool errors per session. ${DIR}/stats.md has corpus-wide counts for context.

Find FRICTION: places the user had to intervene, repeat, correct, approve trivially, wait, re-explain, recover context or restart, and places where agents erred and reworked (hook refusals, wrong pushes, failed CI after "green", review gates looping, wrong claims). Also note what visibly worked well. Prefer patterns that recur over one-offs, and count occurrences. Give timestamps and session id prefixes for every piece of evidence.

${RULES}`

const controlsPrompt = `You are auditing the user's own past agent sessions to answer: "${QUESTION}". ${CONTEXT} Your slice: the friction already RECORDED and the controls already BUILT, so recommendations do not duplicate them.

Read: ${CONTROLS.map((c) => '`' + c + '`').join(', ')}. For a directory of notes, read the frontmatter of every file and the bodies of those that bear on the question. For a directory of hook or helper scripts, read each header for what it enforces; run none of them. Also read ${DIR}/stats.md.

Return themes of recorded friction (with note ids, whether each is still open, and whether the same failure recurs after a rule was added), plus in working_well a list of existing controls (hook, script, rule) with what each covers. Flag every place where a rule was added and the failure recurred: those need structural fixes, not more rules. Flag rule bloat too: instruction files grown so long or overlapping that they likely cost attention or get skipped.

${RULES}`

phase('Read')
const slices = Array.from({ length: N }, (_, k) => ({ source: `bundle-${k + 1}`, run: () => agent(readerPrompt(k + 1), { label: `read:bundle-${k + 1}`, phase: 'Read', schema: THEMES }) }))
if (CONTROLS.length) slices.push({ source: 'observations+controls', run: () => agent(controlsPrompt, { label: 'read:observations+controls', phase: 'Read', schema: THEMES }) })
const reads = await parallel(slices.map((s) => s.run))
const ok = reads.map((r, i) => (r ? { source: slices[i].source, ...r } : null)).filter(Boolean)
if (ok.length < slices.length) log(`${slices.length - ok.length} reader(s) returned nothing; synthesis covers ${ok.length}/${slices.length} slices: missing ${slices.filter((_, i) => !reads[i]).map((s) => s.source).join(', ')}`)

phase('Synthesize')
const report = await agent(`You are writing an audit of the user's own past agent sessions, answering: "${QUESTION}". ${CONTEXT} Below is JSON from ${ok.length} readers: ${N} chronological digest bundles${CONTROLS.length ? ' plus one over recorded observations and existing controls' : ''}. ${DIR}/index.tsv lists every session with its counts and cost.

Do this:
1. Merge duplicate themes across readers. For each merged theme, VERIFY its size against the digests with read-only shell counts over ${DIR}/digests/*.md (grep -c, or grep -l | wc -l, with the reader's grep_pattern or your own) and over ${DIR}/index.tsv and ${DIR}/stats.md. State the verified count and the command used. Drop or downgrade any theme you cannot substantiate. Say whether it is getting better or worse over time (digest filenames start with the date).
2. Rank friction points by total cost to the user: attention (interventions, approvals, re-explaining), wall-clock (waiting, restarts), money (cost_usd) and rework.
3. For each of the top 8: root cause and one concrete improvement. Prefer STRUCTURAL fixes (a hook, a script, a default, a skill change, a harness setting, deleting a rule) over new prose rules, above all where the controls reader shows a rule exists and the failure recurred. Name the exact file, script or skill to change, check the fix is not already in place, and give effort (S/M/L) and expected payoff.
4. List 3-5 quick wins doable in under an hour.
5. List what is working well and should be kept.
6. Note anything the user does that adds friction (approval style, session length, task batching), stated kindly and plainly.

Output: a terse Markdown report, one-line bottom line first, then the ranked list with bold lead-ins, each with verified numbers. Under ~1500 words. End with a short "Method and limits" section: what the digests capture and what they do not (subagent transcripts excluded from digests, tool errors capped at 40 per session, sessions from other machines and other agent CLIs absent, the current session excluded).

${RULES}

READER FINDINGS:
${JSON.stringify(ok)}`, { label: 'synthesize+verify', phase: 'Synthesize' })

return { report, readers: ok.length, slices: slices.length }
