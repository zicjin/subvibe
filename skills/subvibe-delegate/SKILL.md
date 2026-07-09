---
name: subvibe-delegate
description: Delegate a well-scoped subtask (scaffolding, test generation, migrations, bulk reads, boilerplate) to a cheaper subagent CLI (Grok Build by default; Antigravity/agy available) under cost discipline, then verify the result. Use when the offloaded volume clearly exceeds the spec + verification overhead.
---

Delegate the task via the `subvibe-delegate` wrapper, following the **Cost
discipline** and **Verification gates** in the plugin's delegation policy
(injected at session start; also at `docs/AGENTS-snippet.md` in the plugin root,
two directories above this SKILL.md).

The wrapper lives at `<plugin-root>/scripts/subvibe-delegate.sh` (plugin root =
two directories above this SKILL.md; `subvibe-delegate` below means that script).
Default executor is **Grok Build (`grok`)**; use `--driver agy` or
`SUBVIBE_DRIVER=agy` for the Antigravity CLI.

Do this:
1. Pick a thinking level (`medium` default; `low` for trivial; `high` for harder reasoning).
   If the task needs the repo, add `--dir <repo-root>` so the executor reads the real files
   (don't paste them into context).
   **If the task WRITES files or uses tools** (implement / scaffold / test-gen /
   migrate / fix, or web / Vertex AI Search) **add `--yolo`** — without it, a headless
   executor may only *describe* the edits and return a confident "done" **while writing nothing**.
   Run write tasks on a dedicated branch (+ `--sandbox`). Your own sandbox may block
   the command — if the shell call is denied, request approval / escalated
   permissions for `subvibe-delegate`.
2. Run **synchronously** (you may be headless — `codex exec` / `claude -p` — do not
   background-and-wait):
   `subvibe-delegate --tier <tier> [--dir .] [--yolo] [--digest] "<task>"`
   For read/analysis tasks, add `--digest` — it appends a digest-only output
   contract so the executor returns compact bullets instead of raw content.
   Compose the task text per the `subvibe-prompting` skill: operator-style,
   XML-block prompt with an explicit output contract and follow-through defaults.
   For a follow-up on the same thread, use `--continue` and send only the delta
   instruction — don't restate the whole prompt.
3. Ingest only the **result/digest** — do NOT re-read the files the executor already handled
   (keeps your context lean; that's where the cost savings come from). If the
   wrapper prints a *"looks like a raw dump"* note on stderr, do NOT ingest the raw
   output — re-run with `--digest` or ask the executor to summarize it first.
4. Structured failures: exit `10` quota · `11` auth · `12` timeout · `13` CLI
   missing (plus `2` failed / `3` empty), with an `SUBVIBE_SIGNAL {...}` line on
   stderr — react to the code instead of scraping prose.
5. **Verify**: actually run/check the output; never trust a self-reported "done".
   Report what you delegated and how you verified it. If the run failed or
   returned nothing, report the failure (with the most actionable stderr lines) —
   don't silently substitute your own answer for the delegated one; tell the user
   before doing the work yourself.

Remember the break-even: only delegate if the offloaded volume clearly exceeds the
spec + round-trip + verification overhead. Tiny tasks are cheaper to just do
yourself.

**Long task, interactive session?** A long sync delegation can hit the shell-tool
time limit — start it in the background and keep working:
`ID=$(subvibe-job start --tier high --dir . "<task>")`
then check with `subvibe-job status "$ID"` and collect with `subvibe-job result "$ID"`
(see the `subvibe-jobs` skill). Don't do this when YOU are headless (`codex exec` / `claude -p`) —
one-shot, no later turn to collect; delegate synchronously there.
