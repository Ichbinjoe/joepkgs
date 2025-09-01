{lib, ...}: {
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
    listenAddress = "127.0.0.1";
    stateDir = "../../zpool/monitoring/prometheus";
    retentionTime = "1y";
    # webExternalUrl = "http://${dn42Ip}/";
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
