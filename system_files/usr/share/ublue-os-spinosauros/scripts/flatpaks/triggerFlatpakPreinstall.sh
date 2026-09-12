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
# Phase 1
# Remove unwanted Flatpaks
########################################

echo "========================================"
echo "Phase 1: Removing unwanted Flatpaks"
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

echo
echo "Phase 1 completed successfully."


########################################
# Phase 2
# Find Fedora Flatpaks
########################################

echo
echo "========================================"
echo "Phase 2: Finding Fedora Flatpaks"
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

echo
echo "Phase 2 completed successfully."


########################################
# Phase 3
# Remove ALL Fedora Flatpaks
########################################

echo
echo "========================================"
echo "Phase 3: Removing Fedora Flatpaks"
echo "========================================"

if [[ -n "$apps" ]]; then

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        echo "Removing: $app"

        flatpak uninstall \
            --system \
            -y \
            "$app"

    done <<< "$apps"

else

    echo "Nothing to remove."

fi

echo
echo "Verifying no Fedora Flatpaks remain..."

remaining_fedora_apps="$(
    flatpak list \
        --system \
        --app \
        --columns=application,origin |
    awk '$2 == "fedora" || $2 == "fedora-testing" {print $1}'
)"

if [[ -n "$remaining_fedora_apps" ]]; then
    echo "ERROR: Fedora Flatpaks are still installed:"
    echo "$remaining_fedora_apps"
    exit 1
fi

echo "No Fedora Flatpaks remain."
echo
echo "Phase 3 completed successfully."


########################################
# Phase 4
# Remove Fedora remotes
########################################

echo
echo "========================================"
echo "Phase 4: Removing Fedora remotes"
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
echo "Verifying Fedora remotes are gone..."

if flatpak remotes --system | \
    awk '{print $1}' | \
    grep -Eq '^(fedora|fedora-testing)$'; then

    echo "ERROR: Fedora Flatpak remote still exists."
    exit 1
fi

echo "Fedora remotes successfully removed."
echo
echo "Phase 4 completed successfully."


########################################
# Phase 5
# Configure Flathub
########################################

echo
echo "========================================"
echo "Phase 5: Configuring Flathub"
echo "========================================"

flatpak remote-add \
    --if-not-exists \
    --system \
    flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo


########################################
# Verify Flathub exists
########################################

if ! flatpak remotes --system | \
    awk '{print $1}' | \
    grep -qx 'flathub'; then

    echo "ERROR: Flathub remote was not added."
    exit 1
fi

echo "Flathub remote successfully configured."
echo
echo "Phase 5 completed successfully."


########################################
# Phase 6
# Install Fedora apps from Flathub
########################################

echo
echo "========================================"
echo "Phase 6: Installing Flathub Flatpaks"
echo "========================================"

if [[ -n "$apps" ]]; then

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        echo
        echo "----------------------------------------"
        echo "Installing from Flathub: $app"
        echo "----------------------------------------"

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

    echo "No Fedora Flatpaks need migration."

fi


########################################
# Verify every migrated app uses Flathub
########################################

echo
echo "Verifying migrated Flatpaks..."

if [[ -n "$apps" ]]; then

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        origin="$(
            flatpak list \
                --system \
                --app \
                --columns=application,origin |
            awk -v app="$app" '$1 == app {print $2}'
        )"

        if [[ "$origin" != "flathub" ]]; then
            echo "ERROR: $app is not installed from Flathub."
            echo "Detected origin: ${origin:-unknown}"
            exit 1
        fi

        echo "Verified: $app → flathub"

    done <<< "$apps"

fi

echo
echo "All migrated Flatpaks are confirmed to use Flathub."
echo
echo "Phase 6 completed successfully."


########################################
# Phase 7
# Run Flatpak preinstall
########################################

echo
echo "========================================"
echo "Phase 7: Installing additional Flatpaks"
echo "========================================"

flatpak preinstall -y

echo
echo "Phase 7 completed successfully."


########################################
# Final configuration
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
