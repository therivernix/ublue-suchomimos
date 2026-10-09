#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Spinosauros | Flatpak Configuration
# =============================================================================
# Removes existing Flatpak applications, configures Flathub, and installs
# the applications defined in flatpaks.txt.
#
# This script runs only once per user, using a sentinel file.
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

readonly FLATPAK="/usr/bin/flatpak"
readonly FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly FLATPAKS_FILE="${SCRIPT_DIR}/flatpaks.txt"
readonly SENTINEL="${HOME}/.local/state/spinosauros-flatpakconfig.done"

# -----------------------------------------------------------------------------
# Output helpers
# -----------------------------------------------------------------------------

if [[ -t 1 ]]; then
    readonly RESET=$'\033[0m'
    readonly BLUE=$'\033[1;34m'
    readonly GREEN=$'\033[1;32m'
    readonly YELLOW=$'\033[1;33m'
    readonly RED=$'\033[1;31m'
else
    readonly RESET="" BLUE="" GREEN="" YELLOW="" RED=""
fi

info() {
    printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"
}

success() {
    printf '%s[ OK ]%s %s\n' "$GREEN" "$RESET" "$*"
}

warn() {
    printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2
}

error() {
    printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$*" >&2
}

section() {
    printf '\n%s==> %s%s\n' "$BLUE" "$*" "$RESET"
}

# -----------------------------------------------------------------------------
# Preflight checks
# -----------------------------------------------------------------------------

preflight() {
    if [[ -f "$SENTINEL" ]]; then
        success "Flatpak configuration already completed."
        exit 0
    fi

    [[ -x "$FLATPAK" ]] || {
        error "Flatpak executable not found: $FLATPAK"
        exit 1
    }

    [[ -f "$FLATPAKS_FILE" ]] || {
        error "Application list not found: $FLATPAKS_FILE"
        exit 1
    }
}

# -----------------------------------------------------------------------------
# Remove Fedora Flatpak remotes
# -----------------------------------------------------------------------------

remove_fedora_remotes() {
    section "Removing Fedora Flatpak remotes"

    local remote

    for remote in fedora fedora-testing; do
        if "$FLATPAK" remote-delete --system "$remote" 2>/dev/null; then
            success "Removed remote: $remote"
        else
            info "Remote absent or could not be removed: $remote"
        fi
    done
}

# -----------------------------------------------------------------------------
# Remove installed Flatpak applications
# -----------------------------------------------------------------------------

remove_applications() {
    local scope="$1"
    local app

    section "Removing ${scope} Flatpak applications"

    while IFS= read -r app; do
        [[ -z "$app" ]] && continue

        info "Removing: $app"

        "$FLATPAK" uninstall \
            "--${scope}" \
            --delete-data \
            -y \
            "$app"

    done < <("$FLATPAK" list "--${scope}" --app --columns=application)

    success "${scope^} applications removed."
}

# -----------------------------------------------------------------------------
# Remove unused runtimes and extensions
# -----------------------------------------------------------------------------

remove_unused() {
    local scope="$1"

    section "Cleaning unused ${scope} runtimes and extensions"

    if "$FLATPAK" uninstall "--${scope}" --unused -y; then
        success "${scope^} cleanup completed."
    else
        warn "${scope^} cleanup could not be completed."
    fi
}

# -----------------------------------------------------------------------------
# Configure Flathub
# -----------------------------------------------------------------------------

configure_flathub() {
    local scope="$1"

    section "Configuring ${scope} Flathub remote"

    "$FLATPAK" remote-add \
        --if-not-exists \
        "--${scope}" \
        flathub \
        "$FLATHUB_URL"

    success "${scope^} Flathub remote configured."
}

# -----------------------------------------------------------------------------
# Install applications from flatpaks.txt
# -----------------------------------------------------------------------------

install_applications() {
    section "Installing Flatpak applications"

    local app
    local count=0

    while IFS= read -r app || [[ -n "$app" ]]; do
        # Ignore comments, blank lines, and Windows line endings.
        app="${app%$'\r'}"
        [[ -z "${app//[[:space:]]/}" || "$app" =~ ^[[:space:]]*# ]] && continue

        info "Installing: $app"

        "$FLATPAK" install \
            --system \
            --noninteractive \
            -y \
            flathub \
            "$app"

        ((count += 1))

    done < "$FLATPAKS_FILE"

    success "Installed $count Flatpak application(s)."
}

# -----------------------------------------------------------------------------
# Mark configuration as completed
# -----------------------------------------------------------------------------

create_sentinel() {
    mkdir -p "$(dirname "$SENTINEL")"
    touch "$SENTINEL"

    success "Sentinel created: $SENTINEL"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    preflight

    printf '\n%s' "$BLUE"
    printf '%s\n' "=========================================="
    printf '%s\n' "       SPINOSAUROS FLATPAK SETUP"
    printf '%s\n' "=========================================="
    printf '%s\n\n' "$RESET"

    remove_fedora_remotes

    remove_applications system
    remove_applications user

    remove_unused system
    remove_unused user

    configure_flathub system
    configure_flathub user

    install_applications
    create_sentinel

    section "Flatpak configuration complete"
    success "Spinosauros Flatpak setup finished successfully."
}

main "$@"
