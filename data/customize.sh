#!/usr/bin/env bash
#
#  Runs inside the Docker container.
#

set -e

# TODO: Copy vars (or some subset) of it in here; don't let this be hardwired.

APT_PROXY_URL="http://192.168.0.1:3142"

USERNAME="solid"
IMAGE_FLAVOUR="ubuntu-livessh"
HOSTNAME_BASE="livessh"

# Volume with files we are bringing into the container.  If we were using a Dockerfile, we could also ADD these.
RESOURCES_VOLUME_PATH="/resources"

############################################

UBUNTU_ARCHIVE_URL="http://us.archive.ubuntu.com/ubuntu/"
UBUNTU_SECURITY_URL="http://security.ubuntu.com/ubuntu/"

APT_GET="env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true apt-get"
APT_GET_INSTALL="$APT_GET install -y --no-install-recommends"

############################################
## Get apt ready to rock
############################################

cat >/etc/apt/apt.conf.d/80proxy <<EOF
Acquire::http::Proxy "${APT_PROXY_URL}";
EOF

$APT_GET update
$APT_GET dist-upgrade -y

############################################
## Install baseline software (based on the "live CD from scratch" wiki page) and fix locale issues
############################################

# N.B.: The ubuntu-minimal package will already have been installed by mkimage.sh.

$APT_GET_INSTALL ubuntu-standard linux-generic discover laptop-detect os-prober casper lupin-casper
## N.B.: On top of the other packages, ubuntu-standard ropes in...
# The following extra packages will be installed:
#   accountsservice apparmor apt-transport-https bash-completion bsdmainutils busybox-static ca-certificates command-not-found command-not-found-data dnsutils dosfstools ed friendly-recovery ftp fuse
#   gir1.2-glib-2.0 groff-base hdparm info install-info iptables iputils-tracepath irqbalance language-selector-common libaccountsservice0 libapparmor-perl libcurl3-gnutls libedit2 libelf1 libgck-1-0
#   libgcr-3-common libgcr-base-3-1 libgirepository-1.0-1 libidn11 libnfnetlink0 libnuma1 libparted2 libpcap0.8 libpipeline1 libpolkit-gobject-1-0 librtmp1 libusb-1.0-0 libx11-6 libx11-data libxau6
#   libxcb1 libxdmcp6 libxext6 libxmuu1 libxtables10 lshw lsof ltrace man-db manpages mlocate mtr-tiny nano ntfs-3g openssh-client openssl parted plymouth-theme-ubuntu-text popularity-contest
#   powermgmt-base ppp pppconfig pppoeconf psmisc python-apt-common python3-apt python3-commandnotfound python3-dbus python3-distupgrade python3-gdbm python3-gi python3-update-manager rsync strace
#   tcpdump telnet time ubuntu-release-upgrader-core ufw update-manager-core usbutils wget xauth

# What these variables do: https://superuser.com/questions/392439/
locale-gen "en_US.UTF-8"
update-locale LANG="en_US.UTF-8" LANGUAGE="en_US"
# TODO: Also, 'console-data' and 'console-setup' ?? (which we have preseed lines for--)

 
# XXX: why do this separately?
# XXX: If we skip the noninteractive part, this complains that 'grub2 depends on grub-pc but grub-pc is not configured yet' and tries to ask us questions.
$APT_GET_INSTALL grub2

# XXX: Necessary?  (The package is, I'm pretty sure, but do we need to ask for it?)
$APT_GET_INSTALL user-setup

############################################
## Sudo without password for all sudoers, not just the casper user
############################################

cat >/etc/sudoers.d/nopasswd <<EOF
%sudo  ALL=(ALL:ALL) NOPASSWD:ALL
EOF

# TODO: Preserve SSH_* variables and EDITOR, VISUAL.
# TODO: Add EDITOR/VISUAL preferences to /etc/profile.d/whatever

############################################
## Add user accounts and authorized SSH key(s)
############################################

# # XXX: Adding --uid to see if that fixes casper's problems.  (Is casper requesting UID 1000 for the livecd user?)
adduser --gecos '' --disabled-password "$USERNAME" --uid 2000  # --shell "$(which zsh)"
for GROUPNAME in adm cdrom sudo dip plugdev; do  # lpadmin sambashare -- these grooups don't seem to exist at the time this script is running
    adduser "$USERNAME" "$GROUPNAME"
