{
  config,
  lib,
  ...
}:
with lib; {
  networking = {
    useNetworkd = true;
    dhcpcd.enable = false;
  };

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    netdevs = {
      # att requires that we send all traffic over vlan 0
      "01-internet" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "internet";
        };
        vlanConfig = {
          Id = 0;
        };
      };

      # auxillary 'IOT' vlan
      "01-iot" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "iot";
        };
        vlanConfig = {
          Id = 2;
        };
      };

      # 'LAN' vlan
      "01-lan" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "lan";
        };
        vlanConfig = {
          Id = 1;
        };
      };
    };

    networks = let
      # standard 'internal' router
      internalRouter = subnet: {
        address = ["192.168.${toString subnet}.1/24"];
        networkConfig = {
          DHCPPrefixDelegation = "yes";
          IPv6SendRA = "yes";
          DHCPServer = "yes";
          IPv6AcceptRA = "no";
          DHCP = "no";
        };
        dhcpServerConfig = {
          DNS = ["_server_address"];
          NTP = ["_server_address"];
        };
        ipv6SendRAConfig.DNS = ["_link_local"];
        dhcpPrefixDelegationConfig.SubnetId = toString subnet;
      };
    in {
      # This is an interface that only exists to host a vlan
      "01-external" = {
        matchConfig.Name = "external";

        vlan = ["internet"];

        # This link should not get an address or really talk to the network
        # at all
        networkConfig = {
          LinkLocalAddressing = "no";
          EmitLLDP = "no";
          LLDP = "no";
          DHCP = "no";
          DHCPServer = "no";
          IPv6SendRA = "no";
          IPv6AcceptRA = "no";
          LLMNR = "no";
        };
      };

      # the actual interface routing traffic
      "01-internet" = {
        matchConfig.Name = "internet";

        networkConfig = {
          DHCPPrefixDelegation = "yes";
          IPv6SendRA = "no";
          DHCPServer = "no";
          IPv6AcceptRA = "yes";
          DHCP = "yes";
        };

        dhcpV4Config = {
          DUIDRawData = config.homerouter.secrets.duid;
          SendHostname = "no";
          UseHostname = "no";
          UseDNS = "no";
          UseNTP = "no";
          UseTimezone = "no";
        };

        dhcpV6Config = {
          DUIDRawData = config.homerouter.secrets.duid;
          WithoutRA = "solicit";
          PrefixDelegationHint = "::/60";
          UseHostname = "no";
          UseDNS = "no";
          UseNTP = "no";
          UseAddress = "no";
        };

        ipv6AcceptRAConfig = {
          UseDNS = "no";
          DHCPv6Client = "always";
        };

        dhcpPrefixDelegationConfig = {
          UplinkInterface = ":self";
        };
      };

      # standard internal interface
      "01-internal" = {
        matchConfig.Name = "internal";

        vlan = ["lan" "iot"];
      };

      "01-lan" = mkMerge [
        {
          matchConfig.Name = "lan";
          ipv6Prefixes = [
            {
              ipv6PrefixConfig = {
                Prefix = "fde7:76fd:7444:fffe::/64";
                Assign = "yes";
              };
            }
          ];
        }
        (internalRouter 2)
      ];

      # super simple interface which is only accessible directly from inside and only runs ipv4
      "01-iot" = {
        matchConfig.Name = "iot";
        address = ["192.168.100.1/24"];
        networkConfig = {
          LinkLocalAddressing = "no";
          DHCPServer = "yes";
          DHCP = "no";
        };
        dhcpServerConfig = {
          DNS = ["_server_address"];
          NTP = ["_server_address"];
          PoolOffset = 100;
        };
      };

      # untrusted ap interface
      "01-untrustedap" = mkMerge [
        {
          matchConfig.Name = "internal";
          dhcpServerConfig = {
            DNS = mkForce ["1.1.1.1" "1.0.0.1"];
          };
          ipv6SendRAConfig.DNS = mkForce ["2606:4700:4700::1111" "2606:4700:4700::1001"];
        }
        (internalRouter 4)
      ];

      "01-lo" = {
        matchConfig.Name = "lo";
        addresses = [
          {
            addressConfig = {
              Address = "127.0.0.1/8";
              Scope = "host";
            };
          }
          {
            addressConfig = {
              Address = "::1/128";
              Scope = "host";
            };
          }
          {
            addressConfig = {
              Address = "172.20.170.224/32";
            };
          }
          {
            addressConfig = {
              Address = "fde7:76fd:7444:ffff::1/128";
            };
          }
          {
            addressConfig = {
              Address = "fde7:76fd:7444:ffff::53/128";
            };
          }
        ];
      };
    };
  };

  # We need a wpa_supplicant to authenticate with att
  wpa_supplicant_att."external" = with config.homerouter.secrets; {
    caCert = caPem;
    clientCert = clientPem;
    clientKey = keyPem;
    identity = mac;
  };
}
