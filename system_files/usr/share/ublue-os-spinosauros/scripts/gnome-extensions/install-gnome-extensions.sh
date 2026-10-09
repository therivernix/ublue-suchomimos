#!/usr/bin/env bash
#
# Install the Spinosauros GNOME Shell extension set system-wide at image-build time.
#
# Strategy:
#   * Prefer ready-made upstream GitHub release ZIPs where available.
#   * Fall back to a directly-installable current upstream source tree.
#   * Use project-specific build/staging logic where the project requires it.
#   * Validate UUID and GNOME Shell compatibility before installing.
#
# Intended for Fedora/Bluefin/Silverblue/bootc image builds.
#

set -euo pipefail

INSTALL_DIR="/usr/share/gnome-shell/extensions"
GITHUB_API="https://api.github.com"
SHELL_VERSION=""

# UUID|GitHub owner/repository
#
# These projects either publish installable ZIP assets or have a directly
# installable extension tree in their current default branch.
RELEASE_EXTENSIONS=(
    "AlphabeticalAppGrid@stuarthayhurst|stuarthayhurst/alphabetical-grid-extension"
    "Studi-Brightness-Control@matey-0|matey-0/Studi-Brightness-Control"
    "clipboard-indicator@tudmotu.com|Tudmotu/gnome-shell-extension-clipboard-indicator"
    "disable-workspace-switch-animation@osmancevik|osmancevik/gnome-extension-disable-workspace-switch-animation"
    "hide-minimized@danigm.net|danigm/hide-minimized"
    "hotedge@jonathan.jdoda.ca|jdoda/hotedge"
    "quick-settings-audio-panel@rayzeq.github.io|Rayzeq/quick-settings-audio-panel"
    "smile-extension@mijorus.it|mijorus/smile-gnome-extension"
)

CUSTOM_COMMAND_UUID="custom-command-list@storageb.github.com"
CUSTOM_COMMAND_REPO="StorageB/custom-command-menu"

TILING_UUID="tilingshell@ferrarodomenico.com"
TILING_REPO="domferr/tilingshell"

ASDB_UUID="ASDB-Brightness-Keys@therivernix"
ASDB_ZIP_URL="https://raw.githubusercontent.com/therivernix/ASDB-Brightness-Keys/main/ASDB-Brightness-Keys%40therivernix.zip"

BUDSLINK_UUID="BudsLink-Companion@maniacx.github.com"
BUDSLINK_REPO="https://github.com/maniacx/BudsLink-Companion.git"
BUDSLINK_REF="c11b6cf5626ee5417efc0af91148736e0697c354"

BLUR_UUID="blur-my-shell@aunetx"
BLUR_REPO="https://github.com/aunetx/blur-my-shell.git"

JUST_UUID="just-perfection-desktop@just-perfection"
JUST_REPO="https://gitlab.gnome.org/jrahmatzadeh/just-perfection.git"

TAILSCALE_UUID="tailscale-gnome-qs@tailscale-qs.github.io"
TAILSCALE_REPO="https://github.com/tailscale-qs/tailscale-gnome-qs.git"
TAILSCALE_BRANCH="develop"

NIGHT_UUID="nightthemeswitcher@romainvigier.fr"
NIGHT_REPO="https://gitlab.com/rmnvgr/nightthemeswitcher-gnome-shell-extension.git"

LIGHTNING_UUID="lightning-gnome-launcher@avimanyu"
LIGHTNING_REPO="https://gitlab.com/rimal.avimanyu/lightning-gnome-launcher-extension.git"



log() {
    printf '[gnome-extensions] %s\n' "$*"
}

warn() {
    printf '[gnome-extensions] WARNING: %s\n' "$*" >&2
}

die() {
    printf '[gnome-extensions] ERROR: %s\n' "$*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 ||
        die "Required build command is missing: $1"
}


