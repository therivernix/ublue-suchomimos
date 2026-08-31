#!/bin/bash
# Interactive LUKS password management helper
# Supports adding, testing, and removing LUKS passwords

set -euo pipefail

# Prompt for sudo at the start
sudo -v

clear

echo "=============================================="
echo "      Interactive LUKS Password Manager"
echo "=============================================="
echo
echo "This script helps you:"
echo "  1. Add a new LUKS password"
echo "  2. Test a LUKS password"
echo "  3. Remove an old LUKS password"
echo
echo "IMPORTANT:"
echo " - The password only unlocks the LUKS keyslot."
echo " - You can have multiple passwords for multiple users."
echo " - On Fedora Atomic desktops (Silverblue/Kinoite),"
echo "   the unlock prompt may use a QWERTY keyboard layout."
echo

echo "Detected block devices:"
echo "----------------------------------------------"
lsblk
echo "----------------------------------------------"
echo

read -rp "Enter your encrypted partition (example: /dev/nvme0n1p3): " LUKS_DEVICE

if [[ ! -b "$LUKS_DEVICE" ]]; then
    echo
    echo "ERROR: '$LUKS_DEVICE' is not a valid block device."
    exit 1
fi

echo
echo "Selected device: $LUKS_DEVICE"
echo

while true; do
    echo "Choose an action:"
    echo "  1) Add a new password"
    echo "  2) Test a password"
    echo "  3) Remove an old password"
    echo "  4) Exit"
    echo

    read -rp "Selection: " CHOICE
    echo

    case "$CHOICE" in
        1)
            echo "Adding a new LUKS password..."
            echo
            sudo cryptsetup luksAddKey "$LUKS_DEVICE"
            echo
            echo "Password successfully added."
            echo
            ;;
        2)
            echo "Testing a LUKS password..."
            echo
            sudo cryptsetup --test-passphrase -v open "$LUKS_DEVICE"
            echo
            echo "Password test completed."
            echo
            ;;
        3)
            echo "Removing a LUKS password..."
            echo
            echo "Enter the password you want to remove."
            echo
            sudo cryptsetup luksRemoveKey "$LUKS_DEVICE"
            echo
            echo "Password successfully removed."
            echo
            ;;
        4)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid selection."
            echo
            ;;
    esac
done
