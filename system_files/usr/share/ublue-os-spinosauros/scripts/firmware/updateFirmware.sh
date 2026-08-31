#!/usr/bin/env bash

set -euo pipefail

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

print_header() {
    echo -e "\n${BOLD}${BLUE}========================================${RESET}"
    echo -e "${BOLD}${CYAN}$1${RESET}"
    echo -e "${BOLD}${BLUE}========================================${RESET}"
}

print_ok() {
    echo -e "${GREEN}✔ $1${RESET}"
}

print_warn() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

print_error() {
    echo -e "${RED}✖ $1${RESET}"
}

# Refresh metadata
print_header "Refreshing fwupd metadata"

if sudo fwupdmgr refresh --force; then
    print_ok "Metadata refresh completed"
else
    print_error "Metadata refresh failed"
    exit 1
fi

# Check for updates
print_header "Checking for firmware updates"

UPDATE_OUTPUT="$(sudo fwupdtool get-updates 2>&1 || true)"

echo "$UPDATE_OUTPUT"

# Apply updates
print_header "Applying firmware updates"

UPDATE_RUN_OUTPUT="$(sudo fwupdtool update 2>&1 || true)"

echo "$UPDATE_RUN_OUTPUT"

# Detect reboot requirement
print_header "Post-update status"

if echo "$UPDATE_RUN_OUTPUT" | grep -qiE "reboot|restart required|pending reboot"; then
    print_warn "A reboot is required to complete firmware updates."

    read -rp "$(echo -e "${YELLOW}Reboot now? [y/N]: ${RESET}")" REPLY

    case "$REPLY" in
        [yY]|[yY][eE][sS])
            print_warn "Rebooting system..."
            systemctl reboot
            ;;
        *)
            print_warn "Reboot skipped. Please reboot later."
            ;;
    esac
else
    print_ok "No reboot required."
fi

print_header "Done"

read -rp "$(echo -e "${CYAN}Press Enter to close this Terminal window...${RESET}")"
