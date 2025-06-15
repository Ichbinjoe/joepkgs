{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  dn42Ip = "fde7:76fd:7444:fffb::1";
  dn42NodeIp = "fde7:76fd:7444:aaaa::235";
  dn42SyncthingGuiIp = "fde7:76fd:7444:fffb::200";
  dn42GrafanaIp = "fde7:76fd:7444:fffb::300";
  dn42BirdLgProxy = "fde7:76fd:7444:fffb::9998";
  dn42Net = "fde7:76fd:7444:fffb::/64";
  dn42LanNet = "fde7:76fd:7444:faaa::/64";
  wgPort = 49992;
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

  services.udev.extraRules = ''
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1546", ATTRS{idProduct}=="01a7", SUBSYSTEM=="tty", GROUP="gpsd", SYMLINK+="gpsserial", TAG+="systemd"
  '';

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  environment.systemPackages = with pkgs; [
    ethtool
    sipcalc
    tshark
    wireguard-tools
    gpsd
    minicom
  ];

  networking.firewall.enable = false;
  networking.useNetworkd = true;
  networking.dhcpcd.enable = false;

  systemd.network.enable = true;
  systemd.network.wait-online.anyInterface = true;

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

    "01-sea-wg" = {
      netdevConfig = {
        Name = "sea-wg";
        Kind = "wireguard";
      };

      wireguardConfig = {
        PrivateKeyFile = "/etc/wireguard/private.key";
      };

      wireguardPeers = [
        {
          wireguardPeerConfig = {
            PublicKey = "9vBrb8Jq3WmifgCjncMzLZvdkoDi3FoSvHjJGsUMwGg=";
            AllowedIPs = ["0.0.0.0/0" "::/0"];
            Endpoint = "107.174.240.107:${toString wgPort}";
          };
        }
      ];
    };

    "01-fmepg-wg" = {
      netdevConfig = {
        Name = "fmepg-wg";
        Kind = "wireguard";
      };

      wireguardConfig = {
        PrivateKeyFile = "/etc/wireguard/private.key";
        ListenPort = 33703;
      };

      wireguardPeers = [
        {
          wireguardPeerConfig = {
            PublicKey = "p+vuFQshD+xQDXvx3XLEYPJbjHdw4VaeszSgzNwDJAI=";
            AllowedIPs = ["0.0.0.0/0" "::/0"];
            Endpoint = "fergus.fmepnet.org:52823";
          };
        }
      ];
    };

    "01-iot" = {
      netdevConfig = {
        Kind = "vlan";
        Name = "iot";
      };

      vlanConfig = {
        Id = 2;
      };
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
    "01-sea-wg" = {
      matchConfig.Name = "sea-wg";

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
    "01-fmepg-wg" = {
      matchConfig.Name = "fmepg-wg";

      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = "no";
      };

      addresses = [
        {
          addressConfig = {
            Address = "172.20.170.235/32";
            Peer = "172.20.159.228/32";
            Scope = "link";
            RouteMetric = 2048;
          };
        }
        {
          addressConfig = {
            Address = "fe80::3703:157/128";
            Peer = "fe80::3703/64";
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
            Address = "${dn42Ip}/128";
          };
        }
        {
          addressConfig = {
            Address = "172.20.170.235/32";
          };
        }
        {
          addressConfig = {
            Address = "${dn42NodeIp}/128";
          };
        }
        {
          addressConfig = {
            Address = "${dn42SyncthingGuiIp}/128";
          };
        }
        {
          addressConfig = {
            Address = "${dn42GrafanaIp}/128";
          };
        }
        {
          addressConfig = {
            Address = "${dn42BirdLgProxy}/128";
          };
        }
      ];
    };

    "01-wan" = {
      matchConfig.Name = "wan";

      networkConfig = {
        DHCPPrefixDelegation = "no";
        IPv6SendRA = "no";
        DHCPServer = "no";
        IPv6AcceptRA = "no";
        DHCP = "yes";
      };

      dhcpV4Config = {
        SendHostname = "no";
        UseHostname = "no";
        UseDNS = "no";
        UseNTP = "no";
        UseTimezone = "no";
      };
    };

    "01-lan" = {
      matchConfig.Name = "lan";
      address = [
        "192.168.2.1/24"
        "172.20.170.235/32"
        "fde7:76fd:7444:ffbb::ffff/64"
      ];
      networkConfig = {
        DHCPServer = "yes";
        IPv6AcceptRA = "no";
        IPv6SendRA = "yes";
        DHCP = "no";
      };
      dhcpServerConfig = {
        DNS = ["_server_address"];
        NTP = ["_server_address"];
      };

      ipv6SendRAConfig = {
        DNS = ["_link_local"];
      };

      ipv6Prefixes = [
        {
          ipv6PrefixConfig = {
            Prefix = dn42LanNet;
            Assign = "yes";
          };
        }
      ];

      vlan = ["iot"];
    };

    "01-iot" = {
      matchConfig.Name = "iot";
      address = ["192.168.100.1/24"];
      networkConfig = {
        DHCPServer = "yes";
        IPv6AcceptRA = "no";
        DHCP = "no";
      };
      dhcpServerConfig = {
        PoolOffset = 100;
        PoolSize = 150;
        EmitDNS = "no";
        EmitNTP = "no";
      };
    };
  };

  networking.nftables = {
    enable = true;
    checkRuleset = false;
    flushRuleset = true;
    ruleset = ''
      table ip ipv4 {
        chain prerouting {
          type nat hook prerouting priority filter; policy accept;
        }

        chain input {
          type filter hook input priority 1; policy accept;
          iifname "lo" accept;
          tcp dport ssh accept;
          iifname "wan" udp dport { 68, 33703 } accept;
          iifname { "lan", "iot" } udp dport 67 accept;
          iifname "lan" udp dport 53 accept;
          iifname "lan" tcp dport 53 accept;
          ip protocol icmp icmp type { echo-request, router-advertisement } accept;
        }

        flowtable f4 {
          hook ingress priority 0;

          devices = { "lan", "wan", "iot" };
        }

        chain forward {
          type filter hook forward priority 1; policy accept;

          iifname { "nyc-wg", "sea-wg", "fmepg-wg" } accept;

          ct state { established, related } accept;
          iifname { "lan", "wan" } ct state invalid drop;
          oifname { "lan", "wan" } ct state invalid drop;
          ip protocol { tcp, udp, icmp } flow offload @f4;
        }

        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          iifname "iot" drop;

          oifname "wan" iifname "lan" masquerade;
          oifname { "nyc-wg", "sea-wg", "fmepg-wg" } iifname { "lan", "lo" } snat to 172.20.170.235;
        }
      }

      table ip6 ipv6 {
        chain input {
          type filter hook input priority 1; policy accept;
          icmpv6 type {echo-request,nd-neighbor-solicit,nd-neighbor-advert,nd-router-solicit,
             nd-router-advert,mld-listener-query} accept;
          iifname "lo" accept;
          tcp dport ssh accept;
          iifname {"lan"} udp dport 53 accept;
          iifname {"lan"} tcp dport 53 accept;
          iifname {"nyc-wg", "sea-wg"} udp dport 6696 accept;
          iifname {"nyc-wg", "sea-wg", "fmepg-wg"} tcp dport 179 accept;
        }

        flowtable f6 {
          hook ingress priority 0;

          devices = { "lan", "wan", "iot" };
        }

        chain forward {
          type filter hook forward priority 1; policy accept;

          iifname { "nyc-wg", "sea-wg", "fmepg-wg" } oifname {"nyc-wg", "sea-wg", "fmepg-wg" } accept;
          oifname {"lan"} ip6 daddr fde7:76fd:7444:ffbb::/64 accept;
          iifname {"lan"} ip6 saddr fde7:76fd:7444:ffbb::/64 oifname { "lan", "nyc-wg", "sea-wg", "fmepg-wg" } accept;

          ct state { established, related } accept;
          flow offload @f6;
        }
      }
    '';
  };

  services.resolved.enable = false;
  services.unbound = let
    dn42AuthoritativeZones = [
      "10.in-addr.arpa."
      "20.172.in-addr.arpa."
      "21.172.in-addr.arpa."
      "22.172.in-addr.arpa."
      "23.172.in-addr.arpa."
      "31.172.in-addr.arpa."
      "d.f.ip6.arpa."
      "dn42."
    ];
  in {
    enable = true;
    settings = {
      server = {
        interface = ["127.0.0.1" "lan"];
        # prefer-ip6 = true;
        access-control = ["0.0.0.0/0 allow" "::0/0 allow"];
        extended-statistics = true;
        use-syslog = true;

        cache-min-ttl = "300";
        cache-max-ttl = "14400";

        msg-cache-size = "128m";
        rrset-cache-size = "256m";
        key-cache-size = "32m";
        neg-cache-size = "8m";

        prefetch = true;
        prefetch-key = true;
        local-zone = map (addr: ''"${addr}" typetransparent'') dn42AuthoritativeZones;
        private-domain = dn42AuthoritativeZones;
        trust-anchor-file = [
          (toString (pkgs.writeText "dn42-trust-anchor" ''
            dn42.                 86400 IN  DS  64441 10 2 6dadda00f5986bd26fe4f162669742cf7eba07d212b525acac9840ee06cb2799
            dn42.                 86400 IN  DS  3096 10 2 b7c687a99bee60e172ea439bd2d3087b1d970916575db9c1cb591b7ee15d8cb1

            20.172.in-addr.arpa.  86400 IN  DS  64441 10 2 616c149633e93d963b0e8f738719630ea0a09f4aabe211b1fbb8fc9f51304027
            20.172.in-addr.arpa.  86400 IN  DS  3096 10 2 6adf85efddf223c8747f1816b12b62feea0b9b1bdb65e7c809202f890a33740d

            21.172.in-addr.arpa.  86400 IN  DS  64441 10 2 4cc085716ba83f18df1a7fb9f9479d10327e3d30e222c7a197109c7560ae0368
            21.172.in-addr.arpa.  86400 IN  DS  3096 10 2 506fd7f34aaad4df1b6cfa56fe8c00e157b1c32551c981def0c5fd8f65ab14ac

            22.172.in-addr.arpa.  86400 IN  DS  64441 10 2 383a8c2714d3da76f58cee4c54566566b336b2dfa219b965f7cb706d71c54356
            22.172.in-addr.arpa.  86400 IN  DS  3096 10 2 5437ab49f1cd947d41c585c2cc9c357323013391b0e5f94784f99175142c3260

            23.172.in-addr.arpa.  86400 IN  DS  64441 10 2 e91c0281e705317968c76689e4f36bf2207c90bdfaad071693bb9a999d15778f
            23.172.in-addr.arpa.  86400 IN  DS  3096 10 2 631b00ba00cf80a8300b356bcca2fde4c844f6ff707a2d98b4518c72e0643467

            31.172.in-addr.arpa.  86400 IN  DS  64441 10 2 5f668f3083d65650ab5c4e9fccdddd0c8108e0fa4be39e161e6a58d1741c5b2d
            31.172.in-addr.arpa.  86400 IN  DS  3096 10 2 4ab3c242fdfa6d84cbe83d5c9b0f9b431c6974dd18db32d08a2599ab1b816465

            10.in-addr.arpa.      86400 IN  DS  64441 10 2 8a39e9df85a73f1982e43c9139e095e8548451d2048d92c2703869ef8bfebbb4
            10.in-addr.arpa.      86400 IN  DS  3096 10 2 1fa3673dc2cf9ffa82b429bf25405b44931460b7263a081d586cc61f003a10a2

            d.f.ip6.arpa.         86400 IN  DS  64441 10 2 9057500a3b6e09bf45a60ed8891f2e649c6812d5d149c45a3c560fa0a6195c49
            d.f.ip6.arpa.         86400 IN  DS  3096 10 2 23fb364c82e6ed1c30b18c635f58dca58bbeb2e069bbd9d90ab9a90f66b948d2
          ''))
        ];
      };
      remote-control = {
        control-enable = true;
        control-interface = "/run/unbound/unbound.socket";
      };
      stub-zone = let
        stub = domain: {
          name = domain;
          stub-host = ["b.delegation-servers.dn42" "k.delegation-servers.dn42" "j.delegation-servers.dn42" "l.delegation-servers.dn42"];
        };
      in
        map stub dn42AuthoritativeZones;

      auth-zone = [
        {
          name = "delegation-servers.dn42.";
          for-upstream = true;
          for-downstream = false;
          zonefile = toString (pkgs.writeText "dn42-delegation-servers-zonefile" ''
            delegation-servers.dn42.   900 IN  SOA   b.master.delegation-servers.dn42. burble.dn42. 1707593005 900 900 86400 900
            delegation-servers.dn42.   900 IN  NS    b.delegation-servers.dn42.
            delegation-servers.dn42.   900 IN  NS    k.delegation-servers.dn42.
            delegation-servers.dn42.   900 IN  NS    j.delegation-servers.dn42.
            delegation-servers.dn42.   900 IN  NS    l.delegation-servers.dn42.
            b.delegation-servers.dn42. 900 IN  AAAA  fd42:4242:2601:ac53::1
            b.delegation-servers.dn42. 900 IN  A     172.20.129.1
            k.delegation-servers.dn42. 900 IN  AAAA  fdcf:8538:9ad5:1111::2
            k.delegation-servers.dn42. 900 IN  A     172.20.14.34
            j.delegation-servers.dn42. 900 IN  AAAA  fd42:5d71:219:0:216:3eff:fe1e:22d6
            j.delegation-servers.dn42. 900 IN  A     172.20.1.254
            l.delegation-servers.dn42. 900 IN  AAAA  fd86:bad:11b7:53::1
            l.delegation-servers.dn42. 900 IN  A     172.22.108.54
          '');
        }
      ];
    };
  };

  # basic ssh
  services.openssh.enable = true;

  services.bird2 = let
    ibgp = {
      name,
      peerId,
      mode,
    }: ''
      protocol bgp ibgp_${name} {
        local as 4242420157;
        source address ${dn42NodeIp};
        neighbor fde7:76fd:7444:aaaa::${toString peerId} as 4242420157 internal;
        ${mode};

        ipv4 {
          next hop self ebgp;
          next hop address ${dn42NodeIp};
          extended next hop on;

          import all;
          export filter {
            if source = RTS_STATIC && dn42_is_self4() then {
              bgp_next_hop = ${dn42NodeIp};
              accept;
            } else if source = RTS_BGP && dn42_valid4() then accept;
            else reject;
          };
        };

        ipv6 {
          next hop self ebgp;
          next hop address ${dn42NodeIp};
          extended next hop on;

          import all;
          export filter {
            if source = RTS_STATIC && dn42_is_self6() then {
              bgp_next_hop = ${dn42NodeIp};
              accept;
            } else if source = RTS_BGP && dn42_valid6() then accept;
            else reject;
          };
        };
      };
    '';
    ibgp_chi = ibgp {
      name = "chi01";
      peerId = 234;
      mode = "multihop 2";
    };
    ibgp_nyc = ibgp {
      name = "nyc01";
      peerId = 232;
      mode = "multihop 1";
    };
    ibgp_nyc2 = ibgp {
      name = "nyc02";
      peerId = 231;
      mode = "multihop 2";
    };
    ibgp_sea = ibgp {
      name = "sea01";
      peerId = 240;
      mode = "multihop 1";
    };
    ibgp_sjc = ibgp {
      name = "sjc01";
      peerId = 233;
      mode = "multihop 2";
    };
    ibgp_tyo = ibgp {
      name = "tyo01";
      peerId = 236;
      mode = "multihop 2";
    };
    ibgp_ire = ibgp {
      name = "ire01";
      peerId = 237;
      mode = "multihop 3";
    };
    ibgp_mbi = ibgp {
      name = "mbi01";
      peerId = 242;
      mode = "multihop 4";
    };
  in {
    enable = true;
    config = ''
      router id 172.20.170.235;

      function dn42_is_self4() -> bool {
        return net ~ [172.20.170.224/27+];
      };

      function dn42_is_self6() -> bool {
        return net ~ [fde7:76fd:7444::/48+];
      };

      function dn42_valid4() -> bool {
        return net ~ [172.20.0.0/14{21,29},172.20.0.0/24{28,32},172.21.0.0/24{28,32},172.22.0.0/24{28,32},172.23.0.0/24{28,32},172.31.0.0/16+,10.100.0.0/14+,10.127.0.0/16{16,32},10.0.0.0/8{15,24}];
      };

      function dn42_valid6() -> bool {
        return net ~ [fd00::/8{44,64}];
      };

      protocol device {
        scan time 10;
      };

      protocol static {
        check link;
        route 172.20.170.235/32 via "lo";

        ipv4 {
          import all;
          export none;
        };
      };

      protocol static {
        check link;
        route ${dn42NodeIp}/128 via "lo";
        route ${dn42Net} via "lo";
        route ${dn42LanNet} via "lan";
        route fde7:76fd:7444:ffbb::/64 via "lan";

        ipv6 {
          import all;
          export none;
        };
      };

      protocol kernel {
        scan time 20;

        ipv4 {
          import none;

          export filter {
            if source = RTS_STATIC then reject;
            krt_prefsrc = 172.20.170.235;
            accept;
          };
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

      protocol babel joenet_babel {
        interface "nyc-wg" {
          type tunnel;
        };

        interface "sea-wg" {
          type tunnel;
        };

        ipv4 {
          import all;
          export where source != RTS_BGP;
        };

        ipv6 {
          import all;
          export where source != RTS_BGP;
        };
      };
      ${ibgp_chi}
      ${ibgp_nyc}
      ${ibgp_nyc2}
      ${ibgp_sea}
      ${ibgp_sjc}
      ${ibgp_tyo}
      ${ibgp_ire}
      ${ibgp_mbi}

      protocol bgp dn42_fmepg {
        local as 4242420157;
        source address fe80::3703:157;
        neighbor fe80::3703 as 4242423703;
        path metric 1;
        direct;
        interface "fmepg-wg";

        ipv4 {
          next hop self ebgp;
          next hop address 172.20.170.235;
          extended next hop on;

          import filter {
            if dn42_valid4() && !dn42_is_self4() then accept; else reject;
          };
          export filter {
            if !dn42_valid4() then reject;
            else if source ~ [RTS_STATIC, RTS_BABEL] && dn42_is_self4() then accept;
            else if source = RTS_BGP then accept;
            else reject;
          };
        };

        ipv6 {
          next hop self ebgp;
          next hop address fe80::3703:157;
          extended next hop on;

          import filter {
            if dn42_valid6() && !dn42_is_self6() then accept; else reject;
          };

          export filter {
            if !dn42_valid6() then reject;
            else if source ~ [RTS_STATIC, RTS_BABEL] && dn42_is_self6() then accept;
            else if source = RTS_BGP then accept;
            else reject;
          };
        };
      };
    '';
  };

  services.postgresql.enable = true;

  services.syncthing = {
    enable = true;
    guiAddress = "[::1]:8384";
  };

  # otherwise, set up a normal remote builder setup
  users.groups.nix-remote-exec = {};
  users.users.nixos-remote-build = {
    description = "NixOS Remote Build";

    isNormalUser = true;
    extraGroups = ["nix-remote-exec"];
  };

  nix.settings.trusted-users = ["root" "@wheel" "@nix-remote-exec" "@nixbld"];

  services.gpsd = {
    enable = true;
    devices = ["/dev/gpsserial"];
    nowait = true;
  };

  systemd.services.gpsd = {
    requires = ["dev-gpsserial.device"];
  };

  services.chrony = {
    enable = true;
    # don't actually trust servers
    servers = mkForce [];

    extraConfig = ''
      refclock SHM 0 refid GPS1
      allow all
      leapsectz right/UTC
      clientloglimit 100000000
    '';
  };

  services.bird-lg.proxy = {
    enable = true;
    listenAddress = "[${dn42BirdLgProxy}]:9999";
    allowedIPs = [
      "fde7:76fd:7444:ffbb::/64"
    ];
  };
}
