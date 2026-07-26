# Official documentation sources

Every URL below was fetched and confirmed reachable on 2026-07-27.

Doc URLs rot. When one 404s, do not guess a replacement — go to the index
(§1) and find the current path, then fix this file so the next run does not
repeat the lookup.

## 1. Start here: the documentation index

```
https://code.claude.com/docs/llms.txt
```

A machine-readable index of every Claude Code documentation page. Fetch this
when a URL below fails, or when you need a page not listed here. It is cheaper
and more reliable than searching.

## 2. The changelog — read this first

```
https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md
```

Per-version list of what changed in Claude Code, newest first. This is the
densest and most authoritative source for "what is new", and it is the only one
that tells you *which version* introduced a thing.

Read from the baseline version up to the installed version. Everything below the
baseline is already known.

## 3. Claude Code reference pages

Host: `https://code.claude.com/docs/en/`

| Page | Path | Fetch when |
|---|---|---|
| Settings reference | `settings` | The changelog mentions a setting, or you are auditing `settings.json` |
| Hooks reference | `hooks` | The changelog mentions a hook event, or you are auditing hooks |
| Skills | `skills` | Auditing skills or `SKILL.md` frontmatter |
| Subagents | `sub-agents` | Auditing `agents/` definitions |
| MCP | `mcp` | Auditing `.mcp.json` |
| Plugins (authoring) | `plugins` | Auditing or authoring a plugin |
| Plugins reference | `plugins-reference` | You need the exact manifest schema |
| Plugin marketplaces | `plugin-marketplaces` | Distribution questions |
| Discover plugins | `discover-plugins` | Install and trust questions |

## 4. Model and API pages

Host: `https://platform.claude.com/docs/en/`

Note: `docs.claude.com` 302-redirects to `platform.claude.com`. Use the new
host directly; a redirect costs an extra round trip.

| Page | Path | Fetch when |
|---|---|---|
| Models overview | `about-claude/models/overview` | Always, when reporting new models. Has ids, context windows, pricing, and a legacy-models section |
| Model deprecations | `about-claude/model-deprecations` | Always, when auditing. Authoritative deprecated/retired table with retirement dates |
| Migration guide | `about-claude/models/migration-guide` | The user is on a model that has a newer replacement |
| Pricing | `about-claude/pricing` | Cost questions, or introductory-pricing caveats |

## 5. Fallback

`WebSearch` — only for gaps the above cannot fill, such as an announcement post
that has not reached the reference docs. Prefer `anthropic.com`,
`platform.claude.com`, and `code.claude.com` results. Never let a search result
override a reference page.

## Known facts as of 2026-07-27

Recorded so a future run can spot drift quickly. **Re-verify these; do not
report them as current without checking.**

- Latest Claude Code CLI at time of writing: `2.1.220`
- Current models: `claude-fable-5`, `claude-opus-5`, `claude-sonnet-5`,
  `claude-haiku-4-5-20251001`
- `claude-opus-5` became the default Opus in CLI 2.1.219, 1M context
- Deprecated: `claude-opus-4-1-20250805`, retires 2026-08-05
- Retired already: `claude-opus-4-20250514`, `claude-sonnet-4-20250514`,
  `claude-3-7-sonnet-20250219`, `claude-3-5-haiku-20241022`,
  `claude-3-haiku-20240307`, and everything older
- `temperature`, `top_p`, `top_k` return HTTP 400 on Claude 4.7 and later when
  set to a non-default value
- Model ids from the 4.6 generation onward are dateless but still pinned
  snapshots, not evergreen pointers
