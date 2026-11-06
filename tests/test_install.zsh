#!/usr/bin/env zsh
# bin/install-zsh-plugin links the repo into $ZSH_CUSTOM/plugins/herdr.
source "${0:A:h}/lib.zsh"
setup_sandbox
export HOME="$SB/home"
mkdir -p "$HOME/.oh-my-zsh/custom" && : >"$HOME/.oh-my-zsh/oh-my-zsh.sh"
unset ZSH ZSH_CUSTOM ZDOTDIR HERDR_PLUGIN_ROOT
print 'plugins=(git\n  docker\n)' >"$HOME/.zshrc"

out="$(zsh "$REPO/bin/install-zsh-plugin" 2>&1)"; rc=$?
link="$HOME/.oh-my-zsh/custom/plugins/herdr"
check "fresh install exits 0" "0" "$rc"
check "symlink points at the repo" "$REPO" "$(readlink "$link")"
check_match "tells the user to add the plugin" "*add 'herdr' to the plugins list*" "$out"

out="$(zsh "$REPO/bin/install-zsh-plugin" 2>&1)"; rc=$?
check "second run is idempotent" "0:$REPO" "$rc:$(readlink "$link")"
check_contains "second run says it updated the link" 'updated link' "$out"

print 'plugins=(git\n  herdr\n)' >"$HOME/.zshrc"
out="$(zsh "$REPO/bin/install-zsh-plugin" 2>&1)"
check_contains "detects herdr already in a multi-line plugins list" "already in the plugins list" "$out"

# HERDR_PLUGIN_ROOT (set by herdr during build) wins over the script location.
out="$(HERDR_PLUGIN_ROOT="$SB/elsewhere" zsh "$REPO/bin/install-zsh-plugin" 2>&1)"
check "HERDR_PLUGIN_ROOT is honoured" "$SB/elsewhere" "$(readlink "$link")"

# ZSH_CUSTOM elsewhere.
mkdir -p "$SB/custom"
out="$(ZSH_CUSTOM="$SB/custom" zsh "$REPO/bin/install-zsh-plugin" 2>&1)"
check "ZSH_CUSTOM is honoured" "$REPO" "$(readlink "$SB/custom/plugins/herdr")"

# A real directory in the way, such as an old plain clone, is replaced by the
# link and kept as a backup next to it.
plugins="$HOME/.oh-my-zsh/custom/plugins"
rm "$link"; mkdir -p "$link"; : >"$link/keep"
out="$(zsh "$REPO/bin/install-zsh-plugin" 2>&1)"; rc=$?
backups=($plugins/herdr.backup-*(N))
check "existing directory is overridden by a link to the plugin root" "0:link:$REPO" \
  "$rc:$([[ -L $link ]] && print link || print dir):$(readlink "$link")"
check "old directory is kept as one backup with its contents" "1:1" \
  "${#backups}:$([[ -f $backups[1]/keep ]] && print 1 || print 0)"
check_contains "replacement names the link" "replaced the directory at $link with a link to $REPO" "$out"
check_contains "replacement names the backup" "old directory was moved to $backups[1]" "$out"

# A second replacement in the same second does not touch the first backup.
rm "$link"; mkdir -p "$link"; : >"$link/again"
zsh "$REPO/bin/install-zsh-plugin" >/dev/null 2>&1
backups=($plugins/herdr.backup-*(N))
check "a later replacement gets its own backup" "2:$REPO" "${#backups}:$(readlink "$link")"
rm -rf $plugins/herdr.backup-*(N)

# The checkout already sitting at the target is never moved out from under itself.
rm "$link"; mkdir -p "$link"; : >"$link/keep"
out="$(HERDR_PLUGIN_ROOT="$link" zsh "$REPO/bin/install-zsh-plugin" 2>&1)"; rc=$?
backups=($plugins/herdr.backup-*(N))
check "a checkout at the target stays in place" "0:dir:1:0" \
  "$rc:$([[ -L $link ]] && print link || print dir):$([[ -f $link/keep ]] && print 1 || print 0):${#backups}"
check_contains "a checkout at the target is explained" 'is this checkout, so it was left in place' "$out"

# Anything else in the way, such as a plain file, is still left alone.
rm -rf "$link"; : >"$link"
out="$(zsh "$REPO/bin/install-zsh-plugin" 2>&1)"; rc=$?
check "existing file is not clobbered" "0:file" "$rc:$([[ -f $link && ! -L $link ]] && print file)"
check_contains "existing file is explained" 'already exists and is not a symlink' "$out"
rm -f "$link"

# No Oh My Zsh: succeed so the herdr plugin still registers, but say so.
out="$(ZSH="$SB/nowhere" zsh "$REPO/bin/install-zsh-plugin" 2>&1)"; rc=$?
check "missing Oh My Zsh exits 0" "0" "$rc"
check_contains "missing Oh My Zsh is explained" 'Oh My Zsh was not found' "$out"

finish
