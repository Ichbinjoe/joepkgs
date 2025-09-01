{
  config,
  lib,
  ...
}: {
  options = with lib; {
    dn42Expose = let
      exposure = {
        options = {
          port = mkOption {
            type = types.port;
          };

          addr = mkOption {
            type = types.singleLineStr;
          };

          reqHeaders = mkOption {
            type = types.listOf types.singleLineStr;
            default = [];
          };

          allowlist = mkOption {
            type = types.nullOr types.singleLineStr;
            default = null;
          };
        };
      };
    in
      mkOption {
        type = types.attrsOf (types.submodule exposure);
      };
  };

  config = {
    # make ipv6 addrs for each of these addresses
    dn42.addrs = map (e: "${e.addr}/128") (lib.attrValues config.dn42Expose);

    # define a haproxy forwarding
    haproxy.localForwards =
      lib.mapAttrs (_: v: {
        localPort = v.port;
        addedReqHeaders = v.reqHeaders;
        allowlistFrom = v.allowlist;
        addrs = [v.addr];
      })
      config.dn42Expose;
  };
}
