FROM localhost/mkosi-bootc:latest

RUN rm -rf /home /root /srv /var /ostree && \
    mkdir -p \
    /sysroot /boot /usr/lib/ostree /var \
    /home /root /srv /opt /mnt \
    /snap && \
    ln -sfn sysroot/ostree /ostree && \
    printf '%s\n' \
    'd /var/home     0755 root root -' \
    'd /var/roothome 0700 root root -' \
    'd /var/srv      0755 root root -' \
    'd /var/opt      0755 root root -' \
    'd /var/mnt      0755 root root -' \
    'd /var/usrlocal 0755 root root -' \
    'd /run/media    0755 root root -' \
    'd /var/lib/snapd/snap 0755 root root -' \
    | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' \
    | tee /usr/lib/ostree/prepare-root.conf

RUN bootc container lint