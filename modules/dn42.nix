{
  config,
  lib,
  ...
}:
with lib; let
  extended-types = import ../lib/extended-types.nix {inherit lib;};

  cfg = config.dn42;
  localZone = config.networking.nftables.firewall.localZoneName;

  wgPeer = {config, ...}: {
    options = {
      remoteEndpoint = mkOption {
        type = types.nullOr extended-types.netPortEndpoint;
        description = "Clearnet endpoint of the peer. If specified, opportunistically reach out to the endpoint";
        example = "[2000::]:12345";
      };

      localInterface = mkOption {
        type = types.nullOr types.str;
        description = "local clearnet interface for wireguard";
        example = "eth0";
        default = null;
      };

      localPort = mkOption {
        type = types.nullOr types.port;
        description = "local port to open";
        example = 50000;
      };

      peerPublicKey = mkOption {
        type = extended-types.base64;
        description = "Peer's public key";
        example = "GzuvCBU1kmzqzV5WNufg6ct1UH28mHa5BGZuB1jOXjI=";
      };

      privateKey = mkOption {
        type = types.path;
        description = "Private key";
        default = "/var/wg/private.key";
      };
    };
  };

  ip4PeerAddr = {
    options = {
      local = mkOption {
        type = extended-types.ip4Addr;
        description = "local ipv4 address";
      };

      peer = mkOption {
        type = extended-types.ip4Addr;
        description = "peer ipv4 address";
      };
    };
  };

  ip6PeerAddr = {
    options = {
      local = mkOption {
        type = extended-types.ip6Addr;
        description = "local ipv6 address";
      };

      peer = mkOption {
        type = extended-types.ip6Addr;
        description = "peer ipv6 address";
      };
    };
  };

  bgpSession = {name, ...}: {
    options = {
      name = mkOption {
        type = types.str;
        description = "Name of the bird2 protocol";
      };

      template = mkOption {
        type = types.str;
        default = "dn42_multiprotocol";
        description = "Which BGP session template to use when creating this peer";
      };

      peerAs = mkOption {
        type = types.ints.u32;
        description = "peer's AS number";
        example = 4242420157;
      };

      sourceAddress = mkOption {
        type = types.either extended-types.ip4Addr extended-types.ip6Addr;
        description = "our ip address for originating the bgp session";
      };

      peerAddress = mkOption {
        type = types.either extended-types.ip4Addr extended-types.ip6Addr;
        description = "peer ip address for the other side of the bgp session";
      };
    };

    config = {
      name = mkDefault name;
    };
  };

  dn42Peer = {name, ...}: {
    options = {
      name = mkOption {
        type = types.str;
        description = "name of the peer";
      };

      wg = mkOption {
        type = types.submodule wgPeer;
        description = "Wireguard link details";
      };

      linkIp4 = mkOption {
        type = types.listOf (types.submodule ip4PeerAddr);
        description = "Peer ip4 addresses";
      };

      linkIp6 = mkOption {
        type = types.listOf (types.submodule ip6PeerAddr);
        description = "Peer ip6 addresses";
      };

      bgp = mkOption {
        type = types.attrsOf (types.submodule bgpSession);
        description = "bgp sessions to spawn";
      };
    };
    config = {
      name = mkDefault name;
    };
  };

  mkBirdCfgFromBgpSession = interface: bgp: ''
    protocol bgp ${bgp.name} from ${bgp.template} {
      neighbor ${bgp.peerAddress} as ${bgp.peerAs};
      source address ${bgp.sourceAddress};
      interface ${interface};
    }
  '';

  mkBirdCfgFromPeer = peer:
    mkMerge (map
      (mkBirdCfgFromBgpSession peer.name)
      (attrValues peer.bgp));

  mkNetDevFromWg = interface: wg: {
    "01-${interface}" = {
      netdevConfig = {
        Name = interface;
        Kind = "wireguard";
      };

      wireguardConfig =
        {
          PrivateKeyFile = wg.privateKey;
        }
        // optionalAttrs (wg.localPort != null) {
          ListenPort = wg.localPort;
        };

      wireguardPeers = [
        {
          wireguardPeerConfig =
            {
              PublicKey = wg.peerPublicKey;
              AllowedIPs = ["0.0.0.0/0" "::/0"];
            }
            // optionAttrs (wg.remoteEndpoint != null) {
              Endpoint = wg.remoteEndpoint;
            };
        }
      ];
    };
  };

  mkNetDevFromPeer = peer: mkNetDevFromWg peer.name peer.wg;

  mkP2PNet = {
    interface,
    local,
    peer,
  }: {
    "01-${interface}" = {
      matchConfig.Name = interface;

      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = "no";
      };

      addresses = [
        {
          addressConfig = {
            Address = local;
            Peer = peer;
            Scope = "link";
            RouteMetric = 2048;
          };
        }
      ];
    };
  };

  mkNetworkFromIp4 = interface: ip4Peer:
    mkP2PNet {
      inherit interface;
      local = "${ip4Peer.local}/32";
      peer = "${ip4Peer.peer}/32";
    };

  mkNetworkFromIp6 = interface: ip6Peer:
    mkP2PNet {
      inherit interface;
      local = "${ip4Peer.local}/128";
      peer = "${ip4Peer.peer}/128";
    };

  mkNetworksFromPeer = peer:
    (map (mkNetworkFromIp4 peer.name) peer.linkIp4)
    ++ (map (mkNetworkFromIp6 peer.name) peer.linkIp6);

  shouldMkWgFwRule = wg: wg.localInterface != null && wg.localPort != null;

  mkFwZoneFromWg = interface: wg: {
    "dn42-wg-${interface}-peer" = mkIf (shouldMkWgFwRule wg) {
      interfaces = [wg.localInterface];
    };
  };

  mkFwRuleFromWg = interface: wg: {
    "dn42-wg-${interface}" = mkIf (shouldMkWgFwRule wg) {
      from = ["dn42-wg-${interface}-peer"];
      to = localZone;
      allowedUDPPorts = [wg.localPort];
    };
  };

  is4Addr = a: builtins.match ''((25[0-5]|(2[0-4]|1[0-9]|[1-9])[0-9])\.?){4}'' a != null;

  mkFwZoneFromBgp = interface: bgp: {
    "dn42-bgp-${bgp.name}-peer" =
      {
        interfaces = [interface];
      }
      // (
        if (traceVal (is4Addr (traceVal bgp.peerAddress)))
        then {
          ipv4Addresses = [ bgp.peerAddress ];
        }
        else {
          ipv6Addresses = [ bgp.peerAddress ];
        }
      );
  };

  mkFwRuleFromBgp = bgp: let
    protocol =
      if (is4Addr bgp.sourceAddress)
      then "ip"
      else "ip6";
  in {
    "dn42-bgp-${bgp.name}" = {
      from = ["dn42-bgp-${bgp.name}-peer"];
      to = localZone;
      extraLines = [
        ''${protocol} daddr ${bgp.sourceAddress} tcp dport 179 accept''
      ];
    };
  };

  mkFwZonesFromPeer = peer:
    [
      (mkFwZoneFromWg peer.name peer.wg)
    ]
    ++ (map (mkFwZoneFromBgp peer.name) (attrValues peer.bgp));

  mkFwRulesFromPeer = peer:
    [
      (mkFwRuleFromWg peer.name peer.wg)
    ]
    ++ (map mkFwRuleFromBgp (attrValues peer.bgp));

  birdPreamble = ''
    router id ${cfg.ip4Self};
  '';

  birdFunctions = ''
    function dn42_is_self4() -> bool {
      return net ~ [${cfg.ip4SelfNet}];
    };

    function dn42_is_self6() -> bool {
      return net ~ [${cfg.ip6SelfNet}];
    };

    function dn42_valid4() -> bool {
      return net ~ [${cfg.ip4Dn42Net}];
    };

    function dn42_valid6() -> bool {
      return net ~ [${cfg.ip6Dn42Net}];
    };
  '';

  ip4PrefSrc = optionalString (cfg.ip4Self != null) ''
    krt_prefsrc = ${cfg.ip4Self};
  '';

  ip6PrefSrc = optionalString (cfg.ip6Self != null) ''
    krt_prefsrc = ${cfg.ip6Self};
  '';

  birdKernel = ''
    protocol device {
      scan time 10;
    };

    protocol kernel {
      scan time 20;

      ipv4 {
        import none;
        export filter {
          if source = RTS_STATIC then reject;
          ${ip4PrefSrc}
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
          ${ip6PrefSrc}
          accept;
        };
      };
    };
  '';

  birdAdvertisement = ''
    protocol static {
      check link;
      ${cfg.ip4Advertisements}

      ipv4 {
        import all;
        export none;
      };
    };

    protocol static {
      check link;
      ${cfg.ip6Advertisements}

      ipv6 {
        import all;
        export none;
      };
    };
  '';

  birdTemplate = ''
    template bgp dn42_multiprotocol {
      local as ${toString cfg.asNumber};
      path metric 1;

      ipv4 {
        import filter {
          if is_valid_network() && !is_self_net() then {
            if (roa_check(dn42_roa_v4, net, bgp_path.last) != ROA_VALID) then {
                print "[dn42] ROA check failed for ", net, " ASN ", bgp_path.last;
                reject;
            } else accept;
          } else reject;
        };

        export filter {
          if is_valid_network() && source ~ [RTS_STATIC, RTS_BGP] then accept;
          reject;
        };

        import limit 1000 action block;
      };

      ipv6 {
        import filter {
          if is_valid_network_v6() && !is_self_net_v6() then {
            if (roa_check(dn42_roa_v6, net, bgp_path.last) != ROA_VALID) then {
                print "[dn42] ROA check failed for ", net, " ASN ", bgp_path.last;
                reject;
            } else accept;
          } else reject;
        };

        export filter {
          if is_valid_network_v6() && source ~ [RTS_STATIC, RTS_BGP] then accept;
          reject;
        };

        import limit 1000 action block;
      };
    };
  '';
