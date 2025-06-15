{lib, ...}: {
  imports = lib.filesystem.listFilesRecursive ./peers;
  dn42 = {
    enable = true;
    enableGrc = true;
    asNumber = 4242420157;
    ip4Self = "172.20.170.224";
    ip6Self = "fde7:76fd:7444:ffff::1";
    ip4SelfNet = "172.20.170.224/27";
    ip6SelfNet = "fde7:76fd:7444::/48";
    ip4Advertisements = ''
      route 172.20.170.224/29 via "lo";
      route 172.20.170.224/27 unreachable;
    '';
    ip6Advertisements = ''
      route fde7:76fd:7444:fffe::/64 via "lan";
      route fde7:76fd:7444:ffff::/64 via "lo";
    '';
  };

  services.bird2.config = lib.mkAfter ''
    protocol ospf v2 nyc_v4 {
      area 0.0.0.0 {
        interface "nyc-wg" {
          type ptmp;
          neighbors {
            172.20.170.232;
          };
        };
      };

      ipv4 {
        import filter {
          if dn42_valid4() && dn42_is_self4() then accept;
          else reject;
        };

        export filter {
          if dn42_valid4() && source ~ [RTS_STATIC, RTS_BGP, RTS_OSPF, RTS_OSPF_IA, RTS_OSPF_EXT1, RTS_OSPF_EXT2] then accept;
          else reject;
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
        import filter {
          if dn42_valid6() && dn42_is_self6() then accept;
          else reject;
        };

        export filter {
          if dn42_valid6() && source ~ [RTS_STATIC, RTS_BGP, RTS_OSPF, RTS_OSPF_IA, RTS_OSPF_EXT1, RTS_OSPF_EXT2] then accept;
          else reject;
        };
      };
    };
  '';
}
