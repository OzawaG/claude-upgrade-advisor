# Official documentation sources

Every URL in this file was fetched and confirmed reachable on 2026-07-27.

Doc URLs rot. When one fails, do not guess a replacement. Go to the relevant
index (§1) and find the current path, then fix this file so the next run does
not repeat the lookup.

---

## 0. Source policy

Three rules govern what may enter a report. They are not preferences.

### Rule 1 — Official only

A source qualifies only if Anthropic publishes it. That means these hosts and
nothing else:

| Host | What it carries |
|---|---|
| `code.claude.com` | Claude Code documentation |
| `platform.claude.com` | API, models, SDK documentation |
| `support.claude.com` | Claude apps help centre and release notes |
| `www.anthropic.com` | Announcements, research, engineering posts |
| `github.com/anthropics` | Source repositories and `CHANGELOG.md` |
| `api.anthropic.com` | The API itself |

Anything else is out, whatever its reputation. A well-researched third-party
post is still not a source.

### Rule 2 — Primary only

Prefer the artifact that **is** the thing over any artifact that *describes*
it. When both exist, the description does not get cited.

Precedence by question, highest first:

| Question | Primary source |
|---|---|
| Which models exist right now, with what capabilities | `/v1/models` (§5), then models overview (§4) |
| What changed in a Claude Code version | `CHANGELOG.md` (§2) |
| Why a Claude Code change matters, with examples | Weekly digest (§3) |
| What a setting or hook does now | Its reference page (§6) |
| What a model's behaviour change breaks | That model's what's-new page (§4) |
| When a model dies | Model deprecations (§4) |
| What changed in the API or SDKs | Platform release notes (§4) |

Never cite the weekly digest for a fact the reference page states, and never
cite an announcement post for a fact the changelog states.

### Rule 3 — Evidence required

Every claim in a report carries:

1. the source URL it came from, and
2. the version or date it applies to.

A claim you cannot attach both to does not go in the report. Say "I could not
verify this" instead. That is a useful sentence; a confident guess is not.

**Your own memory is not a source.** Your training data predates the release
being reported on. That is the reason this skill exists. If a fetch fails, the
answer is "the source was unreachable", never a recollection.

### Excluded, and why

Recorded so nobody re-litigates it.

