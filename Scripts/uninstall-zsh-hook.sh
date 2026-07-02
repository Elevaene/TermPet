#!/usr/bin/env zsh
set -euo pipefail

ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
START_MARKER="# >>> TermPet shell hook >>>"
END_MARKER="# <<< TermPet shell hook <<<"

if [[ ! -f "$ZSHRC" ]]; then
  print "No .zshrc found at $ZSHRC"
  exit 0
fi

BACKUP="$ZSHRC.termpet-uninstall-backup-$(date +%Y%m%d%H%M%S)"
cp "$ZSHRC" "$BACKUP"

tmp_file="$(mktemp)"
awk -v start="$START_MARKER" -v end="$END_MARKER" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
' "$ZSHRC" > "$tmp_file"
mv "$tmp_file" "$ZSHRC"

print "TermPet zsh hook removed."
print "Backup: $BACKUP"
print "Open a new terminal or run: source \"$ZSHRC\""
