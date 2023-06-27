# router-oriented configuration of interfaces - likely has some very
# me-specific setup stuff built in

{ config, lib, pkgs, ... }: with lib;
let
  mkBasicOption = type: description: mkOption { inherit type description; };
  mkSubOpt = sub: description: mkOption {
    inherit description;
    type = types.submodule sub;
    default = { };
  };
  mkOptOption = type: description: ((mkBasicOption (types.nullOr type) description) // { default = null; });
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
      useDns = mkOptOption types.bool "Whether to use DNS from the DHCPv4 advertisement";
      duid = mkSubOpt duidOpts "DUID Options";
    };
  };

  dhcpv6Opts = {
    options = {
      enable = mkEnableOption "DHCPv6 client";
      useDns = mkOptOption types.bool "Whether to use DNS from the DHCPv6 advertisement";
      duid = mkSubOpt duidOpts "DUID Options";
      prefixDelegationHint = mkOptOption types.str "Prefix delegation hint";
    };
  };

  dhcpv4ServerOpts = {
    options = {
      enable = mkEnableOption "DHCPv4 server";
      dns = (mkOptOption (types.listOf types.str) "DNS servers to advertise") // {default = [];};
    };
  };

  ipv4RouterOpts = {
    options = {
      forward = mkEnableOption "forwarding";
      masquerade = mkEnableOption "masquerading";
      dhcp = mkSubOpt dhcpv4ServerOpts "DHCPv4 server";
    };
  };

  sendRaOpts = {
    options = {
      enable = mkEnableOption "IPV6SendRA";
      dns = (mkOptOption (types.listOf types.str) "DNS servers to advertise") // {default = [];};
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
      sendRa = mkSubOpt sendRaOpts "IPv6 router adverts";
      prefixDelegation = mkSubOpt dhcpPrefixDelOpts "DHCP prefix delegation";
    };
  };

  networkOpts = {
    options = {
      blackhole = mkOption {
        type = types.bool;
        default = false;
      };
      requiredForOnline = mkOptOption types.bool "Whether this interface is required for the network to be considered online";
      mtu = mkOptOption types.ints.positive "MTU to use if not inferred";
      # TODO this is gross
      vlans = (mkBasicOption (types.lazyAttrsOf (types.submodule vlanOpts)) "VLANs") // {
        default = { };
      };
      address = (mkBasicOption (types.listOf types.str) "Addresses to attach to this interface") // { default = [ ]; };
      dns = (mkBasicOption (types.listOf types.str) "DNS addresses to attach to this interface") // { default = [ ]; };
      dhcpv4Client = mkSubOpt dhcpv4Opts "dhcpv4 client";
      dhcpv6Client = mkSubOpt dhcpv6Opts "dhcpv6 client";
      ipv4Router = mkSubOpt ipv4RouterOpts "ipv4 router";
      ipv6Router = mkSubOpt ipv6RouterOpts "ipv6 router";
    };
  };

  vlanOpts = { name, ... }: {
    options = {
      name = mkBasicOption types.str "Friendly name for this interface";
      id = mkBasicOption types.int "id to use for the vlan";
      network = mkSubOpt networkOpts "Higher-order network options";
    };

    config = {
      name = mkDefault name;
    };
  };

  interfaceOpts = { name, ... }: {
    options = {
      name = mkBasicOption types.str "Friendly name for the interface";
      match = mkSubOpt ifaceMatchOpts "Match options for the interface";
      macAddress = mkOptOption types.str "MAC address to force";
      wiredWpaSupplicant = mkSubOpt wiredWpaOpts "Wired WPA supplicant settings to use if necessary";
      network = mkSubOpt networkOpts "Higher-order network options";
    };

    config = {
      name = mkDefault name;
    };
  };

  netOpts = {
    options = {
      enable = mkEnableOption "network management";
      interfaces = mkBasicOption (types.lazyAttrsOf (types.submodule interfaceOpts)) "interfaces";
    };
  };
