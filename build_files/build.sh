bash
#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images.
#
# List of RPM Fusion packages:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Install packages from Fedora repositories
dnf5 install -y \
    firefox \
    firefox-langpacks

# Disable RPM-OSTree package management support in GNOME Software
#
# This is the same approach used by Universal Blue for Silverblue-based
# images. Since this image is based on silverblue-main, remove it directly.
dnf5 remove -y \
    gnome-software

# Use a COPR example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
#
# Disable COPRs so they don't end up enabled on the final image:
#
# dnf5 -y copr disable ublue-os/staging


### Removing built-in GNOME Shell extensions

rm -rf /usr/share/gnome-shell/extensions/apps-menu@gnome-shell-extensions.gcampax.github.com
rm -rf /usr/share/gnome-shell/extensions/launch-new-instance@gnome-shell-extensions.gcampax.github.com
rm -rf /usr/share/gnome-shell/extensions/places-menu@gnome-shell-extensions.gcampax.github.com
rm -rf /usr/share/gnome-shell/extensions/window-list@gnome-shell-extensions.gcampax.github.com


### Compile GSettings schemas for GNOME extensions

find /usr/share/gnome-shell/extensions -type d -name schemas \
    -exec glib-compile-schemas {} \;


### Example for enabling a System Unit File

systemctl enable podman.socket
