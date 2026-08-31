#!/usr/bin/bash

IMAGE="ghcr.io/therivernix/ublue-spinosauros"

function list_tags() {
  local filter="$1"

  skopeo list-tags "docker://${IMAGE}" \
    | jq -r '.Tags[]' \
    | grep -E --color=never "$filter" \
    | sort -rV
}

echo "Current image:"
rpm-ostree status | grep -i "ostree-image"

echo

REBASE_TARGET="${IMAGE}:latest"

if gum confirm --default=no "Would you like to pin to a specific build date?"; then
    echo "Fetching available builds..."

    # Adjust this depending on your tag format
    filter="latest-[0-9]{8}"

    valid_tags=( $(list_tags "$filter") )

    if [[ "${#valid_tags[@]}" -eq 0 ]]; then
        echo "No dated builds found for ${IMAGE}"
        exit 1
    fi

    selected_tag="$(gum choose cancel "${valid_tags[@]}")"

    [[ "$selected_tag" == "cancel" || "$selected_tag" == "" ]] && exit 0

    REBASE_TARGET="${IMAGE}:${selected_tag}"
fi


gum confirm "Confirm rebase to ${REBASE_TARGET}?" || exit 1


if grep -q "^LockLayering=true" /etc/rpm-ostreed.conf; then
    pkexec bootc switch --enforce-container-sigpolicy "${REBASE_TARGET}"
else
    rpm-ostree rebase ostree-image-signed:docker://"${REBASE_TARGET}"
fi
