{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  services.gpsd = {
    enable = true;
    devices = ["/dev/gpsserial"];
    nowait = true;
  };

  systemd.services.gpsd = {
    requires = ["dev-gpsserial.device"];
  };

  environment.systemPackages = [pkgs.gpsd];

  services.chrony = {
    enable = true;
    # don't actually trust servers
    servers = mkForce [];

    extraConfig = ''
      refclock SHM 0 refid GPS1
      allow all
      leapsectz right/UTC
      clientloglimit 100000000
    '';
  };
}
