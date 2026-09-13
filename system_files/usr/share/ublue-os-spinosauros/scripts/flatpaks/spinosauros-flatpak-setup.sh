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

if ! command -v flatpak >/dev/null 2>&1; then
    echo "ERROR: flatpak is not installed."
    exit 1
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
# Confirmation
########################################

clear

echo
echo "========================================"
echo "   Spinosauros App Configuration"
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

read -r -p "Configure apps? [y/N]: " answer

case "$answer" in
    y|Y|yes|YES|Yes)
        ;;
    *)
        echo
        echo "App configuration cancelled."
        exit 0
        ;;
esac


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
echo "=======
