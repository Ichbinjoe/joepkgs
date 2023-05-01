# router-oriented configuration of interfaces - likely has some very
# me-specific setup stuff built in

{ config, pkgs, ... }: with lib;
let
  mkBasicOption = type: description: mkOption { inherit type description; };
  mkOptOption = type: mkBasicOption (types.nullOr type);
  wiredWpaOpts = {
    options = {
      enable = mkEnableOption "wired wpa supplicant";
      caCert = mkBasicOption types.path "System path of wpa_supplicant-wired CA certificate";
      clientCert = mkBasicOption types.path "System path of wpa_supplicant-wired client certificate";
      clientKey = mkBasicOption types.path "System path of wpa_supplicant-wired client key";
    };
  };

  ifaceMatchOpts = {
    options = {
      macAddress = mkOptOption types.str "MAC address to match on";
      permMacAddress = mkOptOption types.str "Permanent MAC address to match on";
      path = mkOptOption types.str "udev path to match on";
    };
  };

  duidOpts = {
    options = {
      type = mkOptOption types.str "DHCP DUID Type to use to generate";
      raw = mkOptOption types.str "DHCP DUID to use";
    };
  };

  dhcpv4Opts = {
    options = {
      enable = mkEnableOption "DHCPv4 client";
      sendHostname = mkOptOption types.bool "Whether to send the hostname with the DHCPv4 solicitation";
      useDns = mkOptOption types.bool "Whether to use DNS from the DHCPv6 advertisement";
      duid = mkBasicOption (types.submodule duidOpts) "DUID Options";
    };
  };

  dhcpv6Opts = {
    options = {
      enable = mkEnableOption "DHCPv6 client";
      useDns = mkOptOption types.bool "Whether to use DNS from the DHCPv6 advertisement";
      duid = mkBasicOption (types.submodule duidOpts) "DUID Options";
      prefixDelegationHint = mkOptOption types.str "Prefix delegation hint";
    };
  };

  dhcpv4ServerOpts = {
    options = {
      enable = mkEnableOption "DHCPv4 server";
    };
  };

  ipv4RouterOpts = {
    options = {
      forward = mkEnableOption "forwarding";
      masquerade = mkEnableOption "masquerading";
      dhcp = mkBasicOption (types.submodule dhcpv4ServerOpts) "DHCPv4 server";
    };
  };

  dhcpPrefixDelOpts = {
    options = {
      enable = mkEnableOption "DHCP prefix delegation";
      # TODO: this can also be set to auto, but since that's the default we don't try to complicate this
      subnetId = mkOptOption types.ints.positive "Prefix delegation subnet ID";
    };
  };

  ipv6RouterOpts = {
    options = {
      forward = mkEnableOption "forwarding";
      masquerade = mkEnableOption "masquerading";
      sendRa = mkEnableOption "sending IPv6 router advertisements";
      prefixDelegation = mkBasicOption (types.submodule dhcpPrefixDelOpts) "DHCP prefix delegation";
    };
  };

  networkOpts = {
    options = {
      blackhole = mkOption {
        type = types.bool;
        default = false;
      };
      requiredForOnline = mkBasicOption types.bool "Whether this interface is required for the network to be considered online";
      mtu = mkOptOption types.ints.positive "MTU to use if not inferred";
      vlans = mkBasicOption types.lazyAttrsOf (types.submodule vlanOpts) "VLANs";
      address = mkBasicOption (types.listOf types.str) "Addresses to attach to this interface";
      dhcpv4Client = mkBasicOption (types.submodule dhcpv4Opts) "dhcpv4 client";
      dhcpv6Client = mkBasicOption (types.submodule dhcpv6Opts) "dhcpv6 client";
      ipv4Router = mkBasicOption (types.submodule ipv4RouterOpts) "ipv4 router";
      ipv6Router = mkBasicOption (types.submodule ipv6RouterOpts) "ipv6 router";
    };
  };

  vlanOpts = { name, ... }: {
    options = {
      name = mkBasicOption types.str "Friendly name for this interface";
      id = mkBasicOption types.ints.positive "id to use for the vlan";
      network = mkBasicOption (types.submodule networkOpts) "Higher-order network options";
    };

    config = {
      name = mkDefault name;
    };
  };

  interfaceOpts = { name, ... }: {
    options = {
      name = mkBasicOption types.str "Friendly name for the interface";
      match = mkBasicOption (types.submodule ifaceMatchOpts) "Match options for the interface";
      macAddress = mkOptOption types.str "MAC address to force";
      wiredWpaSupplicant = mkBasicOption (types.submodule wiredWpaOpts) "Wired WPA supplicant settings to use if necessary";
      network = mkBasicOption (types.submodule) "Higher-order network options";
    };

    config = {
      name = mkDefault name;
    };
  };

  networkOpts = {
    options = {
      enable = mkEnableOption "network management";
      interfaces = mkBasicOption (types.lazyAttrsOf (types.submodule interfaceOpts)) "interfaces";
    };
  };
