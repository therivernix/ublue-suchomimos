#!/usr/bin/env bash
set -euo pipefail

FLATPAK="/usr/bin/flatpak"
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

########################################
# Remove Fedora Flatpak remotes
########################################

"$FLATPAK" remote-delete --system fedora 2>/dev/null || true
"$FLATPAK" remote-delete --system fedora-testing 2>/dev/null || true

########################################
# Remove all system Flatpak applications
########################################

"$FLATPAK" list --system --app --columns=application |
while IFS= read -r app; do
    [[ -z "$app" ]] && continue

    "$FLATPAK" uninstall \
        --system \
        --delete-data \
        -y \
        "$app"
done

########################################
# Remove all user Flatpak applications
########################################

"$FLATPAK" list --user --app --columns=application |
while IFS= read -r app; do
    [[ -z "$app" ]] && continue

    "$FLATPAK" uninstall \
        --user \
        --delete-data \
        -y \
        "$app"
done

########################################
# Remove unused system runtimes/extensions
########################################

"$FLATPAK" uninstall --system --unused -y || true

########################################
# Remove unused user runtimes/extensions
########################################

"$FLATPAK" uninstall --user --unused -y || true

########################################
# Ensure system Flathub exists
########################################

"$FLATPAK" remote-add \
    --if-not-exists \
    --system \
    flathub \
    "$FLATHUB_URL"

########################################
# Ensure user Flathub exists
########################################

"$FLATPAK" remote-add \
    --if-not-exists \
    --user \
    flathub \
    "$FLATHUB_URL"