get_shell_major_version() {
    local version

    if command -v rpm >/dev/null 2>&1 && rpm -q gnome-shell >/dev/null 2>&1; then
        version="$(rpm -q --qf '%{VERSION}\n' gnome-shell | head -n1)"
    elif command -v gnome-shell >/dev/null 2>&1; then
        version="$(gnome-shell --version | sed -E 's/.* ([0-9]+).*/\1/')"
    else
        die "Could not determine the installed GNOME Shell version."
    fi

    printf '%s\n' "$version" | sed -E 's/^([0-9]+).*/\1/'
}


supports_shell() {
    local metadata="$1"

    jq -e --arg shell "$SHELL_VERSION" '
        (.["shell-version"] // [])
        | map(tostring)
        | any(. == $shell or startswith($shell + "."))
    ' "$metadata" >/dev/null
}


find_metadata() {
    local root="$1"
    local uuid="$2"
    local metadata
    local found_uuid

    while IFS= read -r metadata; do
        found_uuid="$(jq -r '.uuid // empty' "$metadata" 2>/dev/null || true)"

        if [[ "$found_uuid" == "$uuid" ]]; then
            printf '%s\n' "$metadata"
            return 0
        fi
    done < <(find "$root" -type f -name metadata.json -print)

    return 1
}


install_dir() {
    local uuid="$1"
    local source_dir="$2"
    local metadata="${source_dir}/metadata.json"
    local destination="${INSTALL_DIR}/${uuid}"
    local staging="${INSTALL_DIR}/.${uuid}.new"
    local actual_uuid

    [[ -f "$metadata" ]] ||
        die "Missing metadata.json for $uuid."

    [[ -f "${source_dir}/extension.js" ]] ||
        die "$uuid is missing extension.js; the selected source is not a built/installable GNOME extension."

    jq empty "$metadata" >/dev/null ||
        die "Invalid metadata.json for $uuid."

    actual_uuid="$(jq -er '.uuid // empty' "$metadata")"

    [[ "$actual_uuid" == "$uuid" ]] ||
        die "UUID mismatch: expected '$uuid', found '$actual_uuid'."

    supports_shell "$metadata" ||
        die "$uuid does not declare GNOME Shell $SHELL_VERSION support."

    rm -rf "$staging"
    mkdir -p "$staging"
    cp -a "$source_dir/." "$staging/"

    rm -rf "$destination"
    mv "$staging" "$destination"

    log "Installed $uuid"
}


try_zip() {
    local uuid="$1"
    local zip="$2"
    local tmpdir="$3"
    local extract_dir="${tmpdir}/unzip"
    local metadata

    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"

    unzip -q "$zip" -d "$extract_dir" 2>/dev/null ||
        return 1

    metadata="$(find_metadata "$extract_dir" "$uuid")" ||
        return 1

    supports_shell "$metadata" ||
        return 2

    install_dir "$uuid" "$(dirname "$metadata")"
}


github_api() {
    local url="$1"
    local headers=(
        -H 'Accept: application/vnd.github+json'
        -H 'X-GitHub-Api-Version: 2022-11-28'
    )

    # Optional. Useful in GitHub Actions to avoid the unauthenticated API
    # rate limit during repeated image builds.
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi

    curl --fail --silent --show-error --location \
        "${headers[@]}" \
        "$url"
}


install_release_or_source() {
    local uuid="$1"
    local repo="$2"
    local tmpdir
    local release_json
    local asset_name
    local asset_url
    local branch
    local metadata
    local rc

    tmpdir="$(mktemp -d)"

    log "Resolving $uuid from $repo"

    if release_json="$(github_api "${GITHUB_API}/repos/${repo}/releases/latest" 2>/dev/null)"; then
        log "Latest release: $(jq -r '.tag_name // "unknown"' <<<"$release_json")"

        while IFS=$'\t' read -r asset_name asset_url; do
            [[ -n "$asset_url" ]] || continue

            log "Trying release ZIP: $asset_name"

            if ! curl --fail --silent --show-error --location \
                "$asset_url" \
                -o "$tmpdir/release.zip"; then
                continue
            fi

            set +e
            try_zip "$uuid" "$tmpdir/release.zip" "$tmpdir"
            rc=$?
            set -e

            if [[ $rc -eq 0 ]]; then
                rm -rf "$tmpdir"
                return 0
            fi
        done < <(
            jq -r '
                .assets[]
                | select(.name | ascii_downcase | endswith(".zip"))
                | [.name, .browser_download_url]
                | @tsv
            ' <<<"$release_json"
        )
    fi

    branch="$(github_api "${GITHUB_API}/repos/${repo}" | jq -er '.default_branch')"

    log "No compatible release ZIP; inspecting ${repo}@${branch}"

    curl --fail --silent --show-error --location \
        "https://github.com/${repo}/archive/refs/heads/${branch}.zip" \
        -o "$tmpdir/source.zip"

    mkdir -p "$tmpdir/source"
    unzip -q "$tmpdir/source.zip" -d "$tmpdir/source"

    metadata="$(find_metadata "$tmpdir/source" "$uuid" || true)"

    if [[ -n "$metadata" ]] && supports_shell "$metadata"; then
        install_dir "$uuid" "$(dirname "$metadata")"
        rm -rf "$tmpdir"
        return 0
    fi

    rm -rf "$tmpdir"
    die "No directly installable GNOME-$SHELL_VERSION artifact found for $uuid in $repo."
}




install_custom_command_menu() {
    local tmpdir
    local releases_json
    local tag
    local zipball_url
    local metadata
    local source_dir
    local schema_name
    local schema_file

    tmpdir="$(mktemp -d)"

    log "Resolving newest stable $CUSTOM_COMMAND_UUID release compatible with GNOME $SHELL_VERSION"

    # Custom Command Menu publishes an installable release ZIP, but we install
    # from the source snapshot of the same stable release tag instead.
    #
    # This avoids depending on the separately-packaged release asset while
    # still following upstream stable releases automatically.
    releases_json="$(
        github_api "${GITHUB_API}/repos/${CUSTOM_COMMAND_REPO}/releases?per_page=20"
    )"

    while IFS=$'\t' read -r tag zipball_url; do
        [[ -n "$tag" && -n "$zipball_url" ]] || continue

        log "Trying Custom Command Menu stable release $tag"

        rm -rf "$tmpdir/source"
        mkdir -p "$tmpdir/source"

        if ! curl --fail --silent --show-error --location \
            "$zipball_url" \
            -o "$tmpdir/custom-command-menu-source.zip"; then
            warn "Could not download Custom Command Menu source for $tag"
            continue
        fi

        if ! unzip -q "$tmpdir/custom-command-menu-source.zip" -d "$tmpdir/source"; then
            warn "Could not extract Custom Command Menu source for $tag"
            continue
        fi

        metadata="$(find_metadata "$tmpdir/source" "$CUSTOM_COMMAND_UUID" || true)"
        [[ -n "$metadata" ]] || {
            log "Custom Command Menu $tag does not contain the expected UUID"
            continue
        }

        source_dir="$(dirname "$metadata")"

        if ! supports_shell "$metadata"; then
            log "Custom Command Menu $tag is not compatible with GNOME $SHELL_VERSION"
            continue
        fi

        # Validate the project-specific files required by this extension.
        for required_file in \
            extension.js \
            prefs.js \
            commandsUI.js \
            about.js
        do
            [[ -f "$source_dir/$required_file" ]] ||
                die "Custom Command Menu $tag is missing required file: $required_file"
        done

        schema_name="$(jq -er '.["settings-schema"] // empty' "$metadata")"
        [[ -n "$schema_name" ]] ||
            die "Custom Command Menu $tag does not declare settings-schema in metadata.json"

        schema_file="$source_dir/schemas/${schema_name}.gschema.xml"
        [[ -f "$schema_file" ]] ||
            die "Custom Command Menu $tag is missing its GSettings schema: $schema_file"

        install_dir "$CUSTOM_COMMAND_UUID" "$source_dir"

        log "Selected Custom Command Menu $tag for GNOME $SHELL_VERSION"

        rm -rf "$tmpdir"
        return 0
    done < <(
        jq -r '
            .[]
            | select(.draft == false and .prerelease == false)
            | [.tag_name, .zipball_url]
            | @tsv
        ' <<<"$releases_json"
    )

    rm -rf "$tmpdir"

    die "No stable Custom Command Menu release compatible with GNOME $SHELL_VERSION was found."
}

