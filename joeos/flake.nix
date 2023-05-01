{
  description = "A collection of modules specific for JoeOS";

  inputs = {
    bcm-fw-binary = {
      url = "path:proprietary/Broadcom_NX1_Linux_FW_Upgrade_Utility_lnxfwupg-225.0.1.tar.gz";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, bcm-fw-binary }:
    let
      broadcom-firmware = import ./broadcom-firmware.nix { inherit nixpkgs bcm-fw-binary; };
      default = import ./default.nix { inherit nixpkgs; };
      network = import ./network.nix { inherit nixpkgs; };
      provisioning = import ./provisioning.nix { inherit nixpkgs; };
    in
    {
      nixosModules.default = default;
      nixosModules.network = network;
      nixosModules.provisioning = provisioning;

      packages."x86_64-linux"."bmapilnx" = broadcom-firmware.bmapilnx;
      packages."x86_64-linux"."lnxfwupd" = broadcom-firmware.lnxfwupd;

      packages."x86_64-linux"."livedisk" = import ./livedisk.nix {
        inherit nixpkgs broadcom-firmware default provisioning;
      };
    };
  }
