#!/usr/bin/env bash
#
# claude-upgrade-advisor -- SessionStart hook
#
# Contract this script must never violate:
#   1. It never touches the network.
#   2. It prints nothing at all when nothing has changed.
#   3. It always exits 0, so a bug in here can never block session startup.
#
# It watches for three signals:
#   a. the Claude Code CLI version changed since the last recorded session
#   b. a model id we have never seen before is in use
#   c. the official docs have not been checked for a while
#
# It speaks at most once per new CLI version and once per never-before-seen
# model, so ignoring it does not turn into nagging.

set -u

# Any failure below is non-fatal by design: a broken advisor must not cost
# the user their session.
trap 'exit 0' EXIT

# --------------------------------------------------------------- kill switches
# Documented escape hatch #1: an environment variable.
if [ -n "${CLAUDE_UPGRADE_ADVISOR_DISABLED:-}" ]; then
  exit 0
fi

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
state_dir="$config_dir/claude-upgrade-advisor"
state_file="$state_dir/state.json"
seen_models_file="$state_dir/seen-models"

# Documented escape hatch #2: a marker file next to the state.
if [ -e "$state_dir/disabled" ]; then
  exit 0
fi

stale_days="${CLAUDE_UPGRADE_ADVISOR_STALE_DAYS:-14}"
case "$stale_days" in
  '' | *[!0-9]*) stale_days=14 ;;
esac

# ------------------------------------------------------------------- utilities

