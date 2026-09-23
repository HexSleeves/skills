# Codex invocation contract

Use this contract when driving `codex exec` from a non-TTY harness. The local binary
`/Users/lecoqjacob/.local/bin/codex` reported `codex-cli 0.153.4` when this contract was
updated. Its read-only help shows `-s read-only`, `--approve-for-me`, JSONL output, and
`-o`; it rejects the former `exec --full-auto` invocation.

CLI behavior can change. Before scripting a different installed version, inspect local help with
`codex exec --help` and `codex exec resume --help`:

```bash
CODEX="${CODEX_BIN:-$(command -v codex)}"
"$CODEX" --version
"$CODEX" exec --help
"$CODEX" exec resume --help
```

Use only flags shown by that binary. Do not change the user's model or configuration as a
side effect of this check.

## Every call

1. Confirm that the user authorized this delegation, its scope, and any requested write or
   network access.
2. Put the prompt in a file and pass it on stdin with `- <"$FILE"`. An argv prompt can also
   consume piped stdin, and shell quoting can change its contents.
3. Capture stdout JSONL, stderr diagnostics, and the final answer in separate fresh files.
   Do not pipe the live stream through an early-exiting filter.
4. Use a fresh temporary directory per run and a fresh filename per round:

   ```bash
   RUN=$(mktemp -d /tmp/cdx.XXXXXX)
   ```

5. Resume only an explicit thread ID. Do not use `--last`.
6. Force sandbox mode again on every resume. Codex 0.153.4 resume help does not expose `-s`,
   so use `-c sandbox_mode="read-only"` or `-c sandbox_mode="workspace-write"`. For write
   resumes that need extra authorized roots, also restore them as described under Write calls.
   Never add write roots to a read-only review.
7. Set the harness timeout to 600000 milliseconds. A timeout can leave the answer file empty.
8. Pass `--skip-git-repo-check` when the intended scope may not be a trusted Git root.
9. Apply the integration startup boundary below before every new or resumed call.
10. Snapshot the working tree before and after every call:

   ```bash
   snap() {
     phase=${2:-pre}
     git status --porcelain > "$RUN/$phase-$1.txt"
     git diff > "$RUN/$phase-$1.patch"
     git ls-files --others --exclude-standard -z \
       | xargs -0 shasum > "$RUN/$phase-$1.sha" 2>"$RUN/$phase-$1-sha.err" || true
   }
   ```

After the process exits, run `snap <round> post` and compare both snapshots, including on
failure. Also snapshot ignored files and any authorized locations an integration could touch;
Git status alone misses ignored startup writes. Treat unintended changes as a failed review.
Preserve unexpected generated files and unknown or pre-existing state, and report the mismatch.
Do not automatically revert or delete paths, even when they appeared clean before the call.

## Integration startup

A read-only prompt and sandbox do not by themselves prevent configured MCP integrations from
writing during startup, before any model command. This contract is not general sandbox
certification. For bounded file-only reviews, disable every unneeded configured integration
before starting the process, and apply the same overrides on resume.

Build a Bash `MCP_ARGS` array from the locally configured names. For each unneeded integration,
append `-c 'mcp_servers.<name>.enabled=false'`, replacing `<name>` with its supported plain key
name. Do not quote individual dotted segments: `mcp_servers."<name>".enabled=false` failed
with `invalid transport` on the verified CLI. If a name cannot use the supported syntax, stop
and verify a supported override before launching the review.

Verify the effective configuration with `"$CODEX" "${MCP_ARGS[@]}" mcp list --json` (or
`mcp get <name> --json`), parsing the result locally to check disabled status without printing
raw configuration, credentials, or the server inventory. Check the merged configuration, not
just one config file; stop if any unneeded integration is still enabled or an override fails.
These per-call overrides must not edit the global config. Keep real configured names out of reusable guidance. The examples
below assume `MCP_ARGS` has been prepared and verified; leave it empty only when no overrides
are needed. If an integration is required, consider its startup writes and other side effects
against the user's authorized scope before allowing it to start. Stop if that scope is unclear.

## Read-only calls

```bash
RUN=$(mktemp -d /tmp/cdx.XXXXXX)
# Write the bounded prompt to "$RUN/prompt-r1.md" first.
snap r1
"$CODEX" "${MCP_ARGS[@]}" exec -s read-only --skip-git-repo-check --json \
  -o "$RUN/out-r1.txt" - <"$RUN/prompt-r1.md" \
  >"$RUN/stream-r1.jsonl" 2>"$RUN/err-r1.log"
status=$?
snap r1 post
THREAD_ID=$(grep -m1 '"type":"thread.started"' "$RUN/stream-r1.jsonl" \
  | sed 's/.*"thread_id":"\([^"]*\)".*/\1/')
printf 'THREAD_ID=%s\n' "$THREAD_ID"
```

