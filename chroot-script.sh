#!/bin/bash

# Gentoo install chroot script. This script automates post-chroot Gentoo install process.

set -euo pipefail
# Flush the environment post-chroot
/usr/sbin/env-update
source /etc/profile

# Constant variables:
CYAN='\e[1;36m'
GREEN='\e[1;32m'
RED='\e[1;31m'
RESET='\e[0m'

# Configure portage
emerge-webrsync
#eselect profile set TODO: figure out profile # to set
emerge --oneshot app-portage/cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags
echo "*/* VIDEO_CARDS: intel" > /etc/portage/package.use/00video_cards

# Configure time and locale
ln -sf ../usr/share/zoneinfo/US/Eastern /etc/localtime
echo -e "en_US ISO-8859-1\nen_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
eselect locale set 5

# Reload environment
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
source /root/chroot_vars.sh

# Configure Kernel
mkdir /efi
mount ${DISK} /efi
emerge ask sys-kernel/linux-firmware
emerge ask sys-firmware/sof-firmware
emerge sys-firmware/intel-microcode
echo "sys-kernel/installkernel grub dracut" > /etc/portage/package.use/installkernel
emerge sys-kernel/installkernel
emerge sys-kernel/gentoo-kernel
emerge sys-kernel/gentoo-sources
emerge --depclean

# Configure the system
emerge genfstab
genfstab / >> /etc/fstab
echo mattyice > /etc/hostname
emerge net-misc/dhcpcd
echo "net-misc/networkmanager tools bluetooth wifi dhcpcd" > /etc/portage/package.use/networkmanager
emerge net-misc/networkmanager
rc-update add dhcpd default
rc-update add networkmanager default
rc-service dhcpcd start
rc-service networkmanager start
echo -e "${GREEN}+++ Root password +++${RESET}"
passwd
emerge app-admin/sysklogd
rc-update add sysklogd default
emerge sys-process/cronie
rc-update add cronie default
emerge sys-apps/mlocate
emerge app-shells/bash-completion
emerge net-misc/chrony
rc-update add chronyd default
emerge sys-fs/xfsprogs sys-fs/dosfstools
emerge sys-block/io-scheduler-udev-rules

# Configure bootloader

echo "sys-boot/grub doc" > /etc/portage/package.use/grub
emerge sys-boot/grub
grub-install --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg
exit


