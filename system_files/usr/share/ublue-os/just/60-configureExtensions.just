spino-enable-extensions:
    bash /usr/share/ublue-os-spinosauros/scripts/gnome-extensions/enableExtensions.sh

spino-configure-extensions:
    dconf load /org/gnome/shell/extensions/ < /usr/share/ublue-os-spinosauros/dconf/extension-settings.dconf
    
