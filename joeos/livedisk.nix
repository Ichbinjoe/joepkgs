{ nixpkgs, broadcom-firmware, default, provisioning, ... }:
let
  cfg = import ./livedisk-configuration.nix { inherit nixpkgs default provisioning broadcom-firmware; };

  system = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      cfg
    ];
  };
in
system.config.system.build.isoImage
