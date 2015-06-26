#!/usr/bin/env bash

mkdir -p initramfs
cd initramfs
gunzip -c -S .lz ../image/casper/initrd.lz | cpio -imvd --no-absolute-filenames