in {
  options.dn42 = {
    enable = mkEnableOption "dn42 router";

    asNumber = mkOption {
      type = types.ints.u32;
      description = "my AS number";
      example = 4242420157;
    };

    ip4Dn42Net = mkOption {
      type = types.commas;
      description = "ip4 networks which are valid to be advertised across the dn42 network";
      default = mkMerge [
        "172.20.0.0/14{21,29}" # dn42
        "172.20.0.0/24{28,32}" # dn42 Anycast
        "172.21.0.0/24{28,32}" # dn42 Anycast
        "172.22.0.0/24{28,32}" # dn42 Anycast
        "172.23.0.0/24{28,32}" # dn42 Anycast
        "172.31.0.0/16+" # ChaosVPN
        "10.100.0.0/14+" # ChaosVPN
        "10.127.0.0/16{16,32}" # neonetwork
        "10.0.0.0/8{15,24}" # Freifunk.net
      ];
    };

    ip6Dn42Net = mkOption {
      type = types.commas;
      description = "ip6 networks which are valid to be advertised across the dn42 network";
      default = mkMerge [
        "fd00::/8{44,64}"
      ];
    };

    ip4Self = mkOption {
      type = extended-types.ip4Addr;
      description = "router ip4 address";
      default = null;
    };

    ip6Self = mkOption {
      type = extended-types.ip6Addr;
      description = "router ip6 address";
      default = null;
    };

    ip4SelfNet = mkOption {
      type = types.commas;
      description = "ip4 networks we should reject from importing from our peers";
    };

    ip6SelfNet = mkOption {
      type = types.commas;
      description = "ip6 networks we should reject from importing from our peers";
    };

    ip4Advertisements = mkOption {
      type = types.lines;
      description = "ip4 advertisements to advertise";
      default = "";
    };

    ip6Advertisements = mkOption {
      type = types.lines;
      description = "ip6 advertisements to advertise";
      default = "";
    };

    peers = mkOption {
      type = types.attrsOf (types.submodule dn42Peer);
      description = "peers to this node";
    };
  };

  config = let
    peers = attrValues cfg.peers;
    deriveAttr = k: attrs:
      if attrs ? k
      then (getAttr k attrs)
      else {};
  in {
    services.bird2 = mkIf cfg.enable {
      enable = true;
      config = mkMerge ([
          birdPreamble
          birdFunctions
          birdKernel
          birdAdvertisement
          birdTemplate
        ]
        ++ (map mkBirdCfgFromPeer peers));
    };

    systemd.network.netdevs = mkMerge (map mkNetDevFromPeer peers);
    systemd.network.networks = mkMerge (concatMap mkNetworksFromPeer peers);
    networking.nftables.firewall.zones = mkMerge (concatMap mkFwZonesFromPeer peers);
    networking.nftables.firewall.rules = mkMerge (concatMap mkFwRulesFromPeer peers);

    assertions = [
      {
        assertion = all (peer: peer.wg.remoteEndpoint != null || peer.wg.localPort != null) peers;
        message = "Either a remote endpoint or a local port must be defined";
      }
    ];
  };
}
