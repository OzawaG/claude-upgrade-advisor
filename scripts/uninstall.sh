#!/usr/bin/env bash
#
# claude-upgrade-advisor -- remove every trace of this plugin's own data.
#
# This plugin confines all of its writes to a single directory, so removal is
# exact rather than best-effort. This script shows you what it will delete,
# asks, deletes it, then verifies nothing survived.
#
# It does not uninstall the plugin itself -- that is Claude Code's job, and the
# command is printed at the end.
#
# Usage:
#   ./scripts/uninstall.sh           # ask before deleting
#   ./scripts/uninstall.sh --yes     # delete without asking
#   ./scripts/uninstall.sh --dry-run # show what would go, delete nothing

set -eu

assume_yes=0
dry_run=0

for arg in "$@"; do
  case "$arg" in
    --yes | -y) assume_yes=1 ;;
    --dry-run | -n) dry_run=1 ;;
    --help | -h)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$arg" >&2
      printf 'Try --help.\n' >&2
      exit 2
      ;;
  esac
done

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
state_dir="$config_dir/claude-upgrade-advisor"

printf 'claude-upgrade-advisor uninstall\n\n'

# Refuse to operate on anything that is not the expected directory. Cheap
# insurance against a misconfigured CLAUDE_CONFIG_DIR turning this into an
# accidental rm of something important.
case "$state_dir" in
  */claude-upgrade-advisor) : ;;
  *)
    printf 'Refusing to act: %s is not a claude-upgrade-advisor directory.\n' "$state_dir" >&2
    exit 1
    ;;
esac

if [ ! -d "$state_dir" ]; then
  printf 'Nothing to remove. %s does not exist.\n\n' "$state_dir"
  printf 'To remove the plugin itself, run this inside Claude Code:\n\n'
  printf '  /plugin uninstall claude-upgrade-advisor\n\n'
  exit 0
fi

# ------------------------------------------------------------ show the damage
printf 'This is everything this plugin has written:\n\n'
printf '  %s\n' "$state_dir"
find "$state_dir" -mindepth 1 2>/dev/null | sed 's|^|    |' || true
printf '\n'

size="$(du -sh "$state_dir" 2>/dev/null | cut -f1 || echo '?')"
count="$(find "$state_dir" -mindepth 1 2>/dev/null | wc -l | tr -d ' ' || echo '?')"
printf 'Total: %s items, %s\n\n' "$count" "$size"

if [ -d "$state_dir/reports" ]; then
  printf 'Note: past audit reports are in there and will be deleted too.\n'
  printf 'Copy them elsewhere first if you want to keep them.\n\n'
fi

if [ "$dry_run" -eq 1 ]; then
  printf 'Dry run. Nothing was deleted.\n'
  exit 0
fi

# ------------------------------------------------------------------- confirm
if [ "$assume_yes" -eq 0 ]; then
  printf 'Delete all of it? [y/N] '
  read -r reply < /dev/tty || reply=""
  case "$reply" in
    y | Y | yes | YES) : ;;
    *)
      printf '\nCancelled. Nothing was deleted.\n\n'
      printf 'To silence the plugin without deleting anything:\n\n'
      printf '  touch "%s/disabled"\n\n' "$state_dir"
      exit 0
      ;;
  esac
fi

# -------------------------------------------------------------------- delete
rm -rf "$state_dir"

# -------------------------------------------------------------------- verify
if [ -e "$state_dir" ]; then
  printf '\nFailed: %s still exists. Check its permissions.\n' "$state_dir" >&2
  exit 1
fi

printf '\nRemoved %s\n' "$state_dir"

# The plugin writes nowhere else, so this is the whole story. Say so, and prove
# it rather than asserting it.
leftovers="$(find "$config_dir" -maxdepth 2 -name '*claude-upgrade-advisor*' 2>/dev/null || true)"
if [ -n "$leftovers" ]; then
  printf '\nStill present under %s:\n%s\n' "$config_dir" "$leftovers"
  printf 'These are Claude Code'"'"'s own plugin records, not data this plugin wrote.\n'
  printf 'The /plugin uninstall step below clears them.\n'
else
  printf 'Verified: no files matching claude-upgrade-advisor remain under %s.\n' "$config_dir"
fi

printf '\nOne step left. Inside Claude Code, run:\n\n'
printf '  /plugin uninstall claude-upgrade-advisor\n\n'
printf 'To also drop the marketplace entry:\n\n'
printf '  /plugin marketplace remove claude-upgrade-advisor\n\n'
