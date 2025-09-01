{
  config,
  lib,
  ...
}: {
  imports = [
    ./roa.nix
  ];

  options.dn42Bird = with lib; {
    enable = mkEnableOption "dn42 Bird";
    selfNetworks4 = mkOption {
      type = types.commas;
      default = "";
    };
    selfNetworks6 = mkOption {
      type = types.commas;
      default = "";
    };
    valid4 = mkOption {
      type = types.commas;
      default = "";
    };
    valid6 = mkOption {
      type = types.commas;
      default = "";
    };
    validBh4 = mkOption {
      type = types.commas;
      default = "";
    };
    validBh6 = mkOption {
      type = types.commas;
      default = "";
    };

    regionCode = mkOption {
      type = types.nullOr (types.ints.between 41 70);
      default = null;
    };

    countryCode = mkOption {
      type = types.nullOr (types.ints.between 1000 1999);
      default = null;
    };

    routerId = mkOption {
      type = types.singleLineStr;
    };

    localAs = mkOption {
      type = types.ints.u32;
    };

    localUla = mkOption {
      type = types.singleLineStr;
    };

    local4 = mkOption {
      type = types.singleLineStr;
    };

    nodePrefix = mkOption {
      type = types.singleLineStr;
    };

    ibgpHops = mkOption {
      type = types.ints.u8;
      default = 255;
    };

    babelInterfaces = mkOption {
      type = types.listOf types.singleLineStr;
      default = [];
    };

    advertisements = let
      advertisement = {
        options = {
          advertise = mkOption {
            type = types.listOf types.singleLineStr;
            default = [];
          };

          blackhole = mkOption {
            type = types.listOf types.singleLineStr;
            default = [];
          };

          protocol = mkOption {
            type = types.strMatching "(ipv4|ipv6)";
          };
        };
      };
    in
      mkOption {
        type = types.attrsOf (types.submodule advertisement);
        default = {};
      };

    ibgps = let
      ibgp = {
        options = {
          peerId = mkOption {
            type = types.int;
          };
        };
      };
    in
      mkOption {
        type = types.attrsOf (types.submodule ibgp);
        default = {};
      };

    ebgps = let
      ebgp = {
        template = mkOption {
          type = types.strMatching "(v4|v6|mp|enh)";
        };

        asNumber = mkOption {
          type = types.ints.u32;
        };

        neighborAddr = mkOption {
          type = types.singleLineStr;
        };

        interface = mkOption {
          type = types.singleLineStr;
        };
      };
    in
      mkOption {
        type = types.attrsOf (types.submodule ebgp);
        default = {};
      };
  };

  config = let
    cfg = config.dn42Bird;
    functions = let
      netFn = name: nets: ''
        function ${name}() -> bool {
          return net ~ [${nets}];
        };
      '';

      validCodes = builtins.filter (c: c != null) [cfg.regionCode cfg.countryCode];
      tagRegion =
        if validCodes != []
        then let
          code = c: "bgp_community.add((64511, ${toString c}));";
          codes = builtins.concatStringsSep "\n" (map code validCodes);
        in ''
          if source ~ [RTS_STATIC, RTS_BABEL] then {
            ${codes}
          }
        ''
        else "";
    in ''
      function blackhole_route() {
        dest = RTD_BLACKHOLE;
      }

      function should_blackhole() -> bool {
        return (65535, 666) ~ bgp_community;
      }

      function blackhole_route_if_community() -> bool {
        if should_blackhole() then {
          blackhole_route();
          return true;
        } else return false;
      }

      function add_blackhole_community() {
        bgp_community.add((65535, 666));
      }

      function blackhole_community_if_locally_blackholed() {
        if dest = RTD_BLACKHOLE then {
          add_blackhole_community();
        }
      }

      # We only use WG
      function update_crypto() {
        if (64511, 31) !~ bgp_community &&
          (64511, 32) !~ bgp_community &&
          (64511, 33) !~ bgp_community then {
            # We are using WG
          bgp_community.add((64511, 34));
        }
      }

      ${netFn "dn42_is_self4" cfg.selfNetworks4}
      ${netFn "dn42_is_self6" cfg.selfNetworks6}
      ${netFn "dn42_valid4" cfg.valid4}
      ${netFn "dn42_valid6" cfg.valid6}
      ${netFn "dn42_valid_bh4" cfg.validBh4}
      ${netFn "dn42_valid_bh6" cfg.validBh6}

      function update_communities() {
        update_crypto();

        ${tagRegion}
      }
    '';

    routerId = ''
      router id ${cfg.routerId};
    '';

    roaFns = let
      roaV = v: ''
                roa${v} table dn42_roa_v${v};

                protocol static dn42_roa_v${v}_static {
                  roa${v} { table dn42_roa_v${v}; };
                  include "/var/lib/bird/roa_dn42_v${v}.conf";
                }

                function invalid_roa${v}() -> bool {
        if (roa_check(dn42_roa_v${v}, net, bgp_path.last) != ROA_VALID) then {
                    print "[dn42] ROA check failed for ", net, " ASN ", bgp_path.last;
                    reject;
                  } else return false;
                }
      '';
    in ''
      ${roaV "4"}
      ${roaV "6"}
    '';

    filters = ''
      filter dn42_ebgp_import4 {
        if !dn42_valid_bh4() then reject;
        else if dn42_is_self4() then reject;
        else if invalid_roa4() then reject;
        else if blackhole_route_if_community() then accept;
        else if !dn42_valid4() then reject;
        else accept;
      }

      filter dn42_ebgp_import6 {
        if !dn42_valid_bh6() then reject;
        else if dn42_is_self6() then reject;
        else if invalid_roa6() then reject;
        else if blackhole_route_if_community() then accept;
        else if !dn42_valid6() then reject;
        else accept;
      }

      filter dn42_ebgp_export4 {
        if !dn42_valid_bh4() then reject;
        blackhole_community_if_locally_blackholed();
        if !should_blackhole() && !dn42_valid4() then reject;

        if (source ~ [RTS_STATIC, RTS_BABEL] && dn42_is_self4()) || source = RTS_BGP then {
          update_communities();
          accept;
        }
        else reject;
      }

      filter dn42_ebgp_export6 {
        if !dn42_valid_bh6() then reject;
        blackhole_community_if_locally_blackholed();
        if !should_blackhole() && !dn42_valid6() then reject;

        if (source ~ [RTS_STATIC, RTS_BABEL] && dn42_is_self6()) || source = RTS_BGP then {
          update_communities();
          accept;
        }
        else reject;
      }

      filter ibgp_import {
        if blackhole_route_if_community() then accept;
        else accept;
      }

      filter ibgp_export4 {
        if !dn42_valid_bh4() then reject;
        blackhole_community_if_locally_blackholed();
        if !should_blackhole() && !dn42_valid4() then reject;

        update_communities();
        if source = RTS_STATIC && dn42_is_self4() then accept;
        else if source = RTS_BGP then accept;
        else reject;
      }

      filter ibgp_export6 {
        if !dn42_valid_bh6() then reject;
        blackhole_community_if_locally_blackholed();
        if !should_blackhole() && !dn42_valid6() then reject;

        update_communities();
        if source = RTS_STATIC && dn42_is_self6() then accept;
        else if source = RTS_BGP then accept;
        else reject;
      }

      filter babel_gossip4 {
        if dn42_is_self4() && source != RTS_BGP then accept;
        else reject;
      }

      filter babel_gossip6 {
        if dn42_is_self6() && source != RTS_BGP then accept;
        else reject;
      }

      template bgp dn42_bgp {
        local as ${toString cfg.localAs};
        path metric 1;
        direct;
        enforce first as on;
        enable extended messages on;
        advertise hostname on;
      }

      template bgp dn42_bgp_v4 from dn42_bgp {
        ipv4 {
          import filter dn42_ebgp_import4;
          export filter dn42_ebgp_export4;

          import limit 10000 action block;
        };
      }

      template bgp dn42_bgp_v6 from dn42_bgp {
        ipv6 {
          import filter dn42_ebgp_import6;
          export filter dn42_ebgp_export6;

          import limit 10000 action block;
        };
      }

      template bgp dn42_bgp_mp from dn42_bgp {
        ipv4 {
          import filter dn42_ebgp_import4;
          export filter dn42_ebgp_export4;

          import limit 10000 action block;
        };

        ipv6 {
          import filter dn42_ebgp_import6;
          export filter dn42_ebgp_export6;

          import limit 10000 action block;
        };
      }

      template bgp dn42_bgp_enh from dn42_bgp_mp {
        ipv4 {
          extended next hop on;
        };

        ipv6 {
          extended next hop on;
        };
      }

      template bgp dn42_bgp_rbit from dn42_bgp_enh {
        ipv4 {
          import none;
        };

        ipv6 {
          import none;
        };
      }

      template bgp ibj_ibgp {
        local as ${toString cfg.localAs};
        source address ${cfg.localUla};

        multihop ${toString cfg.ibgpHops};

        ipv4 {
          next hop self ebgp;
          extended next hop on;

          import filter ibgp_import;
          export filter ibgp_export4;
        };

        ipv6 {
          next hop self ebgp;
          extended next hop on;

          import filter ibgp_import;
          export filter ibgp_export6;
        };
      }
    '';

    babel =
      if cfg.babelInterfaces != []
      then let
        interfaceDef = i: ''
          interface "${i}" {
            type tunnel;
          };
        '';

        interfaces = builtins.concatStringsSep "\n" (map interfaceDef cfg.babelInterfaces);
      in ''
        protocol babel joenet_babel {
          ${interfaces}

          ipv4 {
            import where dn42_is_self4() && source != RTS_BGP;
            export where dn42_is_self4() && source != RTS_BGP;
          };

          ipv6 {
            import where dn42_is_self6() && source != RTS_BGP;
            export where dn42_is_self6() && source != RTS_BGP;
          };
        };
      ''
      else "";

    deviceKernel = ''
      protocol device {
        scan time 10;
      };

      protocol kernel {
        scan time 20;

        ipv4 {
          import none;
          export filter {
            if source = RTS_STATIC then reject;
            krt_prefsrc = ${cfg.local4};

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
            krt_prefsrc = ${cfg.localUla};

            accept;
          };
        };
      };
    '';

    staticAds = let
      advertisementEntry = adv: ''route ${adv} via "lo";'';
      advertisements = p: builtins.concatStringsSep "\n" (map advertisementEntry p.advertise);
      blackholeEntry = adv: ''route ${adv} unreachable;'';
      blackholes = p: builtins.concatStringsSep "\n" (map blackholeEntry p.advertise);
      protocolEntry = name: p: ''
        protocol static ${name} {
          check link;
          ${advertisements p}
          ${blackholes p}

          ${p.protocol} {
            import all;
            export none;
          };
        }
      '';
    in
      builtins.concatStringsSep "\n" (lib.mapAttrsToList protocolEntry cfg.advertisements);

    ibgps = let
      ibgp = name: i: ''
        protocol bgp ibgp_${name} from ibj_ibgp {
          neighbor ${cfg.nodePrefix}::${toString i.peerId} as ${toString cfg.localAs} internal;
        };
      '';
    in
      builtins.concatStringsSep "\n" (lib.mapAttrsToList ibgp cfg.ibgps);

    ebgps = let
      ebgp = name: e: ''
        protocol bgp dn42_${name} from dn42_bgp_${e.template} {
          neighbor ${e.neighborAddr} as ${toString e.asNumber} external;
          interface "${e.interface}";
        }
      '';
    in
      builtins.concatStringsSep "\n" (lib.mapAttrsToList ebgp cfg.ebgps);
  in
    lib.mkIf cfg.enable {
      services.bird = {
        enable = true;
        checkConfig = false;
        config = ''
          ${functions}
          ${routerId}
          ${roaFns}
          ${filters}
          ${staticAds}
          ${deviceKernel}
          ${babel}
          ${ibgps}
          ${ebgps}
        '';
      };
    };
}
