{
  config,
  lib,
  ...
}:
with lib; let
  enabledExporters = filterAttrs (n: v: v.enable or false) config.services.prometheus.exporters;
  enabledExporterPorts = mapAttrsToList (n: v: v.port) enabledExporters;
  dn42Peers = attrValues config.dn42.peers;
  dn42Interfaces = (map (p: p.name) dn42Peers) ++ ["nyc-wg"];
  localZone = config.networking.nftables.firewall.localZoneName;

  ports = {
    ssh = 22; # tcp
    dns = 53; # tcp + udp
    dhcp4solicit = 67; # udp
    dhcp4advertise = 68; # udp
    ntp = 123; # udp
    dhcp6advertise = 546; # udp
    dnstcp = 853; # tcp
  };
in {
  networking.nftables.chains = {
    input.conntrack = {
      after = mkForce ["veryEarly"];
      before = ["early"];
      rules = [
        "ct state {established, related} accept"
        "ct state invalid drop"
      ];
    };

    forward.conntrack = {
      after = mkForce ["veryEarly"];
      before = ["early"];
      rules = [
        "ct state {established, related} accept"
        "iifname {lan, internet} ct state invalid drop"
        "oifname {lan, internet} ct state invalid drop"
      ];
    };
  };

  networking.nftables.firewall = {
    enable = true;

    zones = rec {
      internet = {
        interfaces = ["internet"];
      };

      lan = {
        interfaces = ["lan"];
      };

      lanDn42 = {
        interfaces = ["lan"];
        ipv6Addresses = ["fde7:76fd:7444::/48"];
      };

      iot = {
        interfaces = ["iot"];
      };

      dn42Routable = {
        interfaces = dn42Interfaces;
        ipv4Addresses = ["172.20.0.0/14" "10.0.0.0/8"];
        ipv6Addresses = ["fd00::/8"];
      };

      nyc = {
        interfaces = ["nyc-wg"];
      };
    };

    snippets.nnf-common.enable = false;
    snippets.nnf-default-stopRuleset.enable = false;
    snippets.nnf-conntrack.enable = false;
    snippets.nnf-drop.enable = true;
    snippets.nnf-icmp.enable = true;
    snippets.nnf-loopback.enable = true;
    snippets.nnf-ssh.enable = true;

    rules = {
      lanEgress = {
        from = ["lan"];
        to = ["internet" "dn42Routable"];
        verdict = "accept";
        masquerade = true;
      };

      dhcp4Server = {
        from = ["lan" "iot"];
        to = [localZone];
        allowedUDPPorts = [67];
      };

      dhcpClient = {
        from = ["internet"];
        to = [localZone];
        allowedUDPPorts = [68 546];
      };

      dns = {
        from = ["lan" "dn42Routable"];
        to = [localZone];
        allowedUDPPorts = [53];
        allowedTCPPorts = [53 853];
      };

      ntp = {
        from = ["lan" "iot" "dn42"];
        to = [localZone];
        allowedUDPPorts = [123];
      };

      dn42Transit = {
        from = ["dn42Routable" "lanDn42"];
        to = ["dn42Routable" "lanDn42"];
        verdict = "accept";
        before = ["conntrack"];
      };

      pdnsApi = {
        from = ["lan"];
        to = [localZone];
        allowedTCPPorts = [8081];
      };

      monitorPorts = {
        from = ["lan"];
        to = [localZone];
        allowedTCPPorts = enabledExporterPorts;
      };
    };
  };

  # we have a special invocation just for setting up flow tables
  networking.nftables.ruleset = let
    dn42Ifaces = concatStringsSep ", " dn42Interfaces;
    trackedInterfaces = concatStringsSep ", " (["lan" "internet"] ++ dn42Interfaces);
  in ''
    table ip ip4_ospf {
      chain input {
        type filter hook input priority 0;
        ip saddr 172.20.170.232 ip daddr 172.20.170.224 ip protocol 89 meta iifname "nyc-wg" accept;
        ip protocol 89 reject;
      }
    }
    table ip6 ip6_ospf {
      chain input {
        type filter hook input priority 0;
        ip6 saddr fe80::101 ip6 daddr fe80::100 ip6 nexthdr 89 meta iifname "nyc-wg" accept;
        ip6 nexthdr 89 reject;
      }
    }

    table ip ip4_flow {
      flowtable f4 {
        hook ingress priority 0;

        devices = { ${trackedInterfaces} }
      }

      chain forward {
        type filter hook forward priority 1; policy accept;

        # Do not try to track flows that don't enter our network
        iifname { ${dn42Ifaces} } oifname { ${dn42Ifaces} } return;

        ip protocol { tcp, udp, icmp } flow add @f4
      }
    }

    table ip6 ip6_flow {
      flowtable f6 {
        hook ingress priority 0;

        devices = { ${trackedInterfaces} }
      }

      chain forward {
        type filter hook forward priority 1; policy accept;

        # Do not try to track flows that don't enter our network
        iifname { ${dn42Ifaces} } oifname { ${dn42Ifaces} } return;

        meta l4proto { tcp, udp, icmpv6 } flow add @f6
      }
    }
  '';
}
