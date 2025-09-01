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
      backend,
    }: ''
      frontend ${name}
        bind [${ip}]:80
        option forwardfor except 127.0.0.1
        default_backend ${backend}
    '';

    mkHaproxySection = fwdName: fwd: let
      frontends = map mkHaproxyFrontend (lib.imap1 (i: v: {
          name = "${fwdName}${toString i}";
          ip = v;
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
