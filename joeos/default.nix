# the base joe image - sets up basic stuff
{ config, lib, pkgs, ... }: with lib;
let
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
      sshKeys = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      hashedPassword = mkOption {
        type = types.nullOr types.str;
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

    joeos.server = mkEnableOption "server mode";

    joeos.sshServer = mkEnableOption "ssh server";
  };

  imports = [
    ./esp.nix
    ./network.nix
    ./packaging.nix
    ./sysd-simple-boot.nix
    ./uki.nix
  ];

  config = {
    # global version
    system.stateVersion = mkDefault "23.05";

    # standardize on US/Pacific for all time
    time.timeZone = mkDefault "US/Pacific";

    nix.settings = {
      # enable the nix command as well as 'flakes'
      experimental-features = [ "nix-command" "flakes" ];
      # always trust root & members of wheel as they can get to root anyways
      trusted-users = [ "root" "@wheel" ];
    };

    # enable fish to be used as the default shell, use vi bindings
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        fish_vi_key_bindings
      '';
    };

    # default everyone to use fish
    users.defaultUserShell = pkgs.fish;

    # use chrony to get our time synchronized
    services.chrony.enable = true;

    # nixos wants to support a ton of different filesystems by default, but we
    # want to support a very small subset for our uses.
    boot.supportedFilesystems = [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ext4" ];

    # add our nicely defaulted users here, adding a ssh key if needed (as well as adding sudo group)
    users.users = lib.mapAttrs
      (name: value: {
        inherit (value) name description;
        isNormalUser = true;
        extraGroups = lib.mkIf value.allowSudo [ "wheel" ];
        home = "/home/${value.name}";
        createHome = true;
        useDefaultShell = true;
        hashedPassword = lib.mkIf (value.hashedPassword != null) value.hashedPassword;
        openssh.authorizedKeys.keys = value.sshKeys;
      })
      config.joeos.users;

    # disable power management
    powerManagement.enable = lib.mkIf (config.joeos.server) false;

    # add some more settings which should allow for nicer auto-mgmnt of the nix store
    # TODO: should only do this if we are going to allow inline management
    nix.gc = lib.mkIf (config.joeos.server) {
      automatic = true;
      dates = "weekly";
    };
    
    services.openssh = lib.mkIf (config.joeos.sshServer) {
      banner = "\n\nWelcome!\n\n";
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
}
