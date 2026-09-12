#!/usr/bin/env bash
set -euo pipefail

SENTINEL="$HOME/.local/state/spinosauros-flatpak-setup.done"

########################################
# Don't run more than once
########################################

if [[ -f "$SENTINEL" ]]; then
    exit 0
fi

mkdir -p "$(dirname "$SENTINEL")"


########################################
# Remove unwanted Flatpaks
########################################

echo "========================================"
echo "Removing unwanted Flatpaks"
echo "========================================"

flatpak uninstall -y --system \
    org.gnome.Calendar \
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
    org.gnome.Weather \
    || true


########################################
# Find Fedora Flatpaks
########################################

echo
echo "========================================"
echo "Finding Fedora Flatpaks"
echo "========================================"

apps="$(
    flatpak list \
        --system \
        --app \
        --columns=application,origin |
    awk '$2 == "fedora" || $2 == "fedora-testing" {print $1}'
)"

if [[ -z "$apps" ]]; then
    echo "No Fedora Flatpak applications found."
else
    echo "Fedora Flatpaks to migrate:"
    echo "$apps"
fi


########################################
# Remove ALL Fedora Flatpaks
########################################

if [[ -n "$apps" ]]; then

    echo
    echo "========================================"
    echo "Removing Fedora Flatpaks"
    echo "========================================"

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        echo "Removing: $app"

        flatpak uninstall \
            --system \
            -y \
            "$app"

    done <<< "$apps"

fi


########################################
# Remove Fedora Flatpak remotes
########################################

echo
echo "========================================"
echo "Removing Fedora Flatpak remotes"
echo "========================================"

flatpak remote-delete \
    --system \
    -y \
    fedora \
    || true

flatpak remote-delete \
    --system \
    -y \
    fedora-testing \
    || true


########################################
# Verify Fedora remotes are gone
########################################

echo
echo "========================================"
echo "Verifying Flatpak remotes"
echo "========================================"

flatpak remotes --system


########################################
# Configure Flathub
########################################

echo
echo "========================================"
echo "Configuring Flathub"
echo "========================================"

flatpak remote-add \
    --if-not-exists \
    --system \
    flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo


########################################
# Migrate Fedora Flatpaks to Flathub
########################################

if [[ -n "$apps" ]]; then

    echo
    echo "========================================"
    echo "Installing Flathub Flatpaks"
    echo "========================================"

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        echo
        echo "========================================"
        echo "Installing from Flathub: $app"
        echo "========================================"

        if flatpak install \
            --system \
            -y \
            flathub \
            "$app"; then

            echo "Successfully installed $app from Flathub."

        else

            echo "Normal installation failed."
            echo "Attempting downgrade if required..."

            flatpak install \
                --system \
                -y \
                --allow-downgrade \
                flathub \
                "$app"

            echo "Successfully installed $app from Flathub."

        fi

    done <<< "$apps"

else

    echo
    echo "No Fedora Flatpaks need migration."

fi


########################################
# Run Flatpak preinstall
########################################

echo
echo "========================================"
echo "Installing additional Flatpaks"
echo "========================================"

flatpak preinstall -y


########################################
# Show final configuration
########################################

echo
echo "========================================"
echo "Final Flatpak configuration"
echo "========================================"

echo
echo "Remotes:"
echo "========"

flatpak remotes --system

echo
echo "Installed system Flatpaks:"
echo "=========================="

flatpak list \
    --system \
    --app \
    --columns=application,name,origin


########################################
# Mark complete
########################################

# Only create the sentinel after EVERYTHING succeeded.
touch "$SENTINEL"

echo
echo "========================================"
echo "Flatpak setup completed successfully."
echo "========================================"
