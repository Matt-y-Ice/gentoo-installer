#!/bin/bash

# Gentoo install bash script. This script automates Gentoo install process, resulting in
# a complete minimal installation, i.e., not desktop environment (DE) or window manager (WM).
# TODO: Add DE or WM installation and configuration support
# TODO: Add CPU and video card detection
#
# Arg1: full path to disk device to partition, e.g., /dev/sda

set -euo pipefail

# Constant variables:
DISK=$1
STAGE3='https://distfiles.gentoo.org/releases/amd64/autobuilds/20250921T170345Z/stage3-amd64-desktop-openrc-20250921T170345Z.tar.xz'

CYAN='\e[1;36m'
GREEN='\e[1;32m'
RED='\e[1;31m'
RESET='\e[0m'

clear

#########################################################################################
# STAGE 1 - System preparation
#########################################################################################

if [ -z $DISK ]; then
    echo -e "${RED}Error: Arg1 (disk device path) not passed to install script.${RED}"
    # TODO: Add code to prompt for path to disk device as input if not passed to Arg1
fi

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}*** THIS SCRIPT REQUIRES ROOT PRIVILEDGES! ***${REST}"
    exec sudo "$0" "$@"
fi

# Partition disk
wipefs --all "$DISK"
echo -e 'size=1G, type=U\n size=4G type=S \n size=+' | sfdisk --label=gpt "$DISK"
ptype=$(sfdisk --json "$disk" | grep '"label":' | awk -F '"' '{print $4}')
if [ "$ptype" = "dos" ]; then
    echo "${GREEN}MBR detected, setting boot flag on ${DISK}1...${RESET}"
    sfdisk --activate "$DISK" 1
else
    echo "GPT detected, no boot flag needed."
fi

# Format disk
mkfs.vfat -F 32 ${DISK}1
mkswap ${DISK}2
swapon ${DISK}2
mkfs.xfs -f ${DISK}3

# Mount root
mkdir --parents /mnt/gentoo
mount ${DISK}3 /mnt/gentoo

# Download and install stage 3 file
wget ${STAGE3} --directory-prefix=/mnt/gentoo
tar xpvf /mnt/gentoo/stage3-*.tar.xz --xattrs-include'*.*' --numeric-owner -C /mnt/gentoo

# Prepare for Chroot
echo "DISK=\"${DISK}1\"" > /mnt/gentoo/root/chroot_vars.sh
# TODO: Add logic to automatically determine and add compiler flags to make.conf
rm /mnt/gentoo/etc/portage/make.conf
cp ./make.conf /mnt/gentoo/etc/portage/make.conf
cp --dereference /etc/resolv.conf /mnt/gentoo/etc
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run
cp ./chroot-script.sh /mnt/gentoo/root

# Chroot - Stage 2 begins in chroot script
env -i HOME=$HOME TERM=$TERM chroot /mnt/gentoo /bin/bash -c "/root/chroot-script.sh"

echo -e "${GREEN}+++ Chroot setup completed -- back on host system.${RESET}"

cd
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo
