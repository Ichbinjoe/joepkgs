{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
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
  services = {
    # don't use resolved
    resolved.enable = false;

    unbound = {
      # we want unbound to handle our DNS
      enable = true;
      settings = {
        server = {
          interface = ["lan"];
          prefer-ip6 = true;
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
  };
}
