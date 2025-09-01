{...}: {
  userDBs = ["grafana"];

  services.grafana = {
    enable = true;
    settings = {
      server = {
        # http_addr = "[::1]";
        http_addr = "127.0.0.1";
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
