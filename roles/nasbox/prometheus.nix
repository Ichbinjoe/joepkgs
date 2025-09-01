{
  config,
  lib,
  ...
}: {
  dn42Expose.prometheus = {
    port = config.services.prometheus.port;
    addr = "fde7:76fd:7444:eeee::104";
    allowlist = "fde7:76fd:7444::/48";
  };

  services.prometheus = let
    monitoringAddrs = [
      "nyc01.joe.dn42"
      "nyc02.joe.dn42"
      "sea01.joe.dn42"
      "sjc01.joe.dn42"
      "chi01.joe.dn42"
      "tyo01.joe.dn42"
      "ire01.joe.dn42"
      "mbi01.joe.dn42"
      "joebox.joe.dn42"
    ];
    nodeBirdBlackbox = [
      9100
      9101
      9102
    ];

    staticTargets = lib.mapCartesianProduct ({
      a,
      b,
    }: "[${a}]:${toString b}") {
      a = monitoringAddrs;
      b = nodeBirdBlackbox;
    };
  in {
    enable = true;
    listenAddress = "[::1]";
    stateDir = "../../zpool/monitoring/prometheus";
    retentionTime = "1y";
    webExternalUrl = "http://prometheus.joe.dn42/";
    scrapeConfigs = [
      {
        job_name = "dn42_vms";
        scrape_interval = "15s";
        static_configs = [
          {
            targets = staticTargets;
          }
        ];
      }
    ];
  };

  systemd.services.prometheus.serviceConfig.WorkingDirectory = lib.mkForce "/zpool/monitoring/prometheus";
}
