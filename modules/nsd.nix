{
  config,
  nixpkgs,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.nsdjoe;
  username = "nsd";
  stateDir = "/var/lib/nsd";
  nsdPkg = pkgs.nsd;
in {
  options.services.nsdjoe = {
    enable = mkEnableOption "nsd joe edition";
    config = mkOption {
      type = types.lines;
      default = "";
    };
  };

  config = let
  in
    mkIf cfg.enable {
      environment = {
        systemPackages = [nsdPkg];
        etc."nsd/nsd.conf".text = cfg.config;
      };

      users.groups.${username}.gid = config.ids.gids.nsd;

      users.users.${username} = {
        description = "NSD service user";
        home = stateDir;
        createHome = true;
        uid = config.ids.uids.nsd;
        group = username;
      };

      systemd.services.nsd = {
        description = "NSD authoritative only domain name service";

        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        startLimitBurst = 4;
        startLimitIntervalSec = 5 * 60; # 5 mins
        serviceConfig = {
          ExecStart = "${nsdPkg}/sbin/nsd -d -c /etc/nsd/nsd.conf";
          Restart = "always";
          RestartSec = "4s";
        };
      };
    };
}
