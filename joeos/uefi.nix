# sets up permanent uefi boot

{ lib, pkgs, ... }:

{
  boot.loader = {
    # efi = {
    #   canTouchEfiVariables = true;
    #   efiSysMountPoint = "/efi";
    # };
    systemd-boot = {
      enable = true;
      editor = false;
    };
  };
}
