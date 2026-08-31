# Build context / scripts
FROM scratch AS ctx

COPY build_files /
COPY system_files /system_files

# Homebrew integration files
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /brew_system_files


# Base Image
FROM ghcr.io/ublue-os/silverblue-main

## Other possible base images:
# FROM ghcr.io/ublue-os/bazzite:testing
# FROM ghcr.io/ublue-os/aurora:stable
# FROM ghcr.io/ublue-os/bluefin-nvidia-open:stable

### Homebrew

# Copy Homebrew files into the final image
COPY --from=ctx /brew_system_files/ /

# Enable Homebrew setup and update services
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/systemctl preset brew-setup.service && \
    /usr/bin/systemctl preset brew-update.timer && \
    /usr/bin/systemctl preset brew-upgrade.timer


### [IM]MUTABLE /opt

# RUN rm /opt && mkdir /opt


### MODIFICATIONS

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh


### LINTING

RUN bootc container lint
