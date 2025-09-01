{
  config,
  pkgs,
  lib,
  ...
}: {
  # otherwise, set up a normal remote builder setup
  users.groups.nix-remote-exec = {};
  users.users.nixos-remote-build = {
    description = "NixOS Remote Build";

    isNormalUser = true;
    extraGroups = ["nix-remote-exec"];
  };

  nix.settings.trusted-users = ["root" "@wheel" "@nix-remote-exec" "@nixbld"];
}