done
rsync --archive "${RESOURCES_VOLUME_PATH}"/home/"$USERNAME"/ /home/"$USERNAME"/
chown -R "$USERNAME": /home/"$USERNAME"/

############################################
## Configure casper; try to set unique hostname based on MAC address
############################################

# N.B.: Quoting the limit string (EOF) prevents parameter substitution, effectively escaping all of
# the $, `, and \ special characters that we want to write to casper.conf.  Ref.: http://tldp.org/LDP/abs/html/here-docs.html#HEREDOCREF
cat >>/etc/casper.conf <<EOF
export FLAVOUR="${IMAGE_FLAVOUR}"
export USERNAME="${USERNAME}"
export HOST="${HOSTNAME_BASE}"
EOF
cat >>/etc/casper.conf <<'EOF'
# The first unicast, globally-assigned Ethernet-size link-layer address.
HWADDR="$(cat /sys/class/net/*/address | egrep '^[0-9a-f][048c](:[0-9a-f]{2}){5}$' | egrep -v '^00(:00){5}$' | sort -u | head -n 1)"
# If none are available, try the first locally-assigned address.  (Maybe this is a VM.)
if [ "x${HWADDR}" == "x" ]; then
  HWADDR="$(cat /sys/class/net/*/address | egrep '^[0-9a-f][26ae](:[0-9a-f]{2}){5}$' | egrep -v '^00(:00){5}$' | sort -u | head -n 1)"
fi
# If we got an address, strip the colons and append it to our hostname.
if [ "x${HWADDR}" != "x" ]; then
  export HOST="${HOST}-$(echo $HWADDR | sed 's/://g')"
fi
EOF

############################################
##
############################################

# # e.g. debconf-get-selections
# $APT_GET_INSTALL debconf-utils

# # so that we can change timezone via preseed?
# $APT_GET_INSTALL tzdata

# Timezone; should we use UTC instead?
echo "America/Los_Angeles" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

### TODO: update grub config


### CLEANUP

### TODO:
####
## Remove upgraded, old linux-kernels if more than one:
# ls /boot/vmlinuz-2.6.**-**-generic > list.txt
# sum=$(cat list.txt | grep '[^ ]' | wc -l)
#
# if [ $sum -gt 1 ]; then
# dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | xargs sudo apt-get -y purge
# fi
#
# rm list.txt
####

#####################
## Run user customize scripts (in the target environment)
#####################

for SCRIPT_NAME in $(run-parts --test "${RESOURCES_VOLUME_PATH}"/customize.d); do
    source "${SCRIPT_NAME}"
done

############################################
## Repair the configuration changes that docker's debootstrap makes
############################################

rm -f /sbin/initctl  # or else dpkg-divert will fail
dpkg-divert --local --rename --remove /sbin/initctl
rm /usr/sbin/policy-rc.d
rm /etc/apt/apt.conf.d/docker-clean
rm /etc/apt/apt.conf.d/docker-no-languages
rm /etc/apt/apt.conf.d/docker-gzip-indexes  # without removing this, the livecd fails with an error about being unable to find index files
rm etc/apt/apt.conf.d/docker-autoremove-suggests
rm /etc/dpkg/dpkg.cfg.d/docker-apt-speedup

## XX: Does not restore /etc/apt/apt.conf.d/01autoremove-kernels

############################################
## Clean up; revert temporary changes
############################################

$APT_GET autoremove -y
$APT_GET clean

#sudo mv "${BASE_PATH}/etc/hosts"{.bak,}

rm -rf /tmp/*   # XXX: we tell mksquashfs to ignore these anyhow
rm -f /var/lib/dbus/machine-id
rm -f /etc/apt/apt.conf.d/80proxy

# XXX: Remove apt lists.

# TODO: Un-divert and un-symlink /sbin/initctl.

############################################
## Rebuild initramfs
############################################

# Unless we do this, changing e.g. /etc/casper.conf has no real effect, since the initramfs
# (image/casper/initrd.lz) still contains the unmodified version.
update-initramfs -c -k all

############################################
## Produce dpkg manifest
############################################

dpkg-query -W --showformat='${Package} ${Version}\n' | tee /artifacts/filesystem.manifest > /dev/null
