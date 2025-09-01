{
  config,
  lib,
  pkgs,
  ...
}: {
  options.dn42Wg = with lib; let
    dn42AddrPair = {
      options = {
        localAddr = mkOption {
          type = types.singleLineStr;
        };

        peerAddr = mkOption {
          type = types.singleLineStr;
        };
      };
    };
    dn42Peer = {
      options = {
        publicKey = mkOption {
          type = types.singleLineStr;
        };

        endpoint = mkOption {
          type = types.nullOr types.singleLineStr;
          default = null;
        };

        addresses = mkOption {
          type = types.listOf (types.submodule dn42AddrPair);
        };
      };
    };
  in {
    allowedIps = mkOption {
      type = types.listOf types.singleLineStr;
      default = [];
    };
    peers = mkOption {
      type = types.attrsOf (types.submodule dn42Peer);
      default = {};
    };
  };
  config = let
    cfg = config.dn42Wg;
  in {
    environment.systemPackages = with pkgs; [
      wireguard-tools
    ];

    networking.useNetworkd = true;
    systemd.network.enable = true;

    systemd.network.netdevs = let
      netdev = ifname: peer: {
        name = "01-${ifname}";
        value = {
          netdevConfig = {
            Name = ifname;
            Kind = "wireguard";
          };

          wireguardConfig = {
            PrivateKeyFile = "/etc/wireguard/private.key";
          };

          wireguardPeers = [
            ({
                PublicKey = peer.publicKey;
                AllowedIPs = cfg.allowedIps;
              }
              // (lib.optionalAttrs (peer.endpoint != null) {
                Endpoint = peer.endpoint;
              }))
          ];
        };
      };
    in
      lib.mapAttrs' netdev cfg.peers;

    systemd.network.networks = let
      addressEntry = p: {
        Address = p.localAddr;
        Peer = p.peerAddr;
        Scope = "link";
        RouteMetric = 2048;
      };

      network = ifname: peer: {
        name = "01-${ifname}";
        value = {
          matchConfig.Name = ifname;

          networkConfig = {
            DHCP = "no";
            IPv6AcceptRA = "no";
          };

          addresses = map addressEntry peer.addresses;
        };
      };
    in
      lib.mapAttrs' network cfg.peers;
  };
}