install_tilingshell() {
    local tmpdir
    local releases_json
    local tag
    local prerelease
    local asset_name
    local asset_url
    local rc

    tmpdir="$(mktemp -d)"

    log "Resolving newest packaged $TILING_UUID release compatible with GNOME $SHELL_VERSION"

    # GitHub's /releases/latest endpoint excludes prereleases. That is a
    # problem for Tiling Shell on GNOME 50 because stable v17.3 targets
    # GNOME 45-49, while the current v18 release candidate includes GNOME 50.
    #
    # Query the release list instead and validate each packaged ZIP using the
    # same UUID + shell-version checks as every other extension.
    releases_json="$(
        github_api "${GITHUB_API}/repos/${TILING_REPO}/releases?per_page=20"
    )"

    while IFS=$'\t' read -r tag prerelease asset_name asset_url; do
        [[ -n "$asset_url" ]] || continue

        if [[ "$prerelease" == "true" ]]; then
            log "Trying Tiling Shell prerelease $tag asset: $asset_name"
        else
            log "Trying Tiling Shell release $tag asset: $asset_name"
        fi

        curl --fail --silent --show-error --location \
            "$asset_url" \
            -o "$tmpdir/tilingshell.zip" ||
            continue

        set +e
        try_zip "$TILING_UUID" "$tmpdir/tilingshell.zip" "$tmpdir"
        rc=$?
        set -e

        case "$rc" in
            0)
                log "Selected Tiling Shell $tag for GNOME $SHELL_VERSION"
                rm -rf "$tmpdir"
                return 0
                ;;
            2)
                log "Tiling Shell $tag / $asset_name is not compatible with GNOME $SHELL_VERSION"
                ;;
            *)
                log "Tiling Shell $tag / $asset_name is not an installable extension ZIP"
                ;;
        esac
    done < <(
        jq -r '
            .[]
            | select(.draft == false)
            | . as $release
            | .assets[]
            | select(.name | ascii_downcase | endswith(".zip"))
            | [
                $release.tag_name,
                ($release.prerelease | tostring),
                .name,
                .browser_download_url
              ]
            | @tsv
        ' <<<"$releases_json"
    )

    rm -rf "$tmpdir"

    die "No packaged Tiling Shell release compatible with GNOME $SHELL_VERSION was found."
}

