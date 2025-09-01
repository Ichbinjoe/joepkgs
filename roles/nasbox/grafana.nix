{...}: {
  userDBs = ["grafana"];
  dn42Expose.grafana = {
    port = 3000;
    addr = "fde7:76fd:7444:eeee::101";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "::1";
        http_port = 3000;
        domain = "grafana.joe.dn42";
        root_url = "http://grafana.joe.dn42/";
        serve_from_sub_path = true;
      };
      database = {
        type = "postgres";
        host = "/run/postgresql";
        user = "grafana";
      };
    };
  };
}
