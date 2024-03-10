#!/bin/bash
set -x

# Find bootloader partition and umount
blpart="$(findmnt -n -o SOURCE /mnt)"
rootdev="$(basename `readlink -f "/sys/class/block/$(basename $blpart)/.."`)"
partnum="$(echo $(basename $blpart) | sed 's/'"$rootdev"'//;s/p//')"
umount $blpart

# Remove /mnt from fstab
sed -i '/mnt/d' /etc/fstab

# Flash bootloader
submarine="/usr/share/submarine/submarine"
if [ $(uname -m ) == 'x86_64' ]; then
    submarine="$submarine-x86.kpart"
elif [ $(uname -m ) == 'aarch64' ]; then
    submarine="$submarine-a64.kpart"
fi

dd if=$submarine of=$blpart
cgpt add -i $partnum -t kernel -P 15 -T 1 -S 1 /dev/$rootdev

# Workaround for katsu trying to unmount /mnt
mount -o bind /mnt /mnt
