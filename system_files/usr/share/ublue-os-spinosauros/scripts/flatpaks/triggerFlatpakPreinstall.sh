#!/usr/bin/env bash
set -euo pipefail

SENTINEL="$HOME/.local/state/spinosauros-triggerflatpakspreinstall.done"

if [[ -f "$SENTINEL" ]]; then
    exit 0
fi

mkdir -p "$(dirname "$SENTINEL")"

touch "$SENTINEL"

flatpak remote-delete --system fedora || true
flatpak remote-delete --system fedora-testing || true

flatpak remote-add --if-not-exists --system \
    flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    
flatpak preinstall -y 
