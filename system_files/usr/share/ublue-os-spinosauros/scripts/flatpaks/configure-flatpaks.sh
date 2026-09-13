bash
#!/usr/bin/env bash
set -euo pipefail

FLATPAK="/usr/bin/flatpak"
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
SENTINEL="$HOME/.local/state/spinosauros-flatpak-reset.done"

########################################
# Don't run more than once
########################################

if [[ -f "$SENTINEL" ]]; then
    exit 0
fi

mkdir -p "$(dirname "$SENTINEL")"

########################################
# Introduction
########################################

cat <<'EOF'

============================================================
        Spinosauros First-Run Configuration
============================================================

This is a first-run configuration script to configure
applications.

We will remove the Fedora Flatpak repositories and switch
over to Flathub repositories.

Additionally, we will remove any Flatpak that originally
came with the system.

You can install additional applications using ujust or
Bazaar.

============================================================

EOF

########################################
# Ask for confirmation
########################################

read -r -p "Do you want to continue? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo
    echo "Configuration cancelled."
    exit 0
fi

echo
echo "Starting Flatpak configuration..."
echo

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
# Mark setup as completed
########################################

touch "$SENTINEL"

echo
echo "Flatpak configuration completed successfully."
echo
