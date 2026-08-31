spino-install-asdbctl:
    #!/usr/bin/env bash
    cp -r /usr/share/ublue-os-spinosauros/asdbctl/ /tmp/
    cd /tmp/asdbctl/
    cargo install --path .
    
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    
    rm -rf /tmp/asdbctl/
    
    sudo udevadm control --reload-rules
    sudo udevadm trigger
