spino-install-flatpaks:
    bash /usr/share/ublue-os-spinosauros/scripts/flatpaks/installFlatpaks.sh

spino-update-flatpaks:
    flatpak update -y
    
spino-remove-flatpaks:
    bash /usr/share/ublue-os-spinosauros/scripts/flatpaks/removeFlatpaks.sh
