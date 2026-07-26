# claude-upgrade-advisor

**English** · [日本語](./README.ja.md)

A Claude Code plugin that notices when Claude Code or the Claude model lineup
changes, reads the official documentation to find out what actually changed,
and then audits your project's harness and settings against it.

It proposes changes. It never applies them on its own.

---

## Why

Claude Code updates often. Each update can add a setting, add a hook event,
change a default, or ship a new model — and quietly leave your `CLAUDE.md`,
`settings.json`, and `.mcp.json` describing a version that no longer exists.

Asking Claude "what's new?" does not reliably help: the model's training data is
older than the release you are asking about. This plugin fetches the official
docs at the moment you ask, so the answer comes from the docs rather than from
memory.

## What it does

1. **Notices** — a `SessionStart` hook compares the running Claude Code version,
   and the model in use, against what it recorded last time.
2. **Researches** — on request, fetches the official changelog and reference
   pages and reports what changed since your last check.
3. **Audits** — checks your global and project configuration for stale model
   ids, undocumented settings keys, broken hook definitions, overly broad
   permissions, `CLAUDE.md` drift, and MCP misconfiguration.
4. **Proposes** — gives you diffs, ordered by severity, and waits for your
   decision.

## What it does not do

These are guarantees, not aspirations. They are the reason the plugin is safe to
leave installed.

- **It does not edit your configuration.** Every change is a proposal you
  approve first.
- **It does not touch the network during session startup.** The hook is local
  only. Doc fetching happens when *you* run the skill.
- **It does not slow down or break your sessions.** The hook always exits 0.
  If it fails, it fails silently.
- **It does not nag.** Nothing changed means no output at all. Each new version
  and each new model is mentioned exactly once.
- **It does not phone home.** No telemetry. The only network requests are
  fetches of Anthropic's public documentation, made by Claude, visible to you.
- **It does not store credentials.** It reads config files to audit them and
  masks anything credential-shaped before it reaches the conversation.

## Requirements

- Claude Code (`/plugin` available — any reasonably recent version)
- `bash`, and the standard POSIX tools (`sed`, `grep`, `awk`, `date`)
- `jq` is used when present but is **not** required

Tested on macOS. The scripts avoid GNU-only flags and handle both BSD and GNU
`date`, so Linux should work; please open an issue if it does not.

## Install

Installs at **user scope** by default, so it applies across your projects.

```bash
claude plugin marketplace add OzawaG/claude-upgrade-advisor
claude plugin install claude-upgrade-advisor@ozawag-plugins --scope user
```

Or from inside Claude Code:

```
/plugin marketplace add OzawaG/claude-upgrade-advisor
/plugin install claude-upgrade-advisor@ozawag-plugins
```

Then run it once to establish a baseline:

```
/claude-upgrade-advisor:upgrade-check
```

Until you do, the plugin has no record of when you last checked the docs, so it
has nothing to compare against.

### Try it without installing

```bash
git clone https://github.com/OzawaG/claude-upgrade-advisor
claude --plugin-dir ./claude-upgrade-advisor
```

Loads for that session only, and leaves nothing behind except the state
directory described below.

## Usage

### Automatically

When a session starts and something has changed, Claude mentions it once:

> claude-upgrade-advisor noticed a change in this environment. Claude Code was
> 2.1.219 at the last recorded session and is 2.1.220 now.

Then it is up to you whether to look into it. Claude is instructed not to run
the check unprompted.

### On demand

```
/claude-upgrade-advisor:upgrade-check
```

| Argument | Effect |
|---|---|
| *(none)* | Research the docs, then audit your setup |
| `--docs-only` | Report what changed; skip the audit |
| `--audit-only` | Audit the setup; skip the doc research |
| `2.1.180` | Use that version as the comparison baseline |

Reports are written to `<config>/claude-upgrade-advisor/reports/`.

## Uninstall

Three levels, smallest first. Pick the one that matches how annoyed you are.

### 1. Just make it quiet

Keeps everything installed; the hook stops speaking.

```bash
touch "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/claude-upgrade-advisor/disabled"
```

Or set an environment variable in your shell profile:

```bash
export CLAUDE_UPGRADE_ADVISOR_DISABLED=1
```

