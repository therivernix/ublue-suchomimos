#!/usr/bin/env bash
set -euo pipefail

SENTINEL="$HOME/.local/state/spinosauros-keybindings.done"

if [[ -f "$SENTINEL" ]]; then
    exit 0
fi

mkdir -p "$(dirname "$SENTINEL")"

touch "$SENTINEL"

dconf load /org/gnome/settings-daemon/plugins/media-keys/ < /usr/share/ublue-os-spinosauros/dconf/media-keys.dconf
dconf load /org/gnome/desktop/wm/keybindings/ < /usr/share/ublue-os-spinosauros/dconf/wm-keybindings.dconf

extensions=(
  "appindicatorsupport@rgcjonas.gmail.com"
  "caffeine@patapon.info"
  "clipboard-indicator@tudmotu.com"
  "custom-command-list@storageb.github.com"
  "hide-minimized@danigm.net"
  "hotedge@jonathan.jdoda.ca"
  "just-perfection-desktop@just-perfection"
  "nightthemeswitcher@romainvigier.fr"
  "quick-settings-audio-panel@rayzeq.github.io"
  "smile-extension@mijorus.it"
  "tailscale-gnome-qs@tailscale-qs.github.io"
  "Studi-Brightness-Control@matey-0"
  "lightning-gnome-launcher@avimanyu"
  "disable-workspace-switch-animation@osmancevik"
  "tilingshell@ferrarodomenico.com"
  "BudsLink-Companion@maniacx.github.com"
)

for ext in "${extensions[@]}"; do
  echo "Enabling: $ext"
  gnome-extensions enable "$ext"
done

