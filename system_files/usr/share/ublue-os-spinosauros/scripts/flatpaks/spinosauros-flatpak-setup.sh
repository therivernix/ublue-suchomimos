bash
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
# Check required commands
########################################

if ! command -v gum >/dev/null 2>&1; then
    echo "ERROR: gum is not installed."
    exit 1
fi

if ! command -v flatpak >/dev/null 2>&1; then
    echo "ERROR: flatpak is not installed."
    exit 1
fi


########################################
# Welcome / confirmation
########################################

clear

echo
echo "========================================"
echo "       Spinosauros App Configuration"
echo "========================================"
echo
echo "This will configure the default Flatpak"
echo "applications on this system."
echo
echo "You can also use:"
echo
echo "    ujust spino-configure-apps"
echo
echo "to run this configuration in the future."
echo

choice="$(
    gum choose \
        --header "What would you like to do?" \
        "Configure apps" \
        "Cancel"
)"

if [[ "$choice" != "Configure apps" ]]; then
    echo
    echo "App configuration cancelled."
    exit 0
fi


########################################
# Default Flatpak applications
########################################

FLATHUB_APPS=(
    app.drey.EarTag
    be.alexandervanhee.gradia
    ca.desrt.dconf-editor
    cafe.avery.Delfin
    com.brave.Browser
    com.fastmail.Fastmail
    com.github.PintaProject.Pinta
    com.github.tchx84.Flatseal
    com.github.xournalpp.xournalpp
    com.mattjakeman.ExtensionManager
    com.obsproject.Studio
    com.ranfdev.DistroShelf
    com.somaxa8.earx
    com.synology.SynologyDrive
    com.vixalien.sticky
    com.vscodium.codium
    com.yubico.yubioath
    de.leopoldluley.Clapgrep
    de.swsnr.turnon
    fr.handbrake.ghb
    io.github.ans_ibrahim.Memento
    io.github.flattool.Ignition
    io.github.flattool.Warehouse
    io.github.kolunmi.Bazaar
    io.github.maniacx.BudsLink
    io.github.plrigaux.sysd-manager
    io.github.screwys.Rufin
    io.github.tobagin.keysmith
    io.github.victoralvesf.aonsoku
    io.github.vikdevelop.SaveDesktop
    io.gitlab.adhami3310.Impression
    io.missioncenter.MissionCenter
    it.dottorblaster.cauldron
    it.mijorus.gearlever
    it.mijorus.smile
    md.obsidian.Obsidian
    nl.andreasknoben.Laser
    org.fedoraproject.MediaWriter
    org.filezillaproject.Filezilla
    org.gaphor.Gaphor
    org.gnome.Calculator
    org.gnome.Decibels
    org.gnome.Epiphany
    org.gnome.FileRoller
    org.gnome.Firmware
    org.gnome.Logs
    org.gnome.Loupe
    org.gnome.NautilusPreviewer
    org.gnome.Papers
    org.gnome.PowerStats
    org.gnome.Showtime
    org.gnome.SimpleScan
    org.gnome.Snapshot
    org.gnome.SoundRecorder
    org.gnome.TextEditor
    org.gnome.World.PikaBackup
    org.gnome.baobab
    org.gnome.clocks
    org.kde.kdenlive
    org.keepassxc.KeePassXC
    org.libreoffice.LibreOffice
    org.nickvision.tubeconverter
    org.remmina.Remmina
    org.signal.Signal
    page.codeberg.libre_menu_editor.LibreMenuEditor
    page.tesk.Refine
    org.pulseaudio.pavucontrol
    dev.mufeed.Wordbook
)


########################################
# Phase 1
# Remove unwanted Flatpaks
########################################

echo
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


########################################
# Verify Fedora Flatpaks are gone
########################################

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

if flatpak remotes --system | \
    awk '{print $1}' | \
    grep -qx 'fedora'; then

    flatpak remote-delete \
        --system \
        --force \
        fedora
fi

if flatpak remotes --system | \
    awk '{print $1}' | \
    grep -qx 'fedora-testing'; then

    flatpak remote-delete \
        --system \
        --force \
        fedora-testing
fi


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

echo
echo "Verifying Flathub remote..."

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
# Install default Flatpaks
########################################

echo
echo "========================================"
echo "Phase 6: Installing default Flatpaks"
echo "========================================"

echo
echo "Installing ${#FLATHUB_APPS[@]} applications..."
echo

for app in "${FLATHUB_APPS[@]}"; do

    echo
    echo "----------------------------------------"
    echo "Installing: $app"
    echo "----------------------------------------"

    ########################################
    # Skip if already installed from
    # Flathub
    ########################################

    if flatpak list \
        --system \
        --app \
        --columns=application,origin |
        awk -v app="$app" '$1 == app && $2 == "flathub" {found=1} END {exit !found}'
    then
        echo "$app is already installed from Flathub."
        continue
    fi

    ########################################
    # Verify application exists on Flathub
    ########################################

    if ! flatpak remote-info \
        --system \
        flathub \
        "$app" >/dev/null 2>&1; then

        echo "ERROR: $app is not available on Flathub."
        exit 1
    fi

    ########################################
    # Install application
    ########################################

    flatpak install \
        --system \
        --allow-downgrade \
        -y \
        flathub \
        "$app"

    echo "Successfully installed $app."

done

echo
echo "Phase 6 completed successfully."


########################################
# Phase 7
# Verify Flatpak origins
########################################

echo
echo "========================================"
echo "Phase 7: Verifying Flatpak origins"
echo "========================================"

for app in "${FLATHUB_APPS[@]}"; do

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

    echo "Verified: $app -> flathub"

done

echo
echo "All default Flatpaks are confirmed to use Flathub."
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

# Only create the sentinel after EVERYTHING
# succeeded.

touch "$SENTINEL"

echo
echo "========================================"
echo "Flatpak setup completed successfully."
echo "========================================"
echo
echo "You can run the configuration again with:"
echo
echo "    ujust spino-configure-apps"
echo
