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
2. **Every finding cites evidence.** A file path, a line, a doc URL. A finding
   you cannot ground in something you actually read does not get reported.
3. **Report only what applies to this environment.** A new feature the user
   cannot use, or a setting they do not have, is noise. Completeness is not the
   goal; relevance is.
4. **Match the user's language.** Reply in whatever language they are writing
   in. `CLAUDE_UPGRADE_ADVISOR_LANG` overrides this when set.
5. **Say when you do not know.** If a doc fetch fails, say which source was
   unreachable rather than filling the gap from memory. Your training data is
   older than the release you are reporting on — that is the entire reason this
   skill exists.

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

Fetch the changelog first — it is the densest source and tells you which
versions to care about. Then fetch only the reference pages that the changelog
entries actually touch. Fetching all of them every run is waste.

If a source is unreachable, note it and continue with what you have.

## Phase 3 — Report what changed

Cover, in the user's language:

- **New models** — id, what it is for, context window, pricing, and whether it
  is available on the surfaces the user is on. Flag anything the user currently
  references that is now deprecated or retired, with its retirement date.
- **New and changed Claude Code features** — grouped, not a changelog dump.
  Skip entries that are pure internal bug fixes.
- **Behavioural changes that could bite** — defaults that moved, parameters
  that now error, settings that were renamed.

Put a one-line relevance verdict on each item: does this affect this user, and
why. Drop items where the answer is no.

## Phase 4 — Audit the harness

Work through `references/audit-checklist.md` against the Phase 1 snapshot.

For each finding, record:

| Field | Requirement |
|---|---|
| Severity | `high` (breaks or will break) / `medium` (degrades quality) / `low` (tidiness) |
| Location | File path, and line where you can pin it |
| Evidence | What you actually observed, quoted |
| Why | The concrete consequence, not "best practice" |
| Fix | A specific change, as a diff where it is more than one line |

Verify before reporting. Confirm a setting key is genuinely deprecated by
checking it against the settings reference you fetched, not by pattern-matching
on how it looks. A confidently wrong finding costs the user more than a missed
one.

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
