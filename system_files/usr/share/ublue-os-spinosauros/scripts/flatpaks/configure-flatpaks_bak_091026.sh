#!/usr/bin/env bash
set -euo pipefail

FLATPAK="/usr/bin/flatpak"
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

# flatpaks.txt is expected to be next to this script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FLATPAKS_FILE="${SCRIPT_DIR}/flatpaks.txt"

# Sentinel file
SENTINEL="$HOME/.local/state/spinosauros-flatpakconfig.done"

########################################
# Exit if already configured
########################################

if [[ -f "$SENTINEL" ]]; then
    exit 0
fi

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

########################################
# Install system Flatpak applications
########################################

if [[ ! -f "$FLATPAKS_FILE" ]]; then
    echo "ERROR: Flatpak list not found: $FLATPAKS_FILE" >&2
    exit 1
fi

while IFS= read -r app; do
    # Ignore empty lines and comments
    [[ -z "$app" || "$app" == \#* ]] && continue

    echo "Installing $app..."

    "$FLATPAK" install \
        --system \
        -y \
        flathub \
        "$app"
done < "$FLATPAKS_FILE"

########################################
# Create sentinel
########################################

mkdir -p "$(dirname "$SENTINEL")"
touch "$SENTINEL"

echo "Flatpak configuration completed."
