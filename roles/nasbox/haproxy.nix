{
  config,
  lib,
  ...
}: {
  options.haproxy = with lib; {
    localForwards = let
      forward = {
        options = {
          localPort = mkOption {
            type = types.port;
          };
          addrs = mkOption {
            type = types.listOf types.singleLineStr;
          };
          addedReqHeaders = mkOption {
            type = types.listOf types.singleLineStr;
            default = [];
          };
          allowlistFrom = mkOption {
            type = types.nullOr types.singleLineStr;
            default = null;
          };
        };
      };
    in
      mkOption {
        type = types.attrsOf (types.submodule forward);
      };
  };

  config = let
    mkHaproxyBackend = name: port: ''
      backend ${name}
        option forwardfor
        server ${name}_server1 [::1]:${toString port}
    '';
    mkHaproxyFrontend = {
      name,
      ip,
      hdrs,
      allowlist,
      backend,
    }: let
      reqHdrs =
        builtins.concatStringsSep "\n"
        (map (h: " http-request set-header ${h}") hdrs);
      allowlistStanza = lib.optionalString (allowlist != null)
        "http-request deny if !{ src ${allowlist} }";
    in ''
      frontend ${name}
        bind [${ip}]:80
        option forwardfor except 127.0.0.1
        ${allowlistStanza}
        default_backend ${backend}
      ${reqHdrs}
    '';

    mkHaproxySection = fwdName: fwd: let
      frontends = map mkHaproxyFrontend (lib.imap1 (i: v: {
          name = "${fwdName}${toString i}";
          ip = v;
          allowlist = fwd.allowlistFrom;
          hdrs = fwd.addedReqHeaders;
          backend = fwdName;
        })
        fwd.addrs);
    in ''
      ${mkHaproxyBackend fwdName fwd.localPort}
      ${builtins.concatStringsSep "\n" frontends}
    '';

    allHaproxySections = builtins.concatStringsSep "\n" (lib.mapAttrsToList mkHaproxySection config.haproxy.localForwards);
  in {
    services.haproxy = {
      enable = true;
      config = ''
        global
          maxconn 4096
          user haproxy
          group haproxy
          log /dev/log local1 debug
          tune.ssl.default-dh-param 2048

        defaults
          log global
          mode http
          compression algo gzip
          option httplog
          option dontlognull
          retries 3
          option redispatch
          option http-server-close
          option forwardfor
          maxconn 2000
          timeout connect 5s
          timeout client 15m
          timeout server 15m
        ${allHaproxySections}
      '';
    };
  };
}
