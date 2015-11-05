# livessh

A framework for building Ubuntu "live CD" images that start an SSH server at boot.  The resulting images can be booted
in any way that normal Ubuntu images can be, including via PXE ("netbooting"), which is how I typically use them.

The images can, for example, set a predicatable hostname based on the machine's network interfaces' hardware addresses;
advertise via Zeroconf/Avahi; and have your SSH key(s) baked in.  This makes it trivial to PXE boot a machine and then
connect via SSH.

In the past, I've used this ability to reimage machines, to inventory hardware, to update or reconfigure the BIOS and
BMC (IPMI device), to update device firmware, and to perform an array of maintenance tasks on machines with damaged
operating systems.

## Todo

- Better documentation.

- Better separation of the framework from my particular configuration.

## Building

- The build process uses Docker; you will need to have Docker

- Change to the 'bin' directory.  (Sorry; yes, this must be your working directory.)

- Edit 'vars' if appropriate.

- Run

  - `./build-debootstrap-image.sh`

    (This runs `debootstrap` inside a docker container.  It uses the `mkimage` scripts from the Docker repository.  This
    creates a pristine, baseline Ubuntu installation.  You don't need to repeat this step every time you tweak your
    customization scripts.)

  - `./build-customized-environment.sh`

    (This exports the debootstrapped Docker container from the previous step into a temporary directory (`BASE_PATH`).
    Your `pre-customize.d` scripts are run on the host.  The `customize.sh` script, which in turn runs your
    `customize.d` scripts, is invoked inside a container.)

  - `./build-livecd-image.sh`

    (This builds a squashfs from the filesystem created in the previous step, puts that, ISOLINUX, and a few
    configuration files into a temporary directory (`IMAGE_PATH`), and then builds an ISO from that directory.)

## Tips

- Since host keys are regenerated on each boot, host key warnings will become annoying.  You may want to try

      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

  I have this command aliased to `ssh-tmp` in my dotfiles for convenience.

- To discover the newly-booted machine's hostname and/or IP address, you can always check your DHCP server's leases; or,
you can use Zeroconf.

      avahi-browse -t _workstation._tcp

- TODO: Describe how to use an OpenSSH user CA.

- TODO: Describe testing in a libvirt/qemu/KVM guest.

- TODO: Describe PXE booting.

## Features

- openssh

    - By default, pulls in your SSH keys (`~/.ssh/authorized_keys`) at build time.

- hostname

    - Instead of "ubuntu", the live environment changes its hostname to e.g. "livessh-5254000f9ba9", where the latter is
      its hardware address (i.e. MAC address).  If it fails to detect a hardware address, it will chagne its hostname to
      just "livessh".

- Zeroconf/Avahi

    - The live environment runs the Avahi daemon, so you should be able to use 'avahi-browse -at' to see what IP address
      the machine has received via DHCP.  (If you have MDNS set up, you can also just use "livessh-5254000f9ba9.local"
      as a hostname.)

- Installs `squid-deb-proxy-client`, so if an apt proxy is being advertised via zeroconf, it will be automatically used,
  should you need to install new things after booting the image.

- Custom software is easy to add; see `customize.d`.

- NFS mount

- Serial console

- `zsh` instead of `bash`

  - TODO: Touch `~/.zshrc` to avoid the first-run configuration prompt.

## Troubleshooting

- If you are troubleshooting the early part of the booting process, you may need to inspect the initramfs.  The
  'bin/extract-initramfs.sh' script demonstrates how to do this.

- Normal tricks for getting access to a VM's filesystem for inspection purposes, like 'guestmount', won't work (because
  the guest's disk isn't being used; you're booting off a CD!).  However, the live environment's filesystem (the
  unpacked equivalent of the squashfs image in the ISO) is there for you to inspect (at BASE_PATH, right where it was
  built); you don't need direct access to the running guest!

## Nanual testing checklist

- Consoles

  - On the first virtual terminal (tty1), first two hardware serial consoles (ttyS0, ttyS1), and common virtual serial
    consoles (hvc0, others?)  a tty should be present.  If the autologin setting is enabled, agetty should be invoked
    with '--autologin root' so that there is a root shell on each of the above instead of a login prompt.

- Shell

  - If changing the default shell to /bin/zsh, check that we actually get zsh: from a prompt, ZSH_VERSION should be set
    and BASH_VERSION should be unset.  You can also verify that tmp/filesytem/etc/{passwd,adduser.conf} contain
    references to /bin/zsh instead of to /bin/bash.