install_budslink() {
    local tmpdir
    local archive
    local metadata
    local source_dir
    local staged
    local item

    tmpdir="$(mktemp -d)"
    archive="$tmpdir/budslink.zip"
    staged="$tmpdir/staged"

    log "Installing $BUDSLINK_UUID from pinned upstream commit ${BUDSLINK_REF:0:12}"

    # The current Gnome-Extension branch is no longer a self-contained
    # installable BudsLink Companion extension. Bluefin itself pins this
    # known-good upstream commit, where the standalone extension still
    # contains metadata.json and declares GNOME Shell 46-50 support.
    curl --fail --silent --show-error --location \
        "https://github.com/maniacx/BudsLink-Companion/archive/${BUDSLINK_REF}.zip" \
        -o "$archive"

    mkdir -p "$tmpdir/source" "$staged"
    unzip -q "$archive" -d "$tmpdir/source"

    metadata="$(find_metadata "$tmpdir/source" "$BUDSLINK_UUID")" ||
        die "Pinned BudsLink commit $BUDSLINK_REF does not contain $BUDSLINK_UUID."

    source_dir="$(dirname "$metadata")"

    # Mirror the exact extension payload Bluefin packages.
    for item in \
        extension.js \
        prefs.js \
        metadata.json \
        stylesheet.css \
        icons \
        lib \
        preferences \
        ui \
        schemas \
        LICENSE \
        README.md
    do
        if [[ -e "$source_dir/$item" ]]; then
            cp -a "$source_dir/$item" "$staged/"
        fi
    done

    [[ -f "$staged/extension.js" ]] ||
        die "Pinned BudsLink commit is missing extension.js."

    [[ -f "$staged/metadata.json" ]] ||
        die "Pinned BudsLink commit is missing metadata.json."

    install_dir "$BUDSLINK_UUID" "$staged"

    rm -rf "$tmpdir"
}


