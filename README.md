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

- TODO: Touch `~/.zshrc` to avoid the first-run configuration prompt.

- `pre-customize.d/70-kk-ssh-keys` makes explicit reference to my username.

- Better-document what the settings in `vars` do.

- Automatically detect `APT_PROXY_URL`.

- Have a more extensible mechanism for passing variables into `customize.d` scripts.

## Building

- The build process uses Docker; you will need to have Docker working.

- Change to the 'bin' directory.  (Sorry; yes, this must be your working directory.)

- Edit `vars` if appropriate.

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

- Everything in `vars` is available to `pre-customize.d` scripts.  Only the variables copied into `customize.sh` by
  `bin/build-customized-environment.sh` are available to `customize.d` scripts.

- Since host keys are regenerated on each boot, host key warnings will become annoying.  You may want to try

      `ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null`

  I have this command aliased to `ssh-tmp` in my dotfiles for convenience.

- To discover the newly-booted machine's hostname and/or IP address, you can always check your DHCP server's leases; or,
you can use Zeroconf.

      `avahi-browse -t _workstation._tcp`

- TODO: Describe how to use an OpenSSH user CA.

- TODO: Describe testing in a libvirt/qemu/KVM guest.

- TODO: Describe PXE booting.

## Features

- `data/customize.sh`:

    - Updates all installed packages.

    - Sets hostname.

        - Instead of "ubuntu", the live environment changes its hostname to e.g. "livessh-5254000f9ba9", where the
          latter is its hardware address (i.e. MAC address).  Locally-administered hardware addresses (such as those
          commonly assigned to virtual network interfaces) are chosen only if others are not available.  If no hardware
          address can be detected, the machine's hostname will be set to "livessh".

    - Enables passwordless `sudo` access (which is important; see the note about setting the live user's password not working).

    - Sets time zone.

    - Sets locale.

    - Cleans up temporary files.

    - Rebuilds the initramfs and the dpkg manifest.

- `pre-customize.d/70-kk-ssh-keys`:

    - Bakes in SSH keys.  By default, pulls in your SSH keys (`~/.ssh/authorized_keys`).

- `customize.d/10-openssh`:

    - Installs the OpenSSH server.

    - Prevents host keys from being baked into the image and adds a `systemd` unit that regenerates them at boot time.

- `customize.d/20-serial-console`:

    - Provides automatically-logged-in consoles on

        - the virtual terminal `tty1`

        - the serial ports `ttyS0` and `ttyS1`

        - `hvc0` (for use under Xen, qemu/KVM/libvirt, etc.)

- `customize.d/20-zeroconf`:

    - Installs `avahi-daemon`, so you should be able to use 'avahi-browse -at' to see what IP address
      the machine has received via DHCP.  (If you have MDNS set up, you can also just use "livessh-5254000f9ba9.local"
      as a hostname.)

    - Installs `squid-deb-proxy-client`, so if an apt proxy is being advertised via zeroconf, it will be automatically
      used, should you need to install new things after booting the image.

- `customize.d/30-default-shell-zsh`:

    - `zsh` instead of `bash`

- `customize.d/60-custom-nfs-mount`:

    - Mounts an NFS volume from a particular hardwired location.  This volume is an easy place to stick scripts,
      utilities, notes, etc. without having to bake them into the image.

- `customize.d/65-custom-software`:

    - Installs packages that I use frequently.

- `customize.d/70-ipmitool`:

    - Installs `ipmitool`, which comes in handy when dealing with BMCs.

- `customize.d/80-live-user-password`:

    - (Commented out, since it doesn't work.)

## Troubleshooting

- If you are troubleshooting the early part of the booting process, you may need to inspect the initramfs.  The
  'bin/extract-initramfs.sh' script demonstrates how to do this.  (Run that script from the `tmp/` subdirectory.)

- Normal tricks for getting access to a VM's filesystem for inspection purposes, like 'guestmount', won't work (because
  the guest's disk isn't being used; you're booting off a CD!).  However, the live environment's filesystem (the
  unpacked equivalent of the squashfs image in the ISO) is there for you to inspect (at `BASE_PATH`, right where it was
  built); you don't need direct access to the running guest!

## Manual testing checklist

- Consoles

  - On the first virtual terminal (tty1), first two hardware serial consoles (ttyS0, ttyS1), and common virtual serial
    consoles (hvc0, others?)  a tty should be present.  If the autologin setting is enabled, agetty should be invoked
    with '--autologin root' so that there is a root shell on each of the above instead of a login prompt.

- Shell

  - If changing the default shell to /bin/zsh, check that we actually get zsh: from a prompt, ZSH_VERSION should be set
    and BASH_VERSION should be unset.  You can also verify that tmp/filesytem/etc/{passwd,adduser.conf} contain
    references to /bin/zsh instead of to /bin/bash.
