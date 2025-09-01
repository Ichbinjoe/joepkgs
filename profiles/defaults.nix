# the base joe image - sets up basic stuff
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options = {
    # Unlike basic nixos, we want to be able to default
    # this to one version across all configs. easiest way
    # to do this without getting annoying warnings is to
    # add another variable
    system.stateVersionOverride = mkOption {
      type = types.str;
      default = "25.05";
      description = ''See system.stateVersion'';
    };
  };

  config = {
    # global version
    system.stateVersion = config.system.stateVersionOverride;

    # use systemd as stage2
    boot.initrd.systemd.enable = mkDefault true;

    # standardize on US/Pacific for all time
    time.timeZone = mkDefault "US/Pacific";

    # disable power management by default - unless this is a
    # end user, we won't want suspension
    powerManagement.enable = mkDefault false;

    # set up some nix stuff
    nix.settings = {
      # enable the nix command as well as 'flakes'
      experimental-features = mkDefault ["nix-command" "flakes"];
      # always trust root & members of wheel as they can get to root anyways
      trusted-users = mkDefault ["root" "@wheel"];
    };

    # we also want to set up a basic registry link back to nixpkgs so we can
    # install stuff on the fly
    nix.registry = mkDefault {
      "nixpkgs" = {
        from = {
          type = "indirect";
          id = "nixpkgs";
        };

        to = {
          type = "github";
          owner = "NixOS";
          repo = "nixpkgs";
          ref = "nixos-24.11";
        };
      };
    };

    # enable fish to be used as the default shell, use vi bindings
    programs.fish = {
      enable = mkDefault true;
      interactiveShellInit = ''
        fish_vi_key_bindings
      '';
    };

    # default everyone to use fish
    users.defaultUserShell = mkOverride 900 pkgs.fish;

    programs.neovim = {
      # we love neovim
      enable = mkDefault true;
      # we love it being the default editor
      defaultEditor = mkDefault true;
      # so much so we will just pretend it is normal vi/vim
      viAlias = mkDefault true;
      vimAlias = mkDefault true;
      # default to a thin installation - most plugins are lua first or builtin, so this isn't an issue
      # ruby also has a problem cross compiling - https://github.com/NixOS/nixpkgs/issues/216079
      withRuby = mkDefault false;
      withPython3 = mkDefault false;
    };

    environment.systemPackages = [
      (pkgs.runCommand "default-editor" {} ''
        mkdir -p $out/bin/
        ln -s ${config.programs.neovim.package}/bin/nvim $out/bin/editor
      '')
    ];

    # override some openssh stuff by default
    services.openssh.settings = {
      KbdInteractiveAuthentication = mkDefault false;
      PasswordAuthentication = mkDefault false;
      PermitRootLogin = mkDefault "no";
    };

    # we want to be using networkd / netfilter based networking
    networking = {
      useNetworkd = mkDefault true;
      dhcpcd.enable = mkDefault false;
      firewall.enable = mkDefault true;
      nftables.enable = mkDefault true;
    };

    # set up a reasonable network profile
    systemd.network = {
      enable = mkDefault true;
      wait-online.anyInterface = mkDefault true;

      networks."99-default" = {
        matchConfig.Name = "*";
        networkConfig = {
          IPv6AcceptRA = "yes";
          DHCP = "yes";
        };
      };
    };
  };
}
