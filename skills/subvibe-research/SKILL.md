---
name: subvibe-research
description: Conductor-orchestrated deep research — a cheap subagent CLI does the grounded web legwork; the conductor agent plans, verifies the citations, and synthesizes. Use for multi-source research questions that need cited findings.
---

Run a multi-source research pass, following the **Verification gates** of the
plugin's delegation policy. The executor CLI (default `grok`; or `agy` with
`--driver agy`) is the cheap, grounded search worker; **you (the conductor) own
the plan, the verification, and the synthesis**. Print-mode citations can be
coarse (often domain-level) and models can present parametric "knowledge" as a
sourced fact — so never ship citations unchecked.

Use the wrapper at `<plugin-root>/scripts/subvibe-delegate.sh` (plugin
root = two directories above this SKILL.md). If the topic is unclear, ask the user
what to research before starting.

Do this:
1. **Plan (you).** Break the topic into 3–6 sub-questions and list the load-bearing
   claims that must be verified. You own scope and final synthesis.
2. **Fan-out fetch (executor, cheap, one call per sub-question).** Web search needs
   `--yolo` in headless mode; force compact output so bulky pages stay on the
   executor's side, not yours:
   `subvibe-delegate --tier medium --yolo "Web-search <sub-question>. Return 5–8 bullet findings, each with the exact source URL and publication date. Output ONLY findings + URLs + dates."`
3. **Deepen on each load-bearing claim (executor).** Name the URL and have it quote the
   supporting sentence(s), turning domain-level citations into verifiable quotes:
   `subvibe-delegate --tier high --yolo "Open <URL> and quote the exact sentence(s) supporting: '<claim>'. If the page does not support it, reply NOT SUPPORTED."`
4. **Adversarially verify (you).** Corroborate each key claim across ≥2 independent
   domains; treat any single / vague / domain-only citation as unverified;
   sanity-check dates; watch for parametric knowledge posing as a sourced fact.
5. **Synthesize (you).** Write a cited report from verified findings only;
   explicitly mark anything uncorroborated as "unverified".

Keep your own context lean — ingest the executor's bullet digests, not the raw pages
(that's where the cost savings come from). `--print` does one agentic pass per call,
so re-dispatch follow-up calls to close gaps rather than expecting auto-iteration.
In an interactive session a long fetch can be backgrounded with `subvibe-job`; when
**you** are headless (`codex exec` / `claude -p`), delegate synchronously.
