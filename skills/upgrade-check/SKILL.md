---
name: upgrade-check
description: Use when Claude Code or the Claude model lineup has changed, when the user asks what is new in Claude, or when they want their Claude setup reviewed against the current release. Reads the official docs, reports what actually changed, then audits this project's harness and settings and proposes fixes.
---

# Claude upgrade check

Report what genuinely changed in Claude, then check whether this environment's
configuration still makes sense in light of it, and propose fixes.

## Rules

1. **Never edit configuration without explicit approval.** Produce diffs and
   wait. The user asked for a diagnosis and a proposal, not an intervention.
2. **Report only what applies to this environment.** A new feature the user
   cannot use, or a setting they do not have, is noise. Completeness is not the
   goal; relevance is.
3. **Match the user's language.** Reply in whatever language they are writing
   in. `CLAUDE_UPGRADE_ADVISOR_LANG` overrides this when set.

## Source rules

These are not preferences. A report that breaks one of them is wrong even if
everything in it happens to be true. `references/doc-sources.md` §0 holds the
full policy; the short form:

**Official only.** Only Anthropic-published sources count: `code.claude.com`,
`platform.claude.com`, `support.claude.com`, `www.anthropic.com`,
`github.com/anthropics`, `api.anthropic.com`. No third-party blog, forum,
newsletter, or video, however good.

**Primary only.** Cite the artifact that *is* the thing, not one describing it.
The changelog owns "which version changed this". The reference page owns "what
this setting does". `/v1/models` outranks any page listing models. Never cite a
weekly digest for a fact the reference page states.

**Evidence required.** Every claim carries a source URL *and* the version or
date it applies to. No URL and no version means the claim does not ship. Write
"I could not verify this" instead, and name the source that failed.

**Your memory is not a source.** Your training data predates the release you are
reporting on. This is the reason the skill exists. If a fetch fails, say the
source was unreachable. Never substitute recollection, and never let a
plausible-sounding recollection round out an otherwise sourced list.

**No credentials, ever.** `/v1/models` is used only when `ANTHROPIC_API_KEY` is
already in the environment. Never ask for a key, never print one, never write
one to a report. Reference it as `$ANTHROPIC_API_KEY` and nothing else. Its
absence is normal for subscription users and is not a finding.

## Arguments

`$ARGUMENTS` may contain:

- *(empty)* — run every phase
- `--docs-only` — phases 1-3, skip the audit
- `--audit-only` — phases 1 and 4-5, skip the doc research
- a version like `2.1.180` — treat that as the baseline to compare against
  instead of whatever is recorded in state

## Phase 1 — Snapshot the environment

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/upgrade-check/scripts/snapshot-env.sh"
```

Credentials come back as `<REDACTED>`. The masking is deliberately
over-eager, so a field named like a secret is blanked even when harmless — if a
redaction hides something you genuinely need for the audit, read that file
directly instead of guessing.

Note the recorded baseline from the snapshot's advisor-state section:
`last_audited_cli_version` and `last_doc_check`. Those define "what is new".
If there is no recorded baseline, use the installed version's release as the
starting point and say that the comparison window is unknown.

## Phase 2 — Read the official docs

Read `references/doc-sources.md` and follow it. Do not work from memory here.

Append `.md` to any docs URL to get raw markdown instead of rendered HTML. It
costs fewer tokens and carries no navigation chrome.

Fetch in this order. Stop early if the earlier sources already answer the
question; each step exists to fill a gap the previous one leaves.

1. **Changelog** (§2) — read from the baseline version to the installed version.
   This establishes which versions are in scope and anchors every later claim to
   a version number.

2. **Weekly digest** (§3) — fetch the index, read each week's version-range tag,
   then fetch **only** the weeks whose range overlaps your baseline → installed
   window. Do not fetch every week.

   The digest trails the changelog. If the newest week stops short of the
   installed version, cover the remainder from the changelog and say the digest
   does not reach that far.

3. **Model pages** (§4) — when a model is new to this environment, read its
   what's-new page for behaviour and breaking changes, and read the deprecations
   table for anything the environment still references.

4. **Reference pages** (§6) — only the pages the changelog entries actually
   touch, plus whatever the audit needs.

5. **`/v1/models`** (§5) — only if `ANTHROPIC_API_KEY` is already set. Skip
   silently otherwise and note that the model list came from the docs instead.

If a source is unreachable, name it in the report and continue with what you
have. A gap you disclose is fine. A gap you paper over is not.

## Phase 3 — Report what changed

Cover, in the user's language:

- **New models** — id, what it is for, context window, pricing, and whether it
  is available on the surfaces the user is on. Flag anything the user currently
  references that is now deprecated or retired, with its retirement date.
- **New and changed Claude Code features** — grouped, not a changelog dump.
  Skip entries that are pure internal bug fixes.
- **Behavioural changes that could bite** — defaults that moved, parameters
  that now error, settings that were renamed.

Every item carries its source URL and the version or date it applies to. An item
without both does not appear.

Put a one-line relevance verdict on each item: does this affect this user, and
why. Drop items where the answer is no.

End the section with the provenance of the report itself: which sources you
fetched, which failed, and what window the comparison covers. The user needs to
know whether they are reading a complete picture or a partial one.

## Phase 4 — Audit the harness

Work through `references/audit-checklist.md` against the Phase 1 snapshot.

**Do not duplicate `/doctor`.** Claude Code ships its own setup checkup
(`/doctor`, alias `/checkup`, added in v2.1.202–v2.1.206) which diagnoses
installation and environment problems and can fix them. This audit answers a
different question: whether the configuration has gone **stale relative to a
release**. Broken install, missing binary, failed auth, unreachable MCP server
belong to `/doctor`. Point the user at it rather than half-reimplementing it.

For each finding, record:

| Field | Requirement |
|---|---|
| Severity | `high` (breaks or will break) / `medium` (degrades quality) / `low` (tidiness) |
| Location | File path, and line where you can pin it |
| Evidence | What you actually observed in their file, quoted |
| Source | The official URL that makes this a problem, plus the version or date it applies to |
| Why | The concrete consequence, not "best practice" |
| Fix | A specific change, as a diff where it is more than one line |

`Evidence` and `Source` are separate obligations. Evidence is what you saw in
the user's configuration. Source is the Anthropic page proving it is wrong. A
finding with only evidence is an observation, not a finding.

Verify before reporting. Confirm a setting key is genuinely deprecated by
checking it against the settings reference you fetched, not by pattern-matching
on how it looks. A confidently wrong finding costs the user more than a missed
one, because it teaches them to distrust the whole report.

Report the count of items checked and found clean too — a user who sees only
problems cannot tell thorough work from a shallow pass.

## Phase 5 — Propose

Order by severity, then by effort. For each proposal give the diff, the reason,
and the risk of applying it.

Then stop and ask which ones to apply. Do not apply anything before the user
answers. If they approve a subset, apply exactly that subset.

## Phase 6 — Record the run

Write the report to
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/claude-upgrade-advisor/reports/<YYYY-MM-DD>-report.md`
and update `state.json` in the same directory, setting:

- `last_doc_check` to today, `YYYY-MM-DD`
- `last_audited_cli_version` to the version you just audited
- `stale_notified_on` to `""`

Preserve the other fields as they were. Getting this wrong means the hook nags
again next session, or goes quiet when it should not.

Tell the user where the report landed and remind them the whole directory is
removable — `scripts/uninstall.sh` in the plugin, or the Uninstall section of
the README.