Undo either by deleting the file or unsetting the variable.

### 2. Remove the plugin

```
/plugin uninstall claude-upgrade-advisor
/plugin marketplace remove ozawag-plugins
```

The plugin stops loading. Its state directory is left in place, so reinstalling
later resumes where you left off.

### 3. Remove everything

```bash
./scripts/uninstall.sh
```

It lists exactly what it will delete, asks for confirmation, deletes it, then
verifies nothing survived. Use `--dry-run` to look first, `--yes` to skip the
prompt.

Because the plugin writes to exactly one directory, this is complete rather
than best-effort — there are no scattered files to miss.

Then do step 2 to remove the plugin itself.

## What it reads and writes

**Reads** (only to audit them):

- `<config>/settings.json`, `settings.local.json`, `CLAUDE.md`
- `<config>/plugins/installed_plugins.json`, `known_marketplaces.json`
- `<config>/skills/`, `<config>/agents/` — names only
- In the current project: `CLAUDE.md`, `.claude/settings*.json`, `.mcp.json`,
  `.claude/hooks/`, `.claude/agents/`, `.claude/skills/`, `.claude/commands/`

`<config>` is `$CLAUDE_CONFIG_DIR`, or `~/.claude` when unset.

**Writes** — one directory, nothing outside it:

```
<config>/claude-upgrade-advisor/
├── state.json        versions and dates already seen
├── seen-models       model ids observed, one per line
├── disabled          create this to silence the hook
└── reports/          audit reports you can delete freely
```

**Credential masking.** Config files often hold API keys. Before any file
content reaches the conversation, values are redacted when the field is *named*
like a credential (`token`, `key`, `secret`, `password`, `auth`, `credential`,
`passphrase`, any case) or the value *looks* like one (`sk-ant-`, `sk-`, `ghp_`,
`github_pat_`, `xoxb-`, `AKIA`, `AIza`, `glpat-`, `Bearer …`, JWTs).

Masking is deliberately over-eager: a harmless field named `apiKeyHelper` gets
redacted too. Losing a little audit detail is the right trade against leaking a
live token. Nothing in this repository contains a credential, and all paths
resolve through environment variables.

## Configuration

All optional, all environment variables.

| Variable | Default | Effect |
|---|---|---|
| `CLAUDE_UPGRADE_ADVISOR_DISABLED` | unset | Any non-empty value silences the hook |
| `CLAUDE_UPGRADE_ADVISOR_STALE_DAYS` | `14` | Days before suggesting a re-check. `0` disables the timer |
| `CLAUDE_UPGRADE_ADVISOR_LANG` | unset | Force the report language. Default is to match yours |
| `CLAUDE_CONFIG_DIR` | `~/.claude` | Honoured for all state, not a plugin setting |

## How the detection works

The hook is intentionally boring, because it runs on the session startup path.

- **CLI version** — from `claude --version`, measured at about 40ms.
- **New model** — `SessionStart` is the only hook event that receives a `model`
  field, and it is optional. A model counts as *new* only if it has never
  appeared in `seen-models`. This is what stops `/model` switching from being
  mistaken for a model release: flipping between models you already use stays
  silent forever.
- **Staleness** — if the docs have not been checked in `STALE_DAYS`, it says so
  at most once per window. Documentation-only changes produce no version bump,
  so this is the net that catches them.

Everything the hook records is a plain file you can read, edit, or delete.

## Development

```bash
claude plugin validate .          # must pass before any release
claude --plugin-dir .             # load without installing
/reload-plugins                   # pick up edits without restarting
```

The hook has a behavioural test suite covering first run, unchanged
environments, version bumps, new models, model switching, both kill switches, a
missing `claude` binary, malformed stdin, and running without `jq`.

Contributions welcome. Please keep the guarantees in [What it does not
do](#what-it-does-not-do) intact — they are the plugin's whole value
proposition.

## Removing this repository

If you cloned or forked it and want it gone, delete your copy. If you are the
owner:

```bash
gh repo delete OzawaG/claude-upgrade-advisor
```

Be aware that a repository which has been public may already have been forked,
cloned, or cached by third parties. Deleting the original does not retract those
copies.

## License

[MIT](./LICENSE)
