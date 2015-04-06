#!/usr/bin/env bash
#
# Package the Docker container as a bootable ISO.
#

source ./vars

set -e

#!/usr/bin/env bash

############################################
## Export container filesystem from docker
############################################

echo "Removing existing filesystem (if any)..."
sudo rm -rf "${BASE_PATH}"
echo "Exporting filesystem from Docker container..."
mkdir "${BASE_PATH}"
docker export "${CONTAINER_NAME}" | sudo tar --preserve-permissions -C "${BASE_PATH}" -xf -
rmdir "${BASE_PATH}"/{artifacts,resources}  # created by container volumes

############################################
##
############################################

mkdir -p "${IMAGE_PATH}"/{casper,isolinux,install,preseed}

sudo cp "${BASE_PATH}"/boot/vmlinuz-*-generic "${IMAGE_PATH}"/casper/vmlinuz
sudo cp "${BASE_PATH}"/boot/initrd.img-*-generic "${IMAGE_PATH}"/casper/initrd.lz
sudo cp /boot/memtest86+.bin "${IMAGE_PATH}"/install/memtest

# TODO: Can we use this instead of our hacky preseeding?
sudo touch "${IMAGE_PATH}"/preseed/ubuntu.seed

# ############################################
# ## ISOLINUX -- current version from installed host packages -- for Ubuntu 14.10, this is ISOLNUX 6.03 20141020
# ############################################

# sudo cp /usr/lib/ISOLINUX/isolinux.bin "${IMAGE_PATH}"/isolinux/

# # ldlinux is required since SYSLINUX v5.0; these other SYSLINUX modules are cribbed from Fedora's livecd creator:
# # https://git.fedorahosted.org/cgit/livecd/diff/imgcreate/?id=a267c4ab89ff97bcbad550b9ec331d5a0631d444&context=40&ignorews=0&ss=0
# sudo cp /usr/lib/syslinux/modules/bios/{ldlinux,libcom32,libutil}.c32 "${IMAGE_PATH}"/isolinux/

############################################
## ISOLINUX -- legacy version 4.05 extracted from Xubuntu 14.10 desktop ISO
############################################

# isolinux.bin, chain.c32, gfxboot.c32, vesamenu.c32
sudo cp data/isolinux/* "${IMAGE_PATH}"/isolinux/

############################################
## ISOLINUX -- configuration
############################################

sudo cat >"${IMAGE_PATH}"/isolinux/isolinux.txt <<EOF

************************************************************************
This is an Ubuntu-based live environment.
Booting automatically...
************************************************************************

EOF

cat >"${IMAGE_PATH}"/isolinux/isolinux.cfg <<EOF
TIMEOUT 10  # units of 1/10th sec
PROMPT 0
DISPLAY isolinux.txt

DEFAULT live

LABEL live
  menu label ^Boot into live environment
  kernel /casper/vmlinuz
#  append  file=/cdrom/preseed/ubuntu.seed boot=casper initrd=/casper/initrd.lz quiet splash --
  append  file=/cdrom/preseed/ubuntu.seed boot=casper initrd=/casper/initrd.lz --
# LABEL check
#   menu label ^Check CD for defects
#   kernel /casper/vmlinuz
#   append  boot=casper integrity-check initrd=/casper/initrd.lz quiet splash --
# LABEL memtest
#   menu label ^Memory test
#   kernel /install/memtest
#   append -
# LABEL hd
#   menu label ^Boot from first hard disk
#   localboot 0x80
#   append -
EOF

############################################
## Create manifest
############################################

#sudo chroot "${BASE_PATH}" dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee "${IMAGE_PATH}"/casper/filesystem.manifest > /dev/null
sudo cp -v "${ARTIFACTS_TMPDIR}"/filesystem.manifest "${IMAGE_PATH}"/casper/filesystem.manifest
sudo cp -v "${IMAGE_PATH}"/casper/filesystem.manifest{,-desktop}

REMOVE='ubiquity ubiquity-frontend-gtk ubiquity-frontend-kde casper lupin-casper live-initramfs user-setup discover1 xresprobe os-prober libdebian-installer4'
for i in $REMOVE; do
    sudo sed -i "/${i}/d" "${IMAGE_PATH}"/casper/filesystem.manifest-desktop
done

############################################
## Create squashfs from chroot
############################################

# N.B.: If you don't care about being able to install from the livecd, you can save a bit of space
# by adding '-e boot' to the mksquashfs call; this excludes /boot, which isn't necessary since the
# livecd boots using ISOLINUX.  Creating filesystem.size is also only for the installer's benefit.

sudo rm -f "${IMAGE_PATH}"/casper/filesystem.squashfs
sudo mksquashfs "${BASE_PATH}" "${IMAGE_PATH}"/casper/filesystem.squashfs -wildcards -e 'proc/*' -e 'sys/*' -e 'tmp/*' # -e 'dev/pts/*'
printf $(sudo du -sx --block-size=1 "${BASE_PATH}" | cut -f1) > "${IMAGE_PATH}"/casper/filesystem.size

############################################
##
############################################

cat >"${IMAGE_PATH}"/README.diskdefines <<EOF
#define DISKNAME  UbuntuKK-LiveSSH
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF

############################################
## Allow "the USB creator" to recognize this as an Ubuntu derivative.  (It'll still boot without this.)
############################################

touch "${IMAGE_PATH}"/ubuntu
mkdir -p "${IMAGE_PATH}"/.disk
touch "${IMAGE_PATH}"/.disk/base_installable
echo "full_cd/single" > "${IMAGE_PATH}"/.disk/cd_type
echo "UbuntuKK-LiveSSH" > "${IMAGE_PATH}"/.disk/info
echo "http://example.com/" > "${IMAGE_PATH}"/.disk/release_notes_url

############################################
## Calculate checksums
############################################

pushd "${IMAGE_PATH}"
find . -type f -print0 | xargs -0 md5sum | \grep -v "\./md5sum.txt" > md5sum.txt
popd

############################################
## Pack up the image
############################################

pushd "${IMAGE_PATH}"
sudo mkisofs -r -V "$IMAGE_NAME" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "${OUTPUT_ISO_PATH}" .
popd
