{
  lib,
  pkgs,
  ...
}:
with lib; {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
  ];

  environment.systemPackages = [
    pkgs.esptool
    pkgs.esphome
  ];

  # We want this to have Wifi
  networking.wireless.enable = true;

  boot.kernelParams = ["nomodeset"];
  console.enable = false;

  services.openssh.enable = true;
}
