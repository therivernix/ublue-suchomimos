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
# Configure Flathub
########################################

echo
echo "========================================"
echo "Configuring Flathub"
echo "========================================"

flatpak remote-add --if-not-exists --system \
    flathub https://dl.flathub.org/repo/flathub.flatpakrepo


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
    echo


    ########################################
    # Migrate Fedora Flatpaks to Flathub
    ########################################

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        echo
        echo "========================================"
        echo "Migrating: $app"
        echo "========================================"

        ####################################
        # Check whether Flathub provides it
        ####################################

        if ! flatpak remote-info --system flathub "$app" >/dev/null 2>&1; then
            echo "WARNING: $app is not available on Flathub."
            echo "Keeping Fedora version."
            continue
        fi

        ####################################
        # Install Flathub version
        ####################################

        echo "Installing Flathub version..."

        if flatpak install --system -y flathub "$app"; then

            echo "Successfully migrated $app to Flathub."

        else

            echo "Normal installation failed."
            echo "Attempting migration with downgrade allowed..."

            if flatpak install --system -y \
                --allow-downgrade \
                flathub "$app"; then

                echo "Successfully migrated $app to Flathub."

            else

                echo "WARNING: Failed to migrate $app."
                echo "Keeping the existing Fedora version."
                continue

            fi

        fi

    done <<< "$apps"

fi


########################################
# Remove Fedora Flatpak remotes
########################################

echo
echo "========================================"
echo "Removing Fedora Flatpak remotes"
echo "========================================"

flatpak remote-delete -y --system fedora || true
flatpak remote-delete -y --system fedora-testing || true


########################################
# Show current configuration
########################################

echo
echo "========================================"
echo "Flatpak remotes"
echo "========================================"

flatpak remotes --system


echo
echo "========================================"
echo "Installed system Flatpaks"
echo "========================================"

flatpak list \
    --system \
    --app \
    --columns=application,name,origin


########################################
# Run Flatpak preinstall
########################################

echo
echo "========================================"
echo "Installing additional Flatpaks"
echo "========================================"

flatpak preinstall -y


########################################
# Show final installed Flatpaks
########################################

echo
echo "========================================"
echo "Final installed Flatpaks"
echo "========================================"

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