in
{
  imports = [ ];
  options.joeos = {
    network = mkBasicOption (types.submodule networkOpts) "Networking";
  };

  config =
    let
      network = config.network;
      interfaces = attrValues network.interfaces;
      mkIfSet = v: lib.mkIf v != null v;
      enableIf = v: mkIf (v == true) "true";
    in
    {
      # if we think we need wpa_supplicant, we need to pull in the systemd packages so that
      # the units can be symlink'd in as intended
      systemd.packages = mkIf (any (i: i.wiredWpaSupplicant.enable) interfaces) [ pkgs.wpa_supplicant ];

      systemd.network = {
        enable = network.enable;
        # create a link config for interface
        links = lib.mapAttrs'
          (iface: lib.nameValuePair "01-${iface.name}" {
            matchConfig = {
              MacAddress = mkIfSet iface.match.macAddress;
              PermanentMacAddress = mkIfSet iface.match.permMacAddress;
              Path = mkIfSet iface.match.path;
            };
            linkConfig = {
              MACAddress = mkIfSet iface.macAddress;
              Name = iface.name;
              MTUBytes = mkIfSet iface.network.mtu;
            };
          })
          interfaces;

        # we only need to make netdevs for vlans - of course, it is a recursive
        # option, so we need to recursively pull out all vlan configs independently.
        netdevs =
          let
            mkNetdevFromVlan = vlan:
              lib.nameValuePair "01-${vlan.name}" {
                netdevConfig = {
                  Name = vlan.name;
                  Kind = "vlan";
                  MTUBytes = mkIfSet vlan.network.mtu;
                };
                vlanConfig = {
                  Id = vlan.id;
                };
              };
            mkNetdevsFromVlan =
              vlan: [ mkNetdevFromVlan vlan ] ++ mkAllNetdevsForNetwork vlan.network;
            mkAllNetdevsForNetwork =
              n: lib.concatMap mkNetdevsFromVlan (attrValues n.vlans);
            baseNetworks = map (i: i.network) interfaces;
          in
          listToAttrs (lib.concatMap mkAllNetdevsForNetwork baseNetworks);

        networks =
          let
            mkNetStackOpt = ipv4: ipv6:
              lib.mkIf (ipv4 || ipv6) (if ipv4 then (if ipv6 then "yes" else "ipv4") else "ipv6");

            mkDuidDhcp = duid: {
              DUIDType = mkIfSet duid.type;
              DUIDRawData = mkIfSet duid.raw;
            };
            mkSysdNetFromNet = name: net:
              lib.nameValuePair "01-${name}" {
                inherit name;
                vlan = mkIf (net.vlans != { }) (map (v: v.name) (attrValues net.vlans));
                DHCP = mkNetStackOpt net.dhcpv4Client.enable net.dhcpv6Client.enable;
                linkConfig.RequiredForOnline = enableIf net.requiredForOnline;
                networkConfig = {
                  IPForward = mkNetStackOpt net.ipv4Router.forward net.ipv6Router.forward;
                  IPMasquerade = mkNetStackOpt net.ipv4Router.masquerade net.ipv6Router.masquerade;
                  DHCPServer = enableIf net.ipv4Router.dhcp.enable;
                  IPv6SendRA = enableIf net.ipv6Router.sendRa;
                  DHCPv6PrefixDelegation = enableIf net.ipv6Router.prefixDelegation.enable;
                } // mkIf net.blackhole {
                  LinkLocalAddressing = "no";
                  LLDP = false;
                  EmitLLDP = false;
                  IPv6AcceptRA = false;
                  IPv6SendRA = false;
                };

                address = net.address;

                dhcpV4Config = with net.dhcpv4Client; mkIf enable ({
                  SendHostname = mkIfSet sendHostname;
                  UseDNS = mkIfSet useDns;
                } // mkDuidDhcp duid);

                dhcpv6Config = with net.dhcpv6Client; mkIf enable ({
                  UseDNS = mkIfSet useDns;
                  PrefixDelegationHint = mkIfSet prefixDelegationHint;
                } // mkDuidDhcp duid);

                dhcpServerConfig = mkIf net.ipv4Router.dhcp.enable {
                  SendOption = mkIf (net.mtu != null) "26:uint16:${net.mtu}";
                };

                dhcpV6PrefixDelegationConfig = mkIf net.ipv6Router.prefixDelegation.enable {
                  SubnetId = mkIfSet net.ipv6Router.prefixDelegation.subnetId;
                };
              };
            # works for both interfaces & vlans!
            mkSysdNetFromObj = o: mkSysdNetFromNet o.name o.network;

            mkAllNetworks = o: [ mkSysdNetFromObj o ] ++ lib.concatMap mkAllNetworks (attrValues o.network.vlans);
          in
          listToAttrs (lib.concatMap mkAllNetworks interfaces);
      };

      # create systemd overrides for each wpa_supplicant-wired needed.
      systemd.services =
        let
          mkWpaWiredForIface =
            i: lib.nameValuePair "wpa_supplicant-wired@${i.name}" {
              overrideStrategy = "asDropin";
            };
        in
        listToAttrs (map mkWpaWiredForIface (filter (i: i.wiredWpaSupplicant.enable) interfaces));

      # create configs for each of our wired interfaces
      environment.etc =
        let
          mkWpaConfigForIface =
            assert i.macAddress != null;
            i: lib.nameValuePair "wpa_supplicant/wpa_supplicant-wired-${i.name}" {
              text = "
              eapol_version=1
              ap_scan=0
              fast_reauth=1
              network={
                      ca_cert=\"${i.wiredWpaSupplicant.caCert}\"
                      client_cert=\"${i.wiredWpaSupplicant.clientCert}\"
                      private_key=\"${i.wiredWpaSupplicant.clientKey}\"
                      eap=TLS
                      eapol_flags=0
                      identity=\"${i.macAddress}\"
                      key_mgmt=IEEE8021X
                      phase1=\"allow_canned_success=1\"
              }
              ";
            };
        in
        listToAttrs (map mkWpaWiredForIface (filter (i: i.wiredWpaSupplicant.enable) interfaces));
    };
}