install_blur() {
    local tmpdir
    local metadata
    local staged_metadata
    local rc

    tmpdir="$(mktemp -d)"

    log "Building $BLUR_UUID from current upstream master"

    git clone -q --depth=1 "$BLUR_REPO" "$tmpdir/repo"

    # Prefer upstream's own installation process, but stage it into an isolated
    # HOME so nothing is installed into root's real home during the image build.
    mkdir -p "$tmpdir/home"

    set +e
    (
        cd "$tmpdir/repo"
        HOME="$tmpdir/home" make install
    )
    rc=$?
    set -e

    if [[ $rc -eq 0 ]]; then
        staged_metadata="$(find_metadata "$tmpdir/home" "$BLUR_UUID" || true)"

        if [[ -n "$staged_metadata" ]] && supports_shell "$staged_metadata"; then
            install_dir "$BLUR_UUID" "$(dirname "$staged_metadata")"
            rm -rf "$tmpdir"
            return 0
        fi
    fi

    # Upstream master is also laid out as an extension tree. Keep this as a
    # fallback if upstream's install target changes or expects a live session.
    metadata="$(find_metadata "$tmpdir/repo" "$BLUR_UUID")" ||
        die "Blur My Shell metadata was not found."

    install_dir "$BLUR_UUID" "$(dirname "$metadata")"

    rm -rf "$tmpdir"
}


install_just_perfection() {
    local tmpdir
    local metadata
    local zip
    local rc

    tmpdir="$(mktemp -d)"

    log "Building $JUST_UUID from canonical GNOME GitLab upstream"

    git clone -q --depth=1 "$JUST_REPO" "$tmpdir/repo"

    (
        cd "$tmpdir/repo"
        ./scripts/build.sh
    )

    # Prefer a ZIP produced by the upstream builder.
    while IFS= read -r zip; do
        log "Trying Just Perfection build artifact: $(basename "$zip")"

        set +e
        try_zip "$JUST_UUID" "$zip" "$tmpdir"
        rc=$?
        set -e

        if [[ $rc -eq 0 ]]; then
            rm -rf "$tmpdir"
            return 0
        fi
    done < <(find "$tmpdir/repo" -type f -name '*.zip' -print)

    # Some revisions leave the fully-built extension tree in the checkout.
    metadata="$(find_metadata "$tmpdir/repo" "$JUST_UUID" || true)"

    if [[ -n "$metadata" ]] && supports_shell "$metadata"; then
        install_dir "$JUST_UUID" "$(dirname "$metadata")"
        rm -rf "$tmpdir"
        return 0
    fi

    # Final fallback: use upstream's documented install mode, isolated inside a
    # temporary HOME, then copy the result into the system-wide extension path.
    mkdir -p "$tmpdir/home"

    (
        cd "$tmpdir/repo"
        HOME="$tmpdir/home" ./scripts/build.sh -i
    )

    metadata="$(find_metadata "$tmpdir/home" "$JUST_UUID")" ||
        die "Just Perfection build completed but no installable extension was produced."

    install_dir "$JUST_UUID" "$(dirname "$metadata")"

    rm -rf "$tmpdir"
}


