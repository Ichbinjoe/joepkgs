# bundles & provides scripts which can be used to deploy another system's top level to
# a particular mount
{ config, stdenvNoCC, nixpkgs, pkgs, lib, ... }@attrs: with lib;
{
  imports = [
    (nixpkgs + "/nixos/modules/profiles/base.nix")
    (nixpkgs + "/nixos/modules/profiles/minimal.nix")
    ./default.nix
    ./iso.nix
  ];

  config = {
    system.stateVersion = "23.05";
    networking.hostName = "bootstrap";

    # UKI is simple
    # system.boot.loader.uki.enable = true;
    system.boot.loader.simple-systemd.enable = true;

    environment.systemPackages = [
      # these are also generally nice
      pkgs.btrfs-progs
      pkgs.efibootmgr
      pkgs.git
      pkgs.openssh
      pkgs.neovim
      pkgs.parted
      pkgs.socat
      pkgs.tmux
      pkgs.sdparm
      pkgs.hdparm
      pkgs.smartmontools
      pkgs.pciutils
      pkgs.usbutils
      pkgs.unzip
      pkgs.zip
    ];

    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };

    users.users = {
      root = {
        description = "root";
        home = "/root";
        createHome = true;
        useDefaultShell = true;
      };
    };
  };
}
