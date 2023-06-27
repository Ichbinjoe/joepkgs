{
  description = "A collection of modules specific for JoeOS";

  inputs = {
    bcm-fw-binary = {
      url = "path:proprietary/Broadcom_NX1_Linux_FW_Upgrade_Utility_lnxfwupg-225.0.1.tar.gz";
      flake = false;
    };
  };

  outputs = { ... }@attrs:
    let
      broadcom-firmware = import ./broadcom-firmware.nix;
    in
    rec {
      nixosModules.default = import ./default.nix;
      nixosModules.iso = import ./iso.nix;
      nixosModules.deploy = import ./iso.nix;

      packages."x86_64-linux"."bmapilnx" = broadcom-firmware.bmapilnx;
      packages."x86_64-linux"."lnxfwupd" = broadcom-firmware.lnxfwupd;
    };
}
