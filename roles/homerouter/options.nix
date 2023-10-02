{
  config,
  lib,
  ...
}:
with lib; {
  options.homerouter = {
    interface = {
      external = mkOption {
        type = types.str;
      };

      internal = mkOption {
        type = types.str;
      };

      untrustedap = mkOption {
        type = types.str;
      };
    };

    secrets = {
      duid = mkOption {
        type = types.str;
      };

      caPem = mkOption {
        type = types.path;
      };

      clientPem = mkOption {
        type = types.path;
      };

      keyPem = mkOption {
        type = types.path;
      };

      mac = mkOption {
        type = types.str;
      };
    };
  };
}