install_tailscale() {
    local tmpdir
    local metadata

    tmpdir="$(mktemp -d)"

    log "Building $TAILSCALE_UUID from upstream $TAILSCALE_BRANCH branch"

    git clone -q \
        --depth=1 \
        --branch "$TAILSCALE_BRANCH" \
        "$TAILSCALE_REPO" \
        "$tmpdir/repo"

    (
        cd "$tmpdir/repo"
        make build
    )

    metadata="$(find_metadata "$tmpdir/repo" "$TAILSCALE_UUID")" ||
        die "Tailscale QS build produced no $TAILSCALE_UUID extension."

    install_dir "$TAILSCALE_UUID" "$(dirname "$metadata")"

    rm -rf "$tmpdir"
}


build_night_tag() {
    local repo_dir="$1"
    local tag="$2"
    local work_dir="$3"
    local stage="${work_dir}/stage"
    local metadata

    rm -rf "${repo_dir}/builddir" "$stage"
    mkdir -p "$stage"

    git -C "$repo_dir" checkout -q --force "$tag"
    git -C "$repo_dir" clean -q -fdx

    log "Trying Night Theme Switcher tag $tag"

    if ! (
        cd "$repo_dir"
        meson setup builddir --prefix=/usr >/dev/null
        DESTDIR="$stage" meson install -C builddir >/dev/null
    ); then
        warn "Night Theme Switcher tag $tag did not build; trying an older tag."
        return 1
    fi

    metadata="$(find_metadata "$stage" "$NIGHT_UUID" || true)"

    [[ -n "$metadata" ]] ||
        return 1

    supports_shell "$metadata" ||
        return 2

    install_dir "$NIGHT_UUID" "$(dirname "$metadata")"
}


install_night() {
    local tmpdir
    local tag
    local rc

    tmpdir="$(mktemp -d)"

    log "Resolving newest upstream Night Theme Switcher tag for GNOME $SHELL_VERSION"

    # We need tags because upstream main tracks the next GNOME Shell release.
    # Example: current main/version 84 targets GNOME 51, while tag 83 targets 50.
    git clone -q "$NIGHT_REPO" "$tmpdir/repo"

    while IFS= read -r tag; do
        [[ -n "$tag" ]] || continue

        set +e
        build_night_tag "$tmpdir/repo" "$tag" "$tmpdir"
        rc=$?
        set -e

        case "$rc" in
            0)
                log "Selected Night Theme Switcher tag $tag for GNOME $SHELL_VERSION"
                rm -rf "$tmpdir"
                return 0
                ;;
            2)
                log "Night Theme Switcher tag $tag is not for GNOME $SHELL_VERSION"
                ;;
        esac
    done < <(
        git -C "$tmpdir/repo" tag --list |
            grep -E '^[vV]?[0-9]+([.][0-9]+)*$' |
            awk '{
                original=$0
                normalized=$0
                sub(/^[vV]/, "", normalized)
                print normalized "\t" original
            }' |
            sort -t $'\t' -k1,1Vr |
            cut -f2-
    )

    rm -rf "$tmpdir"
    die "Could not find a buildable Night Theme Switcher tag compatible with GNOME $SHELL_VERSION."
}


