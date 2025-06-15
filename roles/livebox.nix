{
  nixpkgs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
  ];

  config = {
    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = [
      (final: prev: {
        ipxe = prev.ipxe.override {
          additionalTargets = {
            "bin/14e4165f.rom" = null;
          };
        };
      })
    ];

    services.openssh.enable = true;

    boot.kernelPatches = with lib.kernel; [
      {
        name = "disable-strict-devmem";
        patch = null;
        extraStructuredConfig = {
          STRICT_DEVMEM = no;
          IO_STRICT_DEVMEM = option no;
        };
      }
    ];

    environment.systemPackages = [
      (pkgs.callPackage ../pkgs/broadcom-firmware {}).lnxfwupd
      pkgs.ipxe
    ];
  };
}