# Read one top-level string field out of a JSON blob.
# Uses jq when present, falls back to grep/sed so that jq is never a
# requirement for people installing this plugin.
json_get() {
  _field="$1"
  _json="$2"
  [ -z "$_json" ] && return 0
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$_json" | jq -r --arg f "$_field" '.[$f] // empty' 2>/dev/null
    return 0
  fi
  printf '%s' "$_json" \
    | tr -d '\n' \
    | grep -o "\"$_field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed 's/.*:[[:space:]]*"\([^"]*\)"$/\1/'
}

# Escape a string for embedding in a JSON string literal.
json_escape() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk 'BEGIN { ORS = "" } { print (NR > 1 ? "\\n" : "") $0 }'
}

# Whole days elapsed since a YYYY-MM-DD date. Prints nothing if unparseable.
# Handles both BSD/macOS date and GNU date.
days_since() {
  _date="$1"
  [ -z "$_date" ] && return 0
  _then=""
  if _then="$(date -j -f "%Y-%m-%d" "$_date" +%s 2>/dev/null)"; then
    :
  elif _then="$(date -d "$_date" +%s 2>/dev/null)"; then
    :
  else
    return 0
  fi
  [ -z "$_then" ] && return 0
  _now="$(date +%s 2>/dev/null)" || return 0
  echo $(( (_now - _then) / 86400 ))
}

today="$(date +%Y-%m-%d 2>/dev/null || true)"

# ------------------------------------------------------------------ hook input
# SessionStart is the only hook event that carries `model`, and the field is
# optional -- so everything below has to work when it is absent.
# There is no $CLAUDE_MODEL environment variable to fall back to.
hook_input=""
if [ ! -t 0 ]; then
  hook_input="$(cat 2>/dev/null || true)"
fi
model="$(json_get model "$hook_input" 2>/dev/null || true)"

# --------------------------------------------------------------- current state
# Measured at ~40ms on a native install, which is acceptable on the session
# startup path. Failure just leaves this empty.
cli_version="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"

# Nothing observable means nothing to say.
if [ -z "$cli_version" ] && [ -z "$model" ]; then
  exit 0
fi

# -------------------------------------------------------------- previous state
prev_json=""
if [ -f "$state_file" ]; then
  prev_json="$(cat "$state_file" 2>/dev/null || true)"
fi

prev_cli="$(json_get last_seen_cli_version "$prev_json")"
notified_cli="$(json_get notified_for_cli_version "$prev_json")"
last_doc_check="$(json_get last_doc_check "$prev_json")"
last_audited="$(json_get last_audited_cli_version "$prev_json")"
stale_notified_on="$(json_get stale_notified_on "$prev_json")"

# Persist state. Written via a temp file so an interrupted session cannot
# leave a truncated state.json behind.
write_state() {
  mkdir -p "$state_dir" 2>/dev/null || return 0
  _tmp="$state_file.tmp.$$"
  cat > "$_tmp" 2>/dev/null <<EOF || { rm -f "$_tmp" 2>/dev/null; return 0; }
{
  "schema_version": 1,
  "last_seen_cli_version": "$cli_version",
  "notified_for_cli_version": "$notified_cli",
  "last_doc_check": "$last_doc_check",
  "last_audited_cli_version": "$last_audited",
  "stale_notified_on": "$stale_notified_on"
}
EOF
  mv -f "$_tmp" "$state_file" 2>/dev/null || rm -f "$_tmp" 2>/dev/null
}

remember_model() {
  [ -z "$model" ] && return 0
  mkdir -p "$state_dir" 2>/dev/null || return 0
  printf '%s\n' "$model" >> "$seen_models_file" 2>/dev/null || true
}

model_is_new() {
  # A model counts as new only if it has never been observed before. This is
  # what keeps `/model` switching from being mistaken for a model release:
  # flipping back and forth between known models stays silent forever.
  [ -z "$model" ] && return 1
  [ ! -f "$seen_models_file" ] && return 0
  grep -qxF "$model" "$seen_models_file" 2>/dev/null && return 1
  return 0
}

# ------------------------------------------------------------------- first run
# Installing the plugin is not a version bump. Seed the state, stay quiet.
# last_doc_check is seeded with the install date so the staleness timer starts
# from installation rather than from the epoch.
if [ ! -f "$state_file" ]; then
  notified_cli="$cli_version"
  last_doc_check="$today"
  last_audited=""
  stale_notified_on=""
  write_state
  remember_model
  exit 0
fi

# ----------------------------------------------------------------- what's new?
notify=0
cli_changed=0
model_changed=0
stale=0

if [ -n "$cli_version" ] \
  && [ "$cli_version" != "$prev_cli" ] \
  && [ "$cli_version" != "$notified_cli" ]; then
  cli_changed=1
  notify=1
fi

if model_is_new; then
  model_changed=1
  notify=1
fi

if [ "$stale_days" -gt 0 ]; then
  days="$(days_since "$last_doc_check")"
  if [ -n "$days" ] && [ "$days" -ge "$stale_days" ]; then
    # Only raise staleness once per stale_days window. Without this, a user who
    # ignores the nudge would be told again every single session.
    since_nag="$(days_since "$stale_notified_on")"
    if [ -z "$stale_notified_on" ] \
      || { [ -n "$since_nag" ] && [ "$since_nag" -ge "$stale_days" ]; }; then
      stale=1
      notify=1
    fi
  fi
fi

# Record what we have seen regardless of whether we speak up, so that the
# next session compares against reality.
remember_model

if [ "$notify" -eq 0 ]; then
  write_state
  exit 0
fi

# ------------------------------------------------------------------- speak up
# Phrased as factual statements about the environment, per the hooks reference
# guidance on additionalContext. The hook reports observations only; it does no
# diagnosis of its own.
msg="claude-upgrade-advisor noticed a change in this environment."

if [ "$cli_changed" -eq 1 ]; then
  msg="$msg Claude Code was ${prev_cli:-unknown} at the last recorded session and is $cli_version now."
fi

if [ "$model_changed" -eq 1 ]; then
  msg="$msg The model $model has not been seen in this environment before."
fi

if [ "$stale" -eq 1 ]; then
  msg="$msg The official documentation was last checked on ${last_doc_check:-an unknown date} (${days:-?} days ago)."
fi

msg="$msg The /claude-upgrade-advisor:upgrade-check skill reports what actually changed in the official docs and audits this project's harness and settings against it. Mention this to the user once, briefly, and let them decide whether to run it -- do not run it unprompted."

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$(json_escape "$msg")"

# Mark as notified so the same version and model never speak twice.
notified_cli="$cli_version"
if [ "$stale" -eq 1 ]; then
  stale_notified_on="$today"
fi
write_state

exit 0
