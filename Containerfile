FROM scratch AS ctx
COPY build_files /

FROM docker.io/library/ubuntu:resolute

ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    cp -r /ctx/sandbox/. /

RUN sed -i 's/main$/main restricted universe multiverse/' /etc/apt/sources.list && \
    apt-get update

RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root --mount=type=tmpfs,dst=/boot \
    apt-get update -y && \
    apt-get -y install wget ca-certificates git curl gpg lsb-release && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL -A "Mozilla/5.0 (X11; Linux x86_64)" https://gitlab.com/afrd.gpg | gpg --dearmor -vo /etc/apt/keyrings/xanmod-archive-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/xanmod-release.list && \
    apt-get update -y && \
    apt-get install -y linux-xanmod-lts-x64v3 clang libelf-dev lld llvm && \
    apt-get install -y btrfs-progs dosfstools e2fsprogs fdisk skopeo systemd systemd-boot* xfsprogs && \
    cp /boot/vmlinuz-* "$(find /usr/lib/modules -maxdepth 1 -type d | tail -n 1)/vmlinuz" && \
    apt-get clean -y


# Firmware, codecs and encryption
RUN apt-get update && apt-get install -y --no-install-recommends \
    amd64-microcode \
    linux-firmware \
    libgl1-mesa-dri mesa-vulkan-drivers libegl-mesa0 libglx-mesa0 libavcodec-extra \
    plymouth \
    plymouth-themes \
    systemd-cryptsetup \
    cryptsetup \
    cryptsetup-initramfs \
    dosfstools \
    keyutils \
    systemd-homed \
    systemd-zram-generator \
    tpm2-tools \
    libtss2-rc0 \
    steam-devices \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup a temporary root passwd (changeme) for dev purposes
# RUN apt-get update -y && apt-get install -y whois
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

RUN apt-get update && apt-get install -y curl && \
    #
    apt-get update && apt-get install --fix-missing -y \
    sudo vim flatpak distrobox \
    cups hplip \
    ubuntu-desktop-minimal python3-nautilus && \
    #
    systemctl enable gdm && \
    apt-get remove -y packagekit totem snapshot shotwell simple-scan \
    transmission-gtk rhythmbox update-manager gnome-calculator gnome-terminal remmina usb-creator-gtk \
    gnome-clocks deja-dup "libreoffice*" || true && \
    apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/config.sh


ENV CARGO_HOME=/tmp/rust
ENV RUSTUP_HOME=/tmp/rust
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root --mount=type=tmpfs,dst=/boot \
    curl -fsSL https://raw.githubusercontent.com/bootc-shindig/bootc-deb/refs/heads/main/bootc-deb.asc | sudo gpg --dearmor -o /usr/share/keyrings/bootc-deb.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/bootc-deb.gpg] https://bootc-shindig.github.io/bootc-deb/debian stable main" | sudo tee /etc/apt/sources.list.d/bootc-deb.list && \
    apt-get update -y && apt-get install -y bootc && \
    dracut --force "$(find /usr/lib/modules -maxdepth 1 -type d | tail -n 1)/initramfs.img" && \
    apt-get autoremove -y && \
    apt-get clean -y

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/mount-system.sh

COPY --from=ghcr.io/ublue-os/brew:latest /system_files /
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/systemctl preset brew-setup.service && \
    /usr/bin/systemctl preset brew-update.timer && \
    /usr/bin/systemctl preset brew-upgrade.timer


RUN rm -rf /var/cache/

# https://bootc-dev.github.io/bootc/bootc-images.html#standard-metadata-for-bootc-compatible-images
LABEL containers.bootc 1

RUN bootc container lint
