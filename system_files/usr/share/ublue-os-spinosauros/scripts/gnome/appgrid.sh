#!/usr/bin/env bash
set -euo pipefail

SENTINEL="$HOME/.local/state/spinosauros-appgrid.done"

if [[ -f "$SENTINEL" ]]; then
    exit 0
fi

mkdir -p "$(dirname "$SENTINEL")"

touch "$SENTINEL"

gsettings set org.gnome.desktop.app-folders folder-children ['']
