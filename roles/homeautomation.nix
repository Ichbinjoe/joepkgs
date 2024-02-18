{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
  ];

  # add a separate iot net
  systemd.network.netdevs."01-iot" = {
    netdevConfig = {
      Kind = "vlan";
      Name = "iot";
    };
    vlanConfig = {
      Id = 2;
    };
  };

  systemd.network.networks = {
    "99-default" = {
      vlan = ["iot"];
    };

    "01-iot" = {
      matchConfig.Name = "iot";
      address = ["192.168.100.2/24"];
      networkConfig = {
        IPv6AcceptRA = "no";
        DHCP = "no";
      };
    };
  };

  # basic ssh
  services.openssh.enable = true;

  # use postgres to back both Home Assistant & Grafana
  services.postgresql = {
    enable = true;

    # create two dbs - one for Grafana, one for Home Assistant
    ensureDatabases = [
      "grafana"
      "hass"
    ];

    ensureUsers = [
      {
        name = "grafana";
        ensureDBOwnership = true;
      }
      {
        name = "hass";
        ensureDBOwnership = true;
      }
    ];
  };

  # setup home assistant
  services.home-assistant = {
    enable = true;
    extraPackages = python3Packages:
      with python3Packages; [
        psycopg2

        aiodiscover
        scapy
      ];

    extraComponents = [
      "auth"
      "automation"
      "config"
      "counter"
      "device_automation"
      "energy"
      "esphome"
      "frontend"
      "hardware"
      "history"
      "homeassistant_alerts"
      "image_upload"
      "input_boolean"
      "input_button"
      "input_datetime"
      "input_number"
      "input_select"
      "input_text"
      "logbook"
      "logger"
      "map"
      "media_source"
      "nest"
      "nws"
      "octoprint"
      "person"
      "pge"
      "prometheus"
      "recorder"
      "schedule"
      "scene"
      "script"
      "stream"
      "subaru"
      "sun"
      "system_health"
      "tag"
      "timer"
      "unifi"
      "unifiprotect"
      "zone"
    ];

    config = {
      default_config = {};
      api = {};
      frontend = {};
      homeassistant = {
        country = "US";
        currency = "USD";
        temperature_unit = "F";
        time_zone = config.time.timeZone;
        unit_system = "imperial";
      };
      http = {
        server_host = "::1";
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1" "::1"];
      };
      logger = {
        default = "info";
      };
      recorder = {
        db_url = "postgresql://@/hass";
      };
    };
  };

  services.paperless = {
    enable = true;
    extraConfig = {
      PAPERLESS_FORCE_SCRIPT_NAME = "/paperless";
      PAPERLESS_STATIC_URL = "/paperless/static/";
      PAPERLESS_USE_X_FORWARD_HOST = true;
      PAPERLESS_USE_X_FORWARD_PORT = true;
    };
  };

  # use haproxy to actually deal with tls & mapping individual services
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

      frontend public
        bind :::80 v4v6
        option forwardfor except 127.0.0.1
        use_backend paperless if { path /paperless } || { path_beg /paperless/ }
        use_backend prometheus if { path /prometheus } || { path_beg /prometheus/ }
        use_backend grafana if { path /grafana } || { path_beg /grafana/ }

        default_backend homeassistant

      backend paperless
        option forwardfor

        server paperless1 127.0.0.1:${toString config.services.paperless.port}

      backend homeassistant
        option forwardfor

        server homeassistant1 [::1]:${toString config.services.home-assistant.config.http.server_port}

      backend prometheus
        option forwardfor

        server prometheus1 [::1]:${toString config.services.prometheus.port}

      backend grafana
        option forwardfor

        server grafana1 [::1]:3000
    '';
  };

  services.vsftpd = {
    enable = true;
    writeEnable = true;
    localUsers = true;
    userlistEnable = true;
    userlist = [config.services.paperless.user];
    chrootlocalUser = true;
    allowWriteableChroot = true;
  };

  users.users.${config.services.paperless.user}.password = "password";

  services.prometheus = {
    enable = true;
    listenAddress = "[::1]";
    webExternalUrl = "http://192.168.2.33/prometheus/";
    scrapeConfigs = [
      {
        job_name = "router";
        scrape_interval = "15s";
        static_configs = [
          {
            targets = ["192.168.2.1:9324" "192.168.2.1:9374" "192.168.2.1:9100" "192.168.2.1:9633" "192.168.2.1:9558" "192.168.2.1:9167"];
          }
        ];
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "[::1]";
        http_port = 3000;
        domain = "192.168.2.33";
        root_url = "http://192.168.2.33/grafana/";
        serve_from_sub_path = true;
      };
      database = {
        type = "postgres";
        host = "/run/postgresql";
        user = "grafana";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [21 80];
}
