{
  pkgs,
  lib,
  ...
}:
with lib; {
  hardware.enableRedistributableFirmware = true;

  # we want to make vchiq a bit more permissive by allowing the video group to access it
  services.udev.extraRules = ''KERNEL=="vchiq", GROUP="video", MODE="0660"'';

  environment.systemPackages = [
    pkgs.raspberrypi-eeprom
    pkgs.libraspberrypi
  ];

  console.enable = mkDefault false;
}