in
{
  imports = [ ];
  options.joeos = {
    network = mkSubOpt netOpts "Networking";
  };

  config =
    let
      network = config.joeos.network;
      interfaces = attrValues network.interfaces;

      mkNetStackOpt = ipv4: ipv6:
        if ipv4 then (if ipv6 then "yes" else "ipv4") else (if ipv6 then "ipv6" else "no");
      mkDuidDhcp = duid:
        (attrIf "DUIDType" duid.type) // (attrIf "DUIDRawData" duid.raw);
      attrIf = field: v: optionalAttrs (v != null) { "${field}" = v; };
      attrMapIf = field: v: fn: optionalAttrs (v != null) { "${field}" = (fn v); };
      flagAttrIf = field: v: (attrMapIf field v (v: if v then "yes" else "no"));
      enableAttrIf = field: v: optionalAttrs v { "${field}" = "yes"; };
      disableAttrIfNot = field: v: optionalAttrs (v == null || !v) { "${field}" = "no"; };
    in
    mkIf network.enable {
      # disable dhcpcd, as we should be using networkd instead
      networking.dhcpcd.enable = false;
      # also disable the firewall. Makes things hard
      networking.firewall.enable = false;
      # but we do want nftables around, and we will populate a ruleset later
      networking.nftables.enable = true;

      # if we think we need wpa_supplicant, we need to pull in the systemd packages so that
      # the units can be symlink'd in as intended
      systemd.packages = mkIf (any (i: i.wiredWpaSupplicant.enable) interfaces) [ pkgs.wpa_supplicant ];

      systemd.network = {
        enable = true;
        # create a link config for interface
        links = listToAttrs
          (map
            (iface: lib.nameValuePair "01-${iface.name}" {
              matchConfig =
                (attrIf "MACAddress" iface.match.macAddress) //
                (attrIf "PermanentMACAddress" iface.match.permMacAddress) //
                (attrIf "Path" iface.match.path);
              linkConfig =
                (attrIf "MACAddress" iface.macAddress) //
                (attrIf "Name" iface.name) //
                (attrMapIf "MTUBytes" iface.network.mtu toString);
            })
            interfaces);

        # we only need to make netdevs for vlans - of course, it is a recursive
        # option, so we need to recursively pull out all vlan configs independently.
        netdevs =
          let
            mkNetdevFromVlan = vlan:
              lib.nameValuePair "01-${vlan.name}" {
                netdevConfig =
                  { Kind = "vlan"; } //
                  attrIf "Name" vlan.name //
                  attrMapIf "MTUBytes" vlan.network.mtu toString;

                vlanConfig = { Id = vlan.id; };
              };
            mkNetdevsFromVlan =
              vlan: [ (mkNetdevFromVlan vlan) ] ++ (mkAllNetdevsForNetwork vlan.network);
            mkAllNetdevsForNetwork =
              n: lib.concatMap mkNetdevsFromVlan (attrValues n.vlans);
            baseNetworks = map (i: i.network) interfaces;
          in
          listToAttrs (lib.concatMap mkAllNetdevsForNetwork baseNetworks);

        networks =
          let
            mkSysdNetFromNet = name: net:
              lib.nameValuePair "01-${name}"
                (
                  {
                    inherit name;
                    DHCP = mkNetStackOpt net.dhcpv4Client.enable net.dhcpv6Client.enable;
                    linkConfig = flagAttrIf "RequiredForOnline" net.requiredForOnline;
                    networkConfig = {
                      # TODO: we probably don't want to give this control to
                      # systemd at all. 
                      # IPForward = mkNetStackOpt net.ipv4Router.forward net.ipv6Router.forward;
                      # IPMasquerade = mkNetStackOpt net.ipv4Router.masquerade net.ipv6Router.masquerade;
                      DNS = net.dns;
                    } //
                    (enableAttrIf "DHCPServer" net.ipv4Router.dhcp.enable) //
                    (enableAttrIf "IPv6SendRA" net.ipv6Router.sendRa.enable) //
                    (enableAttrIf "DHCPPrefixDelegation" net.ipv6Router.prefixDelegation.enable) //
                    (enableAttrIf "IPv6AcceptRA" net.dhcpv6Client.enable) //
                    (optionalAttrs net.blackhole {
                      LinkLocalAddressing = "no";
                      LLDP = false;
                      EmitLLDP = false;
                      IPv6AcceptRA = false;
                      IPv6SendRA = false;
                    });
                  } // (optionalAttrs (net.address != [ ]) {
                    address = net.address;
                  }) // (optionalAttrs (net.vlans != { }) {
                    vlan = map (v: v.name) (attrValues net.vlans);
                  }) // (optionalAttrs net.dhcpv4Client.enable {
                    dhcpV4Config =
                      (disableAttrIfNot "SendHostname" net.dhcpv4Client.sendHostname) //
                      (disableAttrIfNot "UseDNS" net.dhcpv4Client.useDns) //
                      (mkDuidDhcp net.dhcpv4Client.duid);
                  }) // (optionalAttrs net.dhcpv6Client.enable {
                    dhcpV6Config =
                      { "WithoutRA" = "solicit"; } //
                      disableAttrIfNot "UseDNS" net.dhcpv6Client.useDns //
                      attrIf "PrefixDelegationHint" net.dhcpv6Client.prefixDelegationHint //
                      (mkDuidDhcp net.dhcpv6Client.duid);
                  }) // (optionalAttrs net.ipv4Router.dhcp.enable {
                    dhcpServerConfig = {
                      DNS = net.ipv4Router.dhcp.dns;
                    } //
                    (attrMapIf "SendOption" net.mtu (m: "26:uint16:${toString m}"));
                  }) // (optionalAttrs net.ipv6Router.sendRa.enable {
                    ipv6SendRAConfig = {
                      DNS = net.ipv6Router.sendRa.dns;
                    };
                  }) // (optionalAttrs net.ipv6Router.prefixDelegation.enable {
                    dhcpPrefixDelegationConfig =
                      attrMapIf "SubnetId" net.ipv6Router.prefixDelegation.subnetId toString;
                  })
                );
            # works for both interfaces & vlans!
            mkSysdNetFromObj = o: mkSysdNetFromNet o.name o.network;

            mkAllNetworks = o: [ (mkSysdNetFromObj o) ] ++ (lib.concatMap mkAllNetworks (attrValues o.network.vlans));
          in
          listToAttrs (lib.concatMap mkAllNetworks interfaces);
      };

      # create systemd overrides for each wpa_supplicant-wired needed.
      systemd.services =
        let
          mkWpaWiredForIface =
            i: lib.nameValuePair "wpa_supplicant-wired@${i.name}" {
              overrideStrategy = "asDropin";
              enable = true;
              wantedBy = [ "multi-user.target" ];
            };
        in
        listToAttrs (map mkWpaWiredForIface (filter (i: i.wiredWpaSupplicant.enable) interfaces));

      # create configs for each of our wired interfaces
      environment.etc =
        let
          mkWpaConfigForIface =
            i:
            lib.nameValuePair "wpa_supplicant/wpa_supplicant-wired-${i.name}.conf" {
              text = ''
                openssl_ciphers=DEFAULT@SECLEVEL=0
                eapol_version=1
                ap_scan=0
                fast_reauth=1
                network={
                    ca_cert="${i.wiredWpaSupplicant.caCert}"
                    client_cert="${i.wiredWpaSupplicant.clientCert}"
                    private_key="${i.wiredWpaSupplicant.clientKey}"
                    eap=TLS
                    eapol_flags=0
                    identity="${i.macAddress}"
                    key_mgmt=IEEE8021X
                    phase1="allow_canned_success=1"
                }
              '';
            };
        in
        listToAttrs (map mkWpaConfigForIface (filter (i: i.wiredWpaSupplicant.enable) interfaces));
    };
}
