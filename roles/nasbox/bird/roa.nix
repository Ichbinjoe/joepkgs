{
  config,
  lib,
  pkgs,
  ...
}: {
  options.dn42Bird = with lib; {
    roaEnable = mkEnableOption "roa checking";
  };

  config = lib.mkIf config.dn42Bird.roaEnable {
    systemd.services.dn42-roa-update = let
      curlV = v: "${pkgs.curl}/bin/curl https://dn42.burble.com/roa/dn42_roa_bird2_${v}.conf -o /var/lib/bird/roa_dn42_v${v}.conf";
    in {
      after = ["network.target"];
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "15";
        TimeoutSec = "15";
        ExecStart = [
          (curlV "4")
          (curlV "6")
        ];
      };
    };

    systemd.timers.dn42-roa-update = {
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      timerConfig = {
        OnBootSec = "0";
        OnUnitActiveSec = "15m";
      };
    };
  };
}
