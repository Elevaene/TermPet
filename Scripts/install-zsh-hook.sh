#!/usr/bin/env zsh
set -euo pipefail

ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
BACKUP="$ZSHRC.termpet-backup-$(date +%Y%m%d%H%M%S)"
START_MARKER="# >>> TermPet shell hook >>>"
END_MARKER="# <<< TermPet shell hook <<<"

mkdir -p "$(dirname "$ZSHRC")"
touch "$ZSHRC"
cp "$ZSHRC" "$BACKUP"

tmp_file="$(mktemp)"
awk -v start="$START_MARKER" -v end="$END_MARKER" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
' "$ZSHRC" > "$tmp_file"
mv "$tmp_file" "$ZSHRC"

cat >> "$ZSHRC" <<'HOOK'

# >>> TermPet shell hook >>>
zmodload zsh/datetime 2>/dev/null || true

export TERMPET_EVENT_LOG="${TERMPET_EVENT_LOG:-$HOME/Library/Application Support/TermPet/events.jsonl}"

__termpet_json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  print -r -- "$value"
}

__termpet_redact() {
  local value="$1"
  value="${value//[Uu][Ss][Ee][Rr][Nn][Aa][Mm][Ee]=[^&[:space:]]*/username=[REDACTED]}"
  print -r -- "$value"
}

__termpet_now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

__termpet_write_event() {
  mkdir -p "${TERMPET_EVENT_LOG:h}"
  print -r -- "$1" >> "$TERMPET_EVENT_LOG"
}

__termpet_preexec() {
  __TERMPET_COMMAND="$(__termpet_redact "$1")"
  __TERMPET_STARTED_AT="$(__termpet_now_iso)"
  __TERMPET_START_SECONDS="${EPOCHSECONDS:-$(date +%s)}"
  local command_json="$(__termpet_json_escape "$__TERMPET_COMMAND")"
  __termpet_write_event "{\"type\":\"command_started\",\"command\":\"$command_json\",\"startedAt\":\"$__TERMPET_STARTED_AT\"}"
}

__termpet_precmd() {
  local exit_code="$?"
  if [[ -z "${__TERMPET_COMMAND:-}" ]]; then
    return
  fi

  local end_seconds="${EPOCHSECONDS:-$(date +%s)}"
  local duration_ms=$(( (end_seconds - __TERMPET_START_SECONDS) * 1000 ))
  local finished_at="$(__termpet_now_iso)"
  local command_json="$(__termpet_json_escape "$__TERMPET_COMMAND")"
  __termpet_write_event "{\"type\":\"command_finished\",\"command\":\"$command_json\",\"exitCode\":$exit_code,\"durationMs\":$duration_ms,\"startedAt\":\"$__TERMPET_STARTED_AT\",\"finishedAt\":\"$finished_at\"}"
  unset __TERMPET_COMMAND __TERMPET_STARTED_AT __TERMPET_START_SECONDS
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec __termpet_preexec
add-zsh-hook precmd __termpet_precmd
# <<< TermPet shell hook <<<
HOOK

print "TermPet zsh hook installed."
print "Backup: $BACKUP"
print "Open a new terminal or run: source \"$ZSHRC\""
