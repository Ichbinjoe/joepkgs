{
  config,
  pkgs,
  ...
}: let
  dn42Ip = "fde7:76fd:7444:fffd::1";
  dn42Net = "fde7:76fd:7444:fffd::/64";
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

  systemd.network.netdevs =
  let
    wg = {
        name, pubkey, endpoint
      }: {
        netdevConfig = {
          Name = name;
          Kind = "wireguard";
        };

        wireguardConfig = {
          PrivateKeyFile = "/etc/wireguard/private.key";
        };

        wireguardPeers = [
          {
            wireguardPeerConfig = {
              PublicKey = pubkey;
              AllowedIPs = ["0.0.0.0/0" "::/0"];
              Endpoint = endpoint;
            };
          }
        ];
      };
    in
  {
    "01-nyc-wg" = wg {
        name = "nyc-wg";
        pubkey = "BmbqgpKUEYp+FKIFKKDi0Sh+l7OBLzB+AJdTogk7uRU=";
        endpoint = "107.175.132.113:49990";
    };
    "01-sea-wg" = wg {
        name = "sea-wg";
        pubkey = "9vBrb8Jq3WmifgCjncMzLZvdkoDi3FoSvHjJGsUMwGg=";
        endpoint = "sea01.ke8jwh.com:50002";
    };
    "01-sjc-wg" = wg {
        name = "sjc-wg";
        pubkey = "sl9vN6wmKuB3aGjBYx2ukjABc66EAn0p5VJsg0XjjjM=";
        endpoint = "sjc01.ke8jwh.com:50002";
    };
  };

  systemd.network.networks =
  let
    wgNet = name: {
      matchConfig.Name = name;

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
  in {
    "01-nyc-wg" = wgNet "nyc-wg";
    "01-sea-wg" = wgNet "sea-wg";
    "01-sjc-wg" = wgNet "sjc-wg";

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

      protocol babel joenet_babel {
        interface "sea-wg" {
          type tunnel;
        };
        interface "sjc-wg" {
          type tunnel;
        };

        ipv4 {
          import all;
          export filter {
            if source = RTS_STATIC then accept; else reject;
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
