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
        addrs = [v.addr];
      })
      config.dn42Expose;
  };
}
