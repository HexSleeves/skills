---
name: "tdd"
description: Use when the user wants to build features or fix bugs test-first, mentions "red-green-refactor", or wants integration tests.
metadata:
  upstream: mattpocock/skills
---

# Test-Driven Development

TDD is the red → green loop. This skill is the reference that makes that loop produce tests worth keeping: what a good test is, where tests go, the anti-patterns, and the rules of the loop. Every section applies on every cycle: consult them before and during the loop, not after.

When exploring the codebase, read `GLOSSARY.md` (if it exists) so test names and interface vocabulary match the project's domain language, and respect ADRs in the area you're touching.

## What a good test is

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification: "user can checkout with valid cart" tells you exactly what capability exists, and it survives refactors because it doesn't care about internal structure.

For game or simulation rules, rule tests prove the rules correct, not balanced. Write at least one test that drives the rules through the production movement or interaction model with degenerate strategies (do nothing, camp the best spot, sweep mechanically, one active Player with the rest idle) and assert each scores clearly below an attentive strategy. The driver takes its inputs from the production helpers rather than restating them, and is no better than a real player: it travels, and it does not act everywhere on one tick.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

## Seams: where tests go

A **seam** is the public boundary you test at: the interface where you observe behavior without reaching inside. Tests live at seams, never against internals.

**Test only at pre-agreed seams.** Before writing any test, write down the seams under test and confirm them with the user. No test is written at an unconfirmed seam. Under a plan the user approved, the seams the module's existing specs already test at count as agreed: state them in one line before the first test and go ahead. Ask only for a new seam, or when the module has no spec. You can't test everything, so agreeing the seams up front is how testing effort lands on the critical paths and complex logic instead of every edge case.

Before stating the seams, read the repo's documented test rules (`CODING_STANDARDS.md`, `CONTRIBUTING.md`, or whatever AGENTS.md names as review rules). A rule there that names a seam for a kind of change, such as "race fix gets a Postgres test", overrides the existing-spec default for that slice.

Ask: "What's the public interface, and which seams should we test?" Give each proposed seam a one-line note on what it catches and what it misses.

**Test through the production wrapper.** When production wraps a call (client settings, caches, middleware), the integration test runs through that wrapper or with the same settings, and names the wrapper in the test. A seam that skips the wrapper proves a different path; for example, a query the deployed client runs with a query cache enabled must be tested with that cache setting applied.

Process signals and terminal state need one check outside the injected seam. A fake emitter or stream cannot show a terminal hangup, the stdio errors that follow it, or the default exit. Add a real PTY run against the built CLI (tmux `kill-session` for SIGHUP, `send-keys C-c` for SIGINT), or a minimal script that mirrors the handler when the window is too short to hit.

Overlapping timers need a clock that holds them. When the behaviour is about two timers or retries pending at once (dedupe, coalescing, cancellation, joining an existing wait), the fake `sleep` keeps its resolvers until the test releases them. A clock that advances and resolves at once serialises timers and cannot show overlap. A test that is green at the red step is the signal: change the seam, not the assertion.

When the shape of that interface is itself in question (how deep the module is, where the seam belongs, what the interface should expose), call the Skill tool with "codebase-design" for the vocabulary. It is the shared source of the module, interface, depth, seam, adapter, leverage and locality terms, and it is a reference to consult, not a session to run.

## Anti-patterns

- **Implementation-coupled**: mocks internal collaborators, tests private methods, or verifies through a side channel (querying the database instead of using the interface). The tell: the test breaks when you refactor but behavior hasn't changed.
- **Tautological**: the assertion recomputes the expected value the way the code does (`expect(add(a, b)).toBe(a + b)`, a snapshot derived by hand the same way, a constant asserted equal to itself), so it passes by construction and can never disagree with the code. Expected values must come from an independent source of truth: a known-good literal, a worked example, the spec.
- **Horizontal slicing**: writing all tests first, then all implementation. Bulk tests verify _imagined_ behavior: you test the _shape_ of things rather than user-facing behavior, the tests go insensitive to real changes, and you commit to test structure before understanding the implementation. Work in **vertical slices** instead: one test → one implementation → repeat, each test a **tracer bullet** that responds to what the last cycle taught you.

## Rules of the loop

- **Red before green.** Write the failing test first, then only enough code to pass it. Don't anticipate future tests or add speculative features.
- **Red is counted.** Read the runner's count of tests run, not only the fail count: red means at least one test executed and failed for the expected reason. A run of zero tests is a broken instrument. Runners that glob their arguments (`node --test` and others) match nothing on a path with `[...]` segments, such as Next.js dynamic routes, even when the shell quotes it; pass a glob that matches the file and confirm the count.
- **Pinned behaviour goes red by mutation.** A test that pins behaviour the code already has (characterization, call budgets, regression pins) passes on its first run, and a compile error from a missing helper is not red. Derive the expected values from the code or the spec before the first run, then make a minimal temporary change to the code under test that the test should catch, watch it fail, and revert. Name this in the seam proposal so the user agrees to it up front. A mutation that still passes means the fixture is wrong: check that the state the test relies on (unmerged parts, a cold cache, ordering, a fault hook matched on query text) still exists at the assertion, because the storage engine or runtime can erase it first.
- The fixture reaches the case. A run that saturates before the case under test (a wall, a cap, an empty queue, a timeout) passes for the wrong reason, so the test asserts it got there (distance walked exceeds the allowance). Assert the property a guard protects, not an end state the system repairs on its own. A test that something is refused or blocked gets one mutation that removes the blocker outright, a new fuzz is run against the guard-removed mutant before its green is read, and a mutation step asserts it changed the file before its run counts.
- A changed tolerance reruns its recorded case. When a change narrows or replaces a tolerance, timeout, retry count or threshold, find the commit and PR that set the old value (`git log -S <CONSTANT>`), rerun the stress or case recorded there, and compare against main under the same conditions in alternating runs. A green run at default speed says nothing about a constant sized for the slow path.
- Per-run values need three greens. A new test whose fixture carries values that change per run (commit SHAs, timestamps, random ids, temp paths) runs green at least three times before it counts, and an expected collection built from those values is normalised the same way as the actual one (sort both, or compare as sets).
- A universal name sweeps the reachable domain. A test whose name claims a property for every input ("every", "never", "always", "neither ... can") runs the domain production can reach, derived from the code path that produces inputs, not from the first value the feature uses. When that domain is too large to sweep, the name says what it samples.
- A seeded fuzz counts its distinct cases. In JavaScript, use an integer-safe PRNG (`Math.imul`-based, such as mulberry32, or a library), never a textbook LCG on doubles, whose product passes 2^53 and falls into a short cycle. Before reading a failure count as a rate or comparing two counts, count the distinct generated cases (`new Set(cases.map(JSON.stringify)).size`) and report it beside the run count.
- **Propagation needs a sentinel.** When a test checks that a config value or environment variable reaches its consumers, the fixture value differs from every default and fallback the code has (`{"test":"key"}`, not `{}`), and the test asserts it arrived at each consumer. A fixture equal to the default passes whether the value was passed through or dropped.
- **No runner, no production code.** When the test runner is unreachable (remote machine offline, dependencies that won't install), stop writing production code for that behaviour. Restore a runner and witness red first, or stop and report to the user.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Refactoring is not part of the loop.** It belongs to the review stage (see the `code-review` skill), not the red → green implementation cycle.
