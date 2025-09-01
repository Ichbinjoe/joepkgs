{
  config,
  lib,
  ...
}: {
  options = with lib; {
    dn42 = {
      addrs = mkOption {
        type = types.listOf types.singleLineStr;
        default = [];
      };

      advertisements4 = mkOption {
        type = types.listOf types.singleLineStr;
        default = [];
      };

      advertisements6 = mkOption {
        type = types.listOf types.singleLineStr;
        default = [];
      };
    };
  };

  config = let
    nodeId = 243;
    nodeIpv4 = id: "172.20.170.${toString id}";
    myIpv4 = nodeIpv4 nodeId;
    nodePrefix = "fde7:76fd:7444:aaaa";
    nodeUla = id: "${nodePrefix}::${toString id}";
    nodeLL = id: "fe80::157:${toString id}";
    myUla = nodeUla nodeId;

    peers = {
      "chi01" = 234;
      "ire01" = 237;
      "joebox" = 235;
      "nyc01" = 232;
      "sea01" = 240;
      "sjc01" = 233;
      "tyo01" = 236;
      "nyc02" = 231;
      "testrack" = 241;
      "mbi01" = 242;
      # "nasbox" = 243;
    };

    neighbors = {
      "sjc01" = {
        pubKey = "sl9vN6wmKuB3aGjBYx2ukjABc66EAn0p5VJsg0XjjjM=";
        endpoint = "sjc01.ke8jwh.com";
      };
      "sea01" = {
        pubKey = "9vBrb8Jq3WmifgCjncMzLZvdkoDi3FoSvHjJGsUMwGg=";
        endpoint = "sea01.ke8jwh.com";
      };
      "joebox" = {
        pubKey = "U0z+fIL/2uXvT2+q6dqtBYajcnw0jm6ekeZKPZYCaxU=";
        endpoint = "192.168.2.1";
      };
    };

    mkWg = name: entry: ({
        publicKey = entry.pubKey;
        addresses = [
          {
            localAddr = "${nodeLL nodeId}/128";
            peerAddr = "${nodeLL peers.${name}}/128";
          }
        ];
      }
      // (lib.optionalAttrs (lib.hasAttr "endpoint" entry) {
        endpoint = "${entry.endpoint}:40${toString nodeId}";
      }));
  in {
    dn42 = {
      addrs = [
        "${myIpv4}/32"
        "${myUla}/128"
      ];
      advertisements4 = [
        "${myIpv4}/32"
      ];
      advertisements6 = [
        "${myUla}/128"
      ];
    };

    systemd.network.networks = {
      "01-lo" = {
        matchConfig.Name = "lo";

        addresses =
          map (a: {
            Address = a;
          })
          config.dn42.addrs;
      };
    };

    dn42Wg = {
      allowedIps = [
        "172.20.0.0/14"
        "10.0.0.0/8"
        "fd00::/8"
        "fe80::/10"
        "ff00::/8"
        "169.254.0.0/16"
      ];

      peers = lib.mapAttrs mkWg neighbors;
    };

    dn42Bird = {
      inherit nodePrefix;
      enable = true;
      roaEnable = true;

      routerId = myIpv4;
      local4 = myIpv4;
      localUla = myUla;
      localAs = 4242420157;

      regionCode = 44;
      countryCode = 1840;

      selfNetworks4 = "172.20.170.224/27+";
      selfNetworks6 = "fde7:76fd:7444::/48+";

      valid4 = "172.20.0.0/14{21,29},172.20.0.0/24{28,32},172.21.0.0/24{28,32},172.22.0.0/24{28,32},172.23.0.0/24{28,32},172.31.0.0/16+,10.100.0.0/14+,10.127.0.0/16{16,32},10.0.0.0/8{15,24}";
      valid6 = "fd00::/8{44,64}";

      validBh4 = "172.20.0.0/14{21,32},172.20.0.0/24{28,32},172.21.0.0/24{28,32},172.22.0.0/24{28,32},172.23.0.0/24{28,32},172.31.0.0/16+,10.100.0.0/14+,10.127.0.0/16{16,32},10.0.0.0/8{15,32}";
      validBh6 = "fd00::/8{44,128}";

      ibgpHops = 3;
      babelInterfaces = lib.attrNames neighbors;
      advertisements = {
        "static4" = {
          advertise = config.dn42.advertisements4;
          protocol = "ipv4";
        };
        "static6" = {
          advertise = config.dn42.advertisements6;
          protocol = "ipv6";
        };
      };

      ibgps = lib.mapAttrs (_: peerId: {inherit peerId;}) peers;
    };
  };
}