install_lightning() {
    local tmpdir
    local metadata
    local stage
    local rc

    tmpdir="$(mktemp -d)"
    stage="$tmpdir/stage"

    log "Installing $LIGHTNING_UUID from canonical GitLab upstream"

    git clone -q --depth=1 "$LIGHTNING_REPO" "$tmpdir/repo"

    # Current upstream is directly installable.
    metadata="$(find_metadata "$tmpdir/repo" "$LIGHTNING_UUID" || true)"

    if [[ -n "$metadata" ]] && supports_shell "$metadata"; then
        install_dir "$LIGHTNING_UUID" "$(dirname "$metadata")"
        rm -rf "$tmpdir"
        return 0
    fi

    # If the project later grows a Makefile build step, handle it.
    if [[ -f "$tmpdir/repo/Makefile" ]]; then
        set +e
        (
            cd "$tmpdir/repo"
            make build
        )
        rc=$?
        set -e

        if [[ $rc -eq 0 ]]; then
            metadata="$(find_metadata "$tmpdir/repo" "$LIGHTNING_UUID" || true)"

            if [[ -n "$metadata" ]] && supports_shell "$metadata"; then
                install_dir "$LIGHTNING_UUID" "$(dirname "$metadata")"
                rm -rf "$tmpdir"
                return 0
            fi
        fi
    fi

    # Also support a future Meson conversion without changing this installer.
    if [[ -f "$tmpdir/repo/meson.build" ]]; then
        mkdir -p "$stage"

        set +e
        (
            cd "$tmpdir/repo"
            meson setup builddir --prefix=/usr
            DESTDIR="$stage" meson install -C builddir
        )
        rc=$?
        set -e

        if [[ $rc -eq 0 ]]; then
            metadata="$(find_metadata "$stage" "$LIGHTNING_UUID" || true)"

            if [[ -n "$metadata" ]] && supports_shell "$metadata"; then
                install_dir "$LIGHTNING_UUID" "$(dirname "$metadata")"
                rm -rf "$tmpdir"
                return 0
            fi
        fi
    fi

    rm -rf "$tmpdir"
    die "Lightning upstream did not produce an installable GNOME-$SHELL_VERSION extension."
}



install_asdb() {
    local tmpdir
    local rc

    tmpdir="$(mktemp -d)"

    log "Installing $ASDB_UUID"

    curl --fail --silent --show-error --location \
        "$ASDB_ZIP_URL" \
        -o "$tmpdir/asdb.zip"

    set +e
    try_zip "$ASDB_UUID" "$tmpdir/asdb.zip" "$tmpdir"
    rc=$?
    set -e

    rm -rf "$tmpdir"

    case "$rc" in
        0)
            return 0
            ;;
        2)
            die "$ASDB_UUID does not declare GNOME Shell $SHELL_VERSION support."
            ;;
        *)
            die "ASDB ZIP is missing or does not contain $ASDB_UUID."
            ;;
    esac
}


verify_final_install() {
    local entry
    local uuid

    log "Verifying installed extension UUIDs..."

    for entry in "${RELEASE_EXTENSIONS[@]}"; do
        uuid="${entry%%|*}"

        [[ -f "${INSTALL_DIR}/${uuid}/metadata.json" ]] ||
            die "Final verification failed: $uuid is missing."
    done

    for uuid in \
        "$CUSTOM_COMMAND_UUID" \
        "$TILING_UUID" \
        "$BUDSLINK_UUID" \
        "$BLUR_UUID" \
        "$JUST_UUID" \
        "$TAILSCALE_UUID" \
        "$NIGHT_UUID" \
        "$LIGHTNING_UUID" \
        "$ASDB_UUID"
    do
        [[ -f "${INSTALL_DIR}/${uuid}/metadata.json" ]] ||
            die "Final verification failed: $uuid is missing."
    done
}


main() {
    local entry
    local uuid
    local repo
    local command_name

    [[ $EUID -eq 0 ]] ||
        die "Run this script as root during the image build."

    for command_name in \
        curl \
        jq \
        unzip \
        git \
        make \
        gettext \
        meson \
        glib-compile-schemas \
        glib-compile-resources
    do
        need "$command_name"
    done

    SHELL_VERSION="$(get_shell_major_version)"

    log "Detected GNOME Shell major version: $SHELL_VERSION"
    log "Installing extensions into: $INSTALL_DIR"

    mkdir -p "$INSTALL_DIR"

    for entry in "${RELEASE_EXTENSIONS[@]}"; do
        IFS='|' read -r uuid repo <<<"$entry"
        install_release_or_source "$uuid" "$repo"
    done

    install_custom_command_menu
    install_tilingshell
    install_budslink
    install_blur
    install_just_perfection
    install_tailscale
    install_night
    install_lightning
    install_asdb

    verify_final_install

    log "All GNOME extensions installed successfully."
}


main "$@"
