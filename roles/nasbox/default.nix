{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../profiles/base.nix
    ../../profiles/defaults.nix
  ];

  boot.initrd.kernelModules = [
    "ahci"
    "ata_piix"
    "sd_mod"
    "sr_mod"
    "usb_storage"
    "ehci_hcd"
    "uhci_hcd"
    "xhci_hcd"
    "xhci_pci"
    "mmc_block"
    "mmc_core"
    "cqhci"
    "sdhci"
    "sdhci_pci"
    "sdhci_acpi"
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  networking.firewall.enable = false;
  networking.useNetworkd = true;
  networking.dhcpcd.enable = false;

  systemd.network.enable = true;
  systemd.network.wait-online.anyInterface = true;

  # basic ssh
  services.openssh.enable = true;

  # otherwise, set up a normal remote builder setup
  users.groups.nix-remote-exec = {};
  users.users.nixos-remote-build = {
    description = "NixOS Remote Build";

    isNormalUser = true;
    extraGroups = ["nix-remote-exec"];
  };

  nix.settings.trusted-users = ["root" "@wheel" "@nix-remote-exec" "@nixbld"];
}
