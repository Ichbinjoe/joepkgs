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

  # Unlike our normal default setup, we turn off a lot of features as they
  # aren't strictly necessary and don't play nice with cross compiling. Since
  # this image exists to bootstrap all else I build, this image needs to be
  # reduced back down to enable cross compiling

  programs.fish.enable = false;
  programs.neovim.enable = false;
  users.defaultUserShell = mkForce pkgs.bashInteractive;

  # otherwise, set up a normal remote builder setup
  users = {
    groups.nix-remote-exec = {};

    users = {
      nixos-remote-build = {
        description = "NixOS Remote Build";

        isNormalUser = true;
        extraGroups = ["nix-remote-exec"];
      };
    };
  };

  nix.settings.trusted-users = ["root" "@wheel" "@nix-remote-exec" "@nixbld"];

  services.openssh.enable = true;
}
