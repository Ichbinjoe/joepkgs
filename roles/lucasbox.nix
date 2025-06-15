{
  config,
  pkgs,
  ...
}: let
  dn42Ip = "fde7:76fd:7444:fffa::1";
  dn42Net = "fde7:76fd:7444:fffa::/64";
  wgPort = 49993;
in {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
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

  environment.systemPackages = [
    pkgs.wireguard-tools
  ];

  networking.firewall.enable = false;

  systemd.network.netdevs = {
    "01-nyc-wg" = {
      netdevConfig = {
        Name = "nyc-wg";
        Kind = "wireguard";
      };

      wireguardConfig = {
        PrivateKeyFile = "/etc/wireguard/private.key";
      };

      wireguardPeers = [
        {
          wireguardPeerConfig = {
            PublicKey = "BmbqgpKUEYp+FKIFKKDi0Sh+l7OBLzB+AJdTogk7uRU=";
            AllowedIPs = ["0.0.0.0/0" "::/0"];
            Endpoint = "107.175.132.113:${toString wgPort}";
          };
        }
      ];
    };
  };

  systemd.network.networks = {
    "01-nyc-wg" = {
      matchConfig.Name = "nyc-wg";

      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = "no";
      };

      addresses = [
        {
          addressConfig = {
            Address = "fe80::100/128";
            Peer = "fe80::101/128";
            Scope = "link";
            RouteMetric = 2048;
          };
        }
      ];
    };

    "01-lo" = {
      matchConfig.Name = "lo";

      addresses = [
        {
          addressConfig = {
            Address = dn42Ip;
          };
        }
      ];
    };
  };

  # basic ssh
  services.openssh.enable = true;

  services.bird2 = {
    enable = true;
    config = ''
      router id 0.0.0.1;
      protocol device {
        scan time 10;
      };

      protocol static {
        check link;
        route ${dn42Net} via "lo";

        ipv6 {
          import all;
          export none;
        };
      };

      protocol kernel {
        scan time 20;

        ipv6 {
          import none;

          export filter {
            if source = RTS_STATIC then reject;
            krt_prefsrc = ${dn42Ip};
            accept;
          };
        };
      };

      protocol ospf v3 nyc_v6 {
        area 0.0.0.0 {
          interface "nyc-wg" {
            type ptmp;
            neighbors {
              fe80::101;
            };
          };
        };

        ipv6 {
          import all;
          export filter {
            if source = RTS_STATIC then accept; else reject;
          };
        };
      };
    '';
  };
}
