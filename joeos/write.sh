#!/bin/bash

nix build --system x86_64-linux ./#livedisk
hdiutil convert -format UDRW -o /tmp/usb.iso result/iso/nixos.iso
mv /tmp/usb.iso.dmg /tmp/usb.iso
sudo diskutil unmountDisk /dev/disk5
sudo dd if=usb.iso of=/dev/disk5 bs=1m status=progress oflag=direct,sync
