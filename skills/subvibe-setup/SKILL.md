---
name: subvibe-setup
description: Verify subagent CLIs (Grok Build and/or Antigravity) are installed and authenticated and the subvibe tooling is ready to use. Use when setting up, or when delegations fail with auth/missing errors.
---

Run the plugin's doctor and report status.

Run: `<plugin-root>/scripts/doctor.sh` (plugin root = two directories above this
SKILL.md).

Then summarize for the user:
- Which drivers are available? Default is `grok` (`SUBVIBE_DRIVER` / `--driver`).
- Is `grok` installed and authenticated (`grok login` / `XAI_API_KEY`)?
- Is `agy` installed and able to list models (optional; only required if using
  `--driver agy`)?
- Are the plugin scripts executable?
- Any env remaps in play (`GROK_TIER_*`, `AGY_TIER_*`, `SUBVIBE_DEFAULT_MODEL`)?

If anything is missing or failing, give the **exact** command to fix it (install
the CLI, authenticate, `chmod +x` the scripts, etc.). Keep it short and actionable.
