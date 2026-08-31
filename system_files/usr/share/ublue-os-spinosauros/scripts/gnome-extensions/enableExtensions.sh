#!/usr/bin/env bash

set -euo pipefail

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

echo "All extensions enabled."