| Excluded | Reason |
|---|---|
| X posts, including [@AnthropicAI](https://x.com/AnthropicAI) | Official and primary, but `x.com` returns **HTTP 402 Payment Required** to unauthenticated fetches (verified 2026-07-27 against that exact URL), so it cannot be read programmatically at all. Content is announcement-level with no version numbers. Every fact in it reaches the docs with evidence attached. Anthropic's own site footer links `@AnthropicAI`, LinkedIn, and YouTube, and lists no separate Claude Code account. A human may read it to learn *that* something shipped, then verify *what* shipped here |
| YouTube, LinkedIn, Discord | Not primary technical sources; no versioned claims |
| Third-party blogs, Reddit, Hacker News, Medium, newsletters | Fails Rule 1 |
| The model's own recollection | Fails Rule 3 |
| Anthropic marketing and news posts | Official, but usually secondary to a doc page. Cite only when no doc page covers the fact, and label it as an announcement |

---

## 1. Indexes — start here when a URL fails

```
https://code.claude.com/docs/llms.txt          Claude Code docs index
https://platform.claude.com/docs/llms.txt      API and models docs index
```

Machine-readable lists of every page. Cheaper and more reliable than searching.

**Append `.md` to any docs URL** to get raw markdown instead of rendered HTML.
Fewer tokens, no navigation chrome. Both indexes list the `.md` form. Use it.

## 2. Claude Code changelog — read this first

```
https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md
https://code.claude.com/docs/en/changelog.md          (same content, docs-hosted)
```

Per-version entries, newest first. The only source that says *which version*
introduced a thing, so it anchors everything else.

Read from the baseline version up to the installed version. Anything below the
baseline is already known and is not news.

## 3. Weekly digest — why the changes matter

```
https://code.claude.com/docs/en/whats-new/index.md      Index of all weeks
https://code.claude.com/docs/en/whats-new/2026-w29.md   A single week
```

Anthropic's curated weekly summary, with code snippets and rationale. Where the
changelog says *what*, this says *why it matters*.

**Each week is tagged with the version range it covers.** Use those tags to
select weeks:

1. Fetch the index once.
2. Read each week's version-range tag.
3. Fetch only the weeks whose range overlaps baseline → installed.

Fetching every week is waste. Fetching by tag is exact.

The range appears in two formats depending on the page, both meaning the same
thing. Match either:

- On the index: `tags={["v2.1.207–v2.1.212"]}` (en dash)
- On a week page: `Releases v2.1.207 → v2.1.212` (arrow)

Each week page also links the matching changelog section by anchor, for example
`/docs/en/changelog#2-1-207`. Follow it when a digest entry is too summarised and
you need the per-version wording.

A week page carries more than the index shows: two or three highlighted features
with runnable snippets, plus an "Other wins" grid listing new settings and
environment variables. That grid is where most audit-relevant additions appear,
so read it rather than stopping at the index blurb.

**Known lag.** The digest trails the changelog by a week or more. At the time of
writing, the newest week covered up to `v2.1.212` while `2.1.220` had shipped.
Cover the tail with §2 and say so rather than implying the digest is complete.

## 4. Models, API, and platform

Host: `https://platform.claude.com/docs/en/`

| Page | Path (append `.md`) | Fetch when |
|---|---|---|
| Models overview | `about-claude/models/overview` | Reporting models. Ids, context windows, pricing, legacy section |
| Model deprecations | `about-claude/model-deprecations` | **Always when auditing.** Authoritative retired/deprecated table with dates |
| What's new in a model | `about-claude/models/whats-new-opus-5`, `…whats-new-sonnet-5` | A model is new to this environment. Carries **behaviour changes and breaking changes** |
| Model ids and versioning | `about-claude/models/model-ids-and-versions` | Judging whether an id is a pinned snapshot or an alias |
| Migration guide | `about-claude/models/migration-guide` | The user is on a model with a newer replacement |
| Platform release notes | `release-notes/overview` | Auditing API or SDK usage, not just the CLI |
| Published system prompts | `release-notes/system-prompts` | Behaviour changed and no doc explains it |
| Pricing | `about-claude/pricing` | Cost claims, introductory-pricing caveats |

## 5. The API itself — optional, opt-in

```
GET https://api.anthropic.com/v1/models
```

The most authoritative model list that exists, because it is the API answering
for itself rather than a page describing it. Returns per-model `id`,
`display_name`, `created_at`, `max_input_tokens`, `max_tokens`, and a
`capabilities` object covering thinking types, effort levels, batch, citations,
structured outputs, and context management.

**Requires an API key**, so it is off by default.

Use it **only** when `ANTHROPIC_API_KEY` is already set in the environment. Then:

```bash
curl -s https://api.anthropic.com/v1/models \
  -H 'anthropic-version: 2023-06-01' \
  -H "X-Api-Key: $ANTHROPIC_API_KEY"
```

Rules, without exception:

- Never ask the user for a key. If it is unset, skip this source and say so.
- Never print, log, echo, or write the key anywhere, including reports.
- Reference it as `$ANTHROPIC_API_KEY` only. Never inline the value.
- Subscription users normally have no key. Its absence is expected, not a fault.

## 6. Claude Code reference pages

Host: `https://code.claude.com/docs/en/` — append `.md`.

Fetch a page when the changelog touched it, or when the audit needs it. Do not
fetch all of them every run.

**Configuration**

| Page | Path |
|---|---|
| Settings reference | `settings` |
| Environment variables | `env-vars` |
| The `.claude` directory | `claude-directory` |
| Model configuration | `model-config` |
| Config troubleshooting | `debug-your-config` |

**Security**

| Page | Path |
|---|---|
| Permissions | `permissions` |
| Permission modes | `permission-modes` |
| Security | `security` |
| Security guidance | `security-guidance` |
| Sandboxing | `sandboxing` |

**Extensibility**

| Page | Path |
|---|---|
| Hooks reference | `hooks` |
| Hooks guide | `hooks-guide` |
| Skills | `skills` |
| Subagents | `sub-agents` |
| MCP | `mcp` |
| Plugins reference | `plugins-reference` |
| Plugin dependencies | `plugin-dependencies` |

**Context and cost**

| Page | Path |
|---|---|
| Memory and `CLAUDE.md` | `memory` |
| Context window | `context-window` |
| Costs | `costs` |
| Feature availability by platform | `feature-availability` |

## 7. Claude apps release notes

```
https://support.claude.com/en/articles/12138966-release-notes
```

Covers claude.ai, Desktop, and mobile. Relevant when the user works across
surfaces; not needed for a CLI-only audit.

## 8. Fallback

`WebSearch`, restricted to the Rule 1 hosts via `allowed_domains`. For gaps the
indexes cannot fill, such as a very recent announcement. A search result never
overrides a reference page.

---

## Verified facts as of 2026-07-27

Recorded so drift is easy to spot. **Re-verify before reporting any of it as
current.** This section is a baseline, not an answer.

- Claude Code CLI: `2.1.220`, released July 25 2026 ("bug fixes and reliability
  improvements")
- `2.1.219`, July 24 2026, made Claude Opus 5 the default Opus, added the
  `sandbox.network.strictAllowlist` setting and the `DirectoryAdded` hook
- Current models: `claude-fable-5`, `claude-opus-5`, `claude-sonnet-5`,
  `claude-haiku-4-5-20251001`
- `claude-opus-5`: 1M context, 128k max output, $5/$25 per MTok, thinking on by
  default. Retirement not sooner than 2027-07-24
- **Breaking change on Opus 5**: `thinking: {"type": "disabled"}` with effort
  `xhigh` or `max` returns HTTP 400. Allowed at `high` and below
- Deprecated: `claude-opus-4-1-20250805`, retires 2026-08-05, replace with
  `claude-opus-4-8`
- Retired: `claude-opus-4-20250514`, `claude-sonnet-4-20250514`,
  `claude-3-7-sonnet-20250219`, `claude-3-5-haiku-20241022`,
  `claude-3-haiku-20240307`, and everything older
- `temperature`, `top_p`, `top_k` return HTTP 400 on Claude 4.7 and later when
  set to a non-default value
- Model ids from the 4.6 generation onward are dateless but still pinned
  snapshots, not evergreen pointers
- Hooks reference documents 31 hook events. `model` is supplied to `SessionStart`
  only, and is optional
- `docs.claude.com` 302-redirects to `platform.claude.com`. Use the new host
