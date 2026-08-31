#!/bin/bash

set -ouex pipefail

rm -f /etc/dconf/db/distro.d/02-bluefin-keybindings

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y firefox firefox-langpacks 
#gnome-software-rpm-ostree

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

# Removing built-in extensions
rm -rf /usr/share/gnome-shell/extensions/search-light@icedman.github.com
rm -rf /usr/share/gnome-shell/extensions/apps-menu@gnome-shell-extensions.gcampax.github.com
rm -rf /usr/share/gnome-shell/extensions/launch-new-instance@gnome-shell-extensions.gcampax.github.com
rm -rf /usr/share/gnome-shell/extensions/places-menu@gnome-shell-extensions.gcampax.github.com
rm -rf /usr/share/gnome-shell/extensions/window-list@gnome-shell-extensions.gcampax.github.com
rm -rf /usr/share/gnome-shell/extensions/logomenu@aryan_k
rm -rf /usr/share/gnome-shell/extensions/tiling-assistant@leleat-on-github
rm -rf /usr/share/gnome-shell/extensions/blur-my-shell@aunetx

#### Example for enabling a System Unit File

systemctl enable podman.socket
