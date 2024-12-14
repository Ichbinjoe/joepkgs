{config, ...}: {
  imports = [
    # Intel x86
    ./arch/x86_64-linux.nix
  ];

  assertions = [
    {
      assertion = config.systemd.network.enable;
      message = "systemd network must be used";
    }
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

  services.udev.extraRules = ''
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1546", ATTRS{idProduct}=="01a7", SUBSYSTEM=="tty", GROUP="gpsd", SYMLINK+="gpsserial", TAG+="systemd"
  '';

  systemd.network.links = {
    "01-wan" = {
      matchConfig.Path = "pci-0000:02:00.0";
      linkConfig.Name = "wan";
    };
    "01-lan" = {
      matchConfig.Path = "pci-0000:03:00.0";
      linkConfig.Name = "lan";
    };
  };
}
