# Defines the hardware setup of my Linux router, which is a generic linux
# machine I built a long time ago.
#
# We only bother mapping ethernet ports - one 'builtin' and four on a gig-e
# card. We capture link settings in here simply because matching is dependent
# on the hardware - we can abstract this out in the future to run in a VM for
# testing (for example)
{config, ...}: {
  imports = [
    # AMD machine
    ./arch/x86_64-linux.nix
  ];

  assertions = [
    {
      assertion = config.systemd.network.enable;
      message = "systemd network must be used";
    }
  ];

  services.udev.extraRules = ''
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1546", ATTRS{idProduct}=="01a7", SUBSYSTEM=="tty", GROUP="gpsd", SYMLINK+="gpsserial", TAG+="systemd"
  '';

  systemd.network.links = {
    "01-external" = {
      matchConfig.Path = "pci-0000:03:00.0";
      linkConfig = {
        Name = "external";
        MACAddress = config.homerouter.secrets.mac;
      };
    };

    "01-internal" = {
      matchConfig.Path = "pci-0000:03:00.1";
      linkConfig.Name = "internal";
    };

    "01-untrustedap" = {
      matchConfig.Path = "pci-0000:04:00.1";
      linkConfig.Name = "untrustedap";
    };
  };
}
