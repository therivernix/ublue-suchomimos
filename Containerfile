# Build context / scripts
FROM scratch AS ctx

COPY build_files /
COPY system_files /system_files

# Homebrew files
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /brew_system_files


# Base Image
FROM ghcr.io/ublue-os/silverblue-main

# Copy Homebrew into the final image
COPY --from=ctx /brew_system_files/ /

# Make Homebrew available during the image build
ENV PATH="/var/home/linuxbrew/.linuxbrew/bin:/var/home/linuxbrew/.linuxbrew/sbin:${PATH}"

# Enable Homebrew services
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/systemctl preset brew-setup.service && \
    /usr/bin/systemctl preset brew-update.timer && \
    /usr/bin/systemctl preset brew-upgrade.timer

# Run build script
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Lint
RUN bootc container lint
