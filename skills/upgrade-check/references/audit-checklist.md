# Harness audit checklist

Work through every section. Report what you checked and found clean, not only
what you found broken — otherwise the user cannot distinguish a thorough audit
from a shallow one.

Ground each finding in the reference pages fetched during Phase 2. Do not
declare a key deprecated because it *looks* old.

---

## A. Stale model references

Where to look: `CLAUDE.md` (both global and project), `settings.json`,
`.mcp.json`, `agents/*.md` frontmatter, and any source code in the project that
names a model.

| Check | Severity if hit |
|---|---|
| A model id that is **retired** — requests will fail outright | high |
| A model id that is **deprecated** with a retirement date | high |
| A model id that does not exist at all, e.g. a typo or an invented name | high |
| A dated snapshot id where a current dateless id exists | low |
| Prose in `CLAUDE.md` naming an old model as "the latest" | medium |
| `temperature`, `top_p`, or `top_k` set to a non-default value in code targeting Claude 4.7+ — returns HTTP 400 | high |

Check against the deprecations table, not from memory. Report the retirement
date and the recommended replacement for every hit.

## B. Settings keys

Where to look: global `settings.json`, global `settings.local.json`, project
`.claude/settings.json`, project `.claude/settings.local.json`.

| Check | Severity if hit |
|---|---|
| A key that no longer appears in the settings reference | medium |
| A key that was renamed, still using the old name | medium |
| A key set to a value outside its documented range | medium |
| A key duplicated between global and project scope with conflicting values | medium |
| Malformed JSON, or a trailing comma | high |
| A setting pinning a model that section A flagged | high |

When a key is absent from the reference, say so plainly — "not documented in the
current settings reference" — rather than asserting it was removed. Unknown keys
are silently ignored by Claude Code, so the consequence is that the setting
does nothing.

## C. Hooks

Where to look: `.claude/settings.json` hooks block, `.claude/hooks/hooks.json`,
plugin `hooks/hooks.json`, and the scripts they invoke.

| Check | Severity if hit |
|---|---|
| A hook event name that is not in the hooks reference — silently never fires | high |
| A hook script that can exit non-zero and block the session | high |
| A `SessionStart` or `UserPromptSubmit` hook that makes a network call — adds latency to every session | medium |
| No `timeout` on a hook that could hang | medium |
| A hook writing to paths outside a directory it owns | medium |
| A `matcher` that never matches anything | medium |
| A hook whose output is not valid JSON when it claims to emit JSON | high |
| A hook depending on `jq` without checking it exists | low |

Cross-check event names against the fetched hooks reference. The set of events
grows between releases, so a name absent from your memory may well be valid.

## D. Permissions

Where to look: the `permissions` block in every settings file.

| Check | Severity if hit |
|---|---|
| `Bash(*)` or equivalent blanket allow | high |
| An allow rule permitting an irreversible command — `rm -rf`, `git push --force`, `DROP TABLE` | high |
| A wildcard broader than the comment beside it suggests | medium |
| A deny rule shadowed by an earlier, broader allow | medium |
| Secrets or credential paths readable with no deny rule | high |
| Rules using a syntax the current reference does not document | medium |

State the concrete risk. "Overly broad" alone is not a finding; "this allows
`rm -rf` on any path with no confirmation" is.

## E. CLAUDE.md health

Where to look: global and project `CLAUDE.md`, and any imported files.

| Check | Severity if hit |
|---|---|
| Two instructions that contradict each other | high |
| An instruction referencing a tool, flag, or feature that no longer exists | medium |
| A rule that restates default behaviour and only consumes context | low |
| Large enough to crowd out working context — flag past roughly 400 lines and say why | medium |
| Content that belongs in a skill because it applies to one task, not all | low |
| A stated fact that has since become false, e.g. a version or a model claim | medium |

Quote the specific lines. A vague "this file is too long" is not actionable.

## F. MCP servers

Where to look: `.mcp.json` at project root, and any MCP config in settings.

| Check | Severity if hit |
|---|---|
| A credential committed in plaintext rather than referenced from the environment | high |
| A server whose command or package does not resolve | medium |
| A server configured but demonstrably unused | low |
| A configuration shape the current MCP reference does not document | medium |
| An `.mcp.json` at `~/.claude/.mcp.json` — that path is not read | medium |

The snapshot masks credential values, so absence of a visible secret is not
proof of absence. If a value came back `<REDACTED>`, check whether the field
should have been an environment reference instead of a literal.

## G. Skills and agents

Where to look: `skills/*/SKILL.md`, `.claude/skills/`, `agents/*.md`.

| Check | Severity if hit |
|---|---|
| A `description` that does not state *when* to use the skill — it will not trigger | medium |
| Two skills with descriptions that overlap enough to be ambiguous | medium |
| Frontmatter fields the skills reference does not document | low |
| A skill body long enough that it should use progressive disclosure | low |
| An agent naming a model flagged in section A | high |
| A project agent silently shadowing a plugin agent of the same name | low |

A `description` is a routing decision, not a summary. "Reviews code" will not
fire; "Use when reviewing a pull request or checking code quality before merge"
will.

## H. Features worth adopting

This is the other half of the audit: not what is broken, but what the release
made available that this setup is not using.

For each item the changelog surfaced, ask whether it would concretely help
*this* environment. Report only where the answer is yes, with the reason.

Do not recommend a feature merely because it is new. A recommendation the user
has no use for is worse than silence — it teaches them to skim your reports.
