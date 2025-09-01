{
  config,
  pkgs,
  lib,
  ...
}: {
  options = with lib; {
    userDBs = mkOption {
      type = types.listOf types.str;
      default = [];
    };
  };

  config = {
    services.postgresql = {
      enable = true;
      dataDir = "/zflash/postgresql/15";
      ensureDatabases = config.userDBs;
      ensureUsers =
        map (db: {
          name = db;
          ensureDBOwnership = true;
        })
        config.userDBs;
    };
  };
}
