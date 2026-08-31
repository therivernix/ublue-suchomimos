#!/usr/bin/env bash
set -euo pipefail

SENTINEL="$HOME/.local/state/spinosauros-removeflatpaks.done"

if [[ -f "$SENTINEL" ]]; then
    exit 0
fi

mkdir -p "$(dirname "$SENTINEL")"

touch "$SENTINEL"

flatpak uninstall -y org.gnome.Calendar \
        org.gnome.Contacts \
        org.mozilla.firefox \
        org.mozilla.thunderbird \
        org.mozilla.thunderbird_esr \
        org.mozilla.thunderbird_esr.Locale \
        org.gnome.font-viewer \
        org.gnome.Characters \
        org.gnome.Maps \
        org.gnome.DejaDup \
        org.gnome.Connections \
        org.gnome.Weather
