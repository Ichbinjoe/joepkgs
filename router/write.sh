#!/bin/bash
set -e
nix flake update
nix build --system x86_64-linux ./#router-bootstrap-iso
hdiutil convert -format UDRW -o /tmp/usb.iso result/iso/nixos.iso
mv /tmp/usb.iso.dmg /tmp/usb.iso
sudo diskutil unmountDisk /dev/disk4
sudo dd if=/tmp/usb.iso of=/dev/disk4 bs=1m status=progress oflag=direct,sync
