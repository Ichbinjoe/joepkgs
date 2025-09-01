{
  lib,
  pkgs,
  ...
}: {
  options = {};
  config = let
    dn42DS = tag: digest: {inherit tag digest;};
    dn42Zone = zone: dss: {inherit zone dss;};

    dn42AuthoritativeZones = [
      (dn42Zone "10.in-addr.arpa." [
        (dn42DS "64441" "8a39e9df85a73f1982e43c9139e095e8548451d2048d92c2703869ef8bfebbb4")
        (dn42DS "3096" "1fa3673dc2cf9ffa82b429bf25405b44931460b7263a081d586cc61f003a10a2")
      ])
      (dn42Zone "20.172.in-addr.arpa." [
        (dn42DS "64441" "616c149633e93d963b0e8f738719630ea0a09f4aabe211b1fbb8fc9f51304027")
        (dn42DS "3096" "6adf85efddf223c8747f1816b12b62feea0b9b1bdb65e7c809202f890a33740d")
      ])
      (dn42Zone "21.172.in-addr.arpa." [
        (dn42DS "64441" "4cc085716ba83f18df1a7fb9f9479d10327e3d30e222c7a197109c7560ae0368")
        (dn42DS "3096" "506fd7f34aaad4df1b6cfa56fe8c00e157b1c32551c981def0c5fd8f65ab14ac")
      ])
      (dn42Zone "22.172.in-addr.arpa." [
        (dn42DS "64441" "383a8c2714d3da76f58cee4c54566566b336b2dfa219b965f7cb706d71c54356")
        (dn42DS "3096" "5437ab49f1cd947d41c585c2cc9c357323013391b0e5f94784f99175142c3260")
      ])
      (dn42Zone "23.172.in-addr.arpa." [
        (dn42DS "64441" "e91c0281e705317968c76689e4f36bf2207c90bdfaad071693bb9a999d15778f")
        (dn42DS "3096" "631b00ba00cf80a8300b356bcca2fde4c844f6ff707a2d98b4518c72e0643467")
      ])
      (dn42Zone "31.172.in-addr.arpa." [
        (dn42DS "64441" "5f668f3083d65650ab5c4e9fccdddd0c8108e0fa4be39e161e6a58d1741c5b2d")
        (dn42DS "3096" "4ab3c242fdfa6d84cbe83d5c9b0f9b431c6974dd18db32d08a2599ab1b816465")
      ])
      (dn42Zone "dn42." [
        (dn42DS "64441" "6dadda00f5986bd26fe4f162669742cf7eba07d212b525acac9840ee06cb2799")
        (dn42DS "3096" "b7c687a99bee60e172ea439bd2d3087b1d970916575db9c1cb591b7ee15d8cb1")
      ])
      (dn42Zone "d.f.ip6.arpa." [
        (dn42DS "64441" "9057500a3b6e09bf45a60ed8891f2e649c6812d5d149c45a3c560fa0a6195c49")
        (dn42DS "3096" "23fb364c82e6ed1c30b18c635f58dca58bbeb2e069bbd9d90ab9a90f66b948d2")
      ])
    ];

    dn42DlgServer = name: ipv6: ipv4: {
      inherit ipv6 ipv4;
      name = "${name}.delegation-servers.dn42.";
    };

    dn42DelegationServers = [
      (dn42DlgServer "b" "fd42:4242:2601:ac53::1" "172.20.129.1")
      (dn42DlgServer "k" "fdcf:8538:9ad5:1111::2" "172.20.14.34")
      (dn42DlgServer "j" "fd42:5d71:219:0:216:3eff:fe1e:22d6" "172.20.1.254")
      (dn42DlgServer "l" "fd86:bad:11b7:53::1" "172.22.108.54")
    ];
  in {
    services.resolved.enable = false;

    services.unbound = {
      enable = true;
      settings = {
        server = {
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

          # dn42 specific stuff
          local-zone = map (z: ''"${z.zone}" typetransparent'') dn42AuthoritativeZones;
          private-domain = map (z: z.zone) dn42AuthoritativeZones;
          trust-anchor-file = let
            trustEntry = zone: ds: ''${zone} 86400 IN  DS  ${ds.tag} 10  2 ${ds.digest}'';
            trustEntriesForZone = z: map (trustEntry z.zone) z.dss;
            f = builtins.concatStringsSep "\n" (builtins.concatMap trustEntriesForZone dn42AuthoritativeZones);
          in
            toString (pkgs.writeText "dn42-trust-anchor" f);
        };

        remote-control = {
          control-enable = true;
          control-interface = "/run/unbound/unbound.socket";
        };

        stub-zone = let
          stub = z: {
            name = z.zone;
            stub-host = map (d: d.name) dn42DelegationServers;
          };
        in
          map stub dn42AuthoritativeZones;

        auth-zone = let
          nsEntry = ds: "delegation-servers.dn42. 900 IN  NS  ${ds.name}";
          aaaaEntry = ds: "${ds.name} 900 IN  AAAA  ${ds.ipv6}";
          aEntry = ds: "${ds.name} 900 IN  A  ${ds.ipv4}";
          nsEntries = map nsEntry dn42DelegationServers;
          aEntries = lib.concatMap (ds: [(aaaaEntry ds) (aEntry ds)]) dn42DelegationServers;
        in [
          {
            name = "delegation-servers.dn42.";
            for-upstream = true;
            for-downstream = false;
            zonefile = toString (pkgs.writeText "dn42-delegation-servers-zonefile"
              ''
                delegation-servers.dn42.  900 IN  SOA b.master.delegation-servers.dn42. burble.dn42.  1707593005 900 900 86400 900
                ${builtins.concatStringsSep "\n" nsEntries}
                ${builtins.concatStringsSep "\n" aEntries}
              '');
          }
        ];
      };
    };
  };
}
