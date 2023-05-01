# the base joe image - sets up basic stuff
{ nixpkgs }:
{ config, ... }:
let
  pkgs = nixpkgs.nixos.pkgs;
  lib = nixpkgs.lib;
  inherit (lib) mkOption mkDefault types;
  ignoreFishTestOverlay = self: super: {
    fish = super.fish.overrideAttrs (old: {
      doInstallCheck = false;
    });
  };
  userOpts = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
      };
      description = mkOption {
        type = types.str;
        default = "";
      };
      allowSudo = mkOption {
        type = types.bool;
        default = false;
      };
      sshKey = mkOption {
        type = types.nullOr types.path;
        default = null;
      };
    };

    config = {
      name = mkDefault name;
    };
  };
in
{
  options = {
    joeos.users = mkOption {
      type = types.attrsOf (types.submodule userOpts);
      default = { };
    };

    joeos.server = mkOption {
      type = types.bool;
      default = false;
    };

    joeos.sshServer = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = {
    # global version
    system.stateVersion = "23.05";

    # standardize on US/Pacific for all time
    time.timeZone = "US/Pacific";

    # enable the nix command as well as 'flakes'
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # enable fish to be used as the default shell
    programs.fish.enable = true;
    nixpkgs.overlays = [ ignoreFishTestOverlay ];

    # default everyone to use fish
    users.defaultUserShell = pkgs.fish;

    # use chrony to get our time synchronized
    services.chrony.enable = true;

    # nixos wants to support a ton of different filesystems by default, but we
    # want to support a very small subset for our uses.
    boot.supportedFilesystems = [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ext4" ];

    # disable dhcpcd, as we should be using networkd instead
    networking.dhcpcd.enable = false;

    # disable password for wheel users
    security.sudo.wheelNeedsPassword = false;

    # add our nicely defaulted users here, adding a ssh key if needed (as well as adding sudo group)
    users.users = lib.mapAttrs
      (name: value: {
        inherit (value) name description;
        isNormalUser = true;
        extraGroups = lib.mkIf value.allowSudo [ "wheel" ];
        home = "/home/${value.name}";
        createHome = true;
        useDefaultShell = true;
        openssh.authorizedKeys.keys = lib.mkIf (value.sshKey != null) [ value.sshKey ];
      })
      config.joeos.users;
  } // lib.mkIf (config.joeos.server) {
    # disable power management
    powerManagement.enable = false;

    # disable password for wheel users
    security.sudo.wheelNeedsPassword = false;

    # add some more settings which should allow for nicer auto-mgmnt of the nix store
    # TODO: should only do this if we are going to allow inline management
    nix.gc = {
      automatic = true;
      dates = "weekly";
    };
  } // lib.mkIf (config.joeos.sshServer) {
    services.openssh = {
      banner = "\n\nWelcome!\n\n";
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
}
