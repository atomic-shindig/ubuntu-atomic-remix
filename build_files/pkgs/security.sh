#!/bin/bash

set -ouex pipefail

apt -y install apparmor apparmor-utils lsb-release wget gnupg
apt -y install ufw gufw

mkdir -p /usr/local/etc/

cp -a /etc/apparmor /usr/local/etc/
cp -a /etc/apparmor.d /usr/local/etc/