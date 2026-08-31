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


### Remove GNOME Software

# Remove the GNOME Software application from the image.
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


### Install Homebrew applications

# Homebrew is installed by the UBlue brew image.
# Make brew available during the image build.
export PATH="/var/home/linuxbrew/.linuxbrew/bin:/var/home/linuxbrew/.linuxbrew/sbin:${PATH}"

# Verify Homebrew is available
command -v brew
brew --version

# Add the UBlue tap and install 1Password
brew tap --trust ublue-os/tap
brew install --cask 1password-gui-linux


### Removing built-in GNOME Shell extensions

rm -rf /usr/share/gnome-shell/extensions/apps-menu@gnome-shell-extensions.gcampax.github.com
rm -rf /usr/share/gnome-shell/extensions/launch-new-instance@gnome-shell-extensions.gcampax.github.com
rm -rf /usr/share/gnome-shell/extensions/places-menu@gnome-shell-extensions.gcampax.github.com
rm -rf /usr/share/gnome-shell/extensions/window-list@gnome-shell-extensions.gcampax.github.com


### Compile GSettings schemas for GNOME extensions

find /usr/share/gnome-shell/extensions -type d -name schemas \
    -exec glib-compile-schemas {} \;


### Enable System Unit File

systemctl enable podman.socket