Keep the exit status. Do not treat `thread.started` as success.

For a later read-only round:

```bash
snap rN
"$CODEX" "${MCP_ARGS[@]}" exec resume "$THREAD_ID" -c sandbox_mode="read-only" \
  --skip-git-repo-check --json -o "$RUN/out-rN.txt" \
  - <"$RUN/prompt-rN.md" >"$RUN/stream-rN.jsonl" 2>"$RUN/err-rN.log"
status=$?
snap rN post
```

## Write calls

Use write mode only after the user has authorized Codex to edit the named scope. Start from a
clean working tree so the resulting diff can be attributed to the call. If the tree contains
work that is not yours, stop and ask. Do not commit, stash, or reset it automatically.

Codex 0.153.4 supports automatic approval review through `--approve-for-me` while retaining
the workspace-write sandbox. The old `--full-auto` flag is unsupported.

```bash
snap build
# Verify "$RUN/pre-build.txt" is empty before continuing.
"$CODEX" "${MCP_ARGS[@]}" exec --sandbox workspace-write --approve-for-me \
  --skip-git-repo-check --json -o "$RUN/build-out.txt" \
  - <"$RUN/spec.md" >"$RUN/stream-build.jsonl" 2>"$RUN/err-build.log"
status=$?
snap build post
BUILD_THREAD=$(grep -m1 '"type":"thread.started"' "$RUN/stream-build.jsonl" \
  | sed 's/.*"thread_id":"\([^"]*\)".*/\1/')
printf 'BUILD_THREAD=%s\n' "$BUILD_THREAD"
```

Do not use `--dangerously-bypass-approvals-and-sandbox`. Network access is outside this
contract. Add it only when the user authorized it and the installed CLI's current help or local
documentation verifies the setting.

A fix round resumes the same thread and forces write scope again. Codex 0.153.4
`exec resume --help` has no `--add-dir`. Setting only `sandbox_mode=workspace-write` on resume
dropped the original extra writable roots in a verified run. If the write task required those
roots, preserve or restore `sandbox_workspace_write.writable_roots` as a JSON array containing
the same originally approved roots plus the approved scratch directory:

```bash
# Default: no extra roots. Read-only reviews must not use write-root overrides.
RESUME_ROOT_ARGS=()
# Only if extra roots were required, set APPROVED_ROOTS_JSON from the recorded authorized
# paths plus approved scratch, then use:
# RESUME_ROOT_ARGS=(-c "sandbox_workspace_write.writable_roots=$APPROVED_ROOTS_JSON")
```

Never invent broader paths, change sandbox mode to bypass a denial, or disable the sandbox.
These roots do not make protected `.git` or `.agents` paths writable. If already-authorized
setup needs those paths, the controller uses ordinary approved session tools within that scope.

Resume with the conditional roots:

```bash
snap fixN
"$CODEX" "${MCP_ARGS[@]}" exec resume "$BUILD_THREAD" -c sandbox_mode="workspace-write" \
  "${RESUME_ROOT_ARGS[@]}" \
  --skip-git-repo-check --json -o "$RUN/fix-outN.txt" \
  - <"$RUN/fixN.md" >"$RUN/stream-fixN.jsonl" 2>"$RUN/err-fixN.log"
status=$?
snap fixN post
```

Cap fix rounds at two. If the result still fails verification, stop delegating and return
control to the caller. Tell Codex not to commit; the caller owns commits.

## Success and failure checks

A round succeeds only when all of these are true:

- the process exit status is zero;
- that round's `-o` file exists and is non-empty;
- the output contains the terminal marker requested by the prompt;
- the post-call tree matches the authorized scope;
- the caller's own verification passes.

Review `git diff --stat`, read each hand-written source change, and run the verification command
yourself. Never reuse an answer from an earlier round.

On failure, keep and inspect the round's `err-*.log`, `stream-*.jsonl`, output file, and snapshots.
Retry a fresh call once with new paths if no thread ID exists. Retry a resume once with the same
explicit thread ID and new paths. After a second failure, stop and report the diagnostics. For an
authentication error or missing binary, report the problem and ask before any login, install, or
configuration change.
