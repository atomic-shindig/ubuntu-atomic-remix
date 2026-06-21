image := env("IMAGE_FULL", "localhost/mkosi-bootc:latest")
bootable_img := env("IMAGE_FULL", "localhost/ubuntu-bootc-remix:latest")
filesystem := env("BUILD_FILESYSTEM", "btrfs")

default:
    #!/usr/bin/env bash
    set -xeuo pipefail
    just build
    sudo just load
    sudo just lint
    sudo just ostree-rechunk
    sudo env BUILD_BASE_DIR=/tmp just disk-image
    vmbuddy -f /tmp/bootable.img

build:
    sudo rm -rf mkosi.output/*
    mkosi -B --debug

lint:
    podman run --rm -it --entrypoint=bootc {{ image }} container lint

load:
    #!/usr/bin/env bash
    set -x
    podman load -i "$(find mkosi.output/* -maxdepth 0 -type d -printf "%T@ ,%p\n" -iname "_*" -print0 | sort -n | head -n1 | cut -d, -f2)" -q | cut -d: -f3 | xargs -I{} podman tag {} {{image}}
    podman build --security-opt label=type:unconfined_t -f Containerfile -t localhost/ubuntu-bootc-remix:latest

ostree-rechunk:
    #!/usr/bin/env bash
    sudo podman run --rm \
          --privileged \
          -t \
          -v /var/lib/containers:/var/lib/containers \
          "quay.io/centos-bootc/centos-bootc:stream10" \
          /usr/libexec/bootc-base-imagectl rechunk --max-layers 120 \
          "{{image}}" \
          "{{image}}" || exit 1

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -v "${BUILD_BASE_DIR:-.}:/data" \
        --security-opt label=type:unconfined_t \
        "{{bootable_img}}" bootc {{ARGS}}

disk-image $filesystem=filesystem:
    #!/usr/bin/env bash
    if [ ! -e "${BUILD_BASE_DIR:-.}/bootable.img" ] ; then
        fallocate -l 20G "${BUILD_BASE_DIR:-.}/bootable.img"
    fi
    just bootc install to-disk --generic-image --bootloader systemd --via-loopback /data/bootable.img --filesystem "${filesystem}" --wipe --composefs-backend

rechunk:
    #!/usr/bin/env bash
    IMG="{{ image }}"
    # podman pull $IMG # image must be available locally
    export CHUNKAH_CONFIG_STR="$(sudo podman inspect "${IMG}")"
    podman run --rm "--mount=type=image,src=${IMG},dest=/chunkah" -e CHUNKAH_CONFIG_STR quay.io/jlebon/chunkah build --label ostree.bootable=1 --compressed --max-layers 67 | \
        podman load | \
        sort -n | \
        head -n1 | \
        cut -d, -f2 | \
        cut -d: -f3 | \
        xargs -I{} sudo podman tag {} {{image}}

clean:
    mkosi clean
    sudo rm -r mkosi.tools/ mkosi.cache/
