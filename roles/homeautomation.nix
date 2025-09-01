{
  config,
  pkgs,
  lib,
  ...
}: let
  dn42Ip = "fde7:76fd:7444:ffbb::1";
  dn42Net = "fde7:76fd:7444:ffbb::/64";
  dn42DnsPrimary2 = "fde7:76fd:7444:ffbb::3";
  dn42BirdLg = "fde7:76fd:7444:ffbb::3";
  dn42Grafana = "fde7:76fd:7444:ffbb::4";
  dn42Prometheus = "fde7:76fd:7444:ffbb::5";
  dn42Paperless = "fde7:76fd:7444:ffbb::6";
  dn42GitWeb = "fde7:76fd:7444:ffbb::7";
  dn42Netbox = "fde7:76fd:7444:ffbb::100";
  dn42Via = "fde7:76fd:7444:ffbb::ffff";
in {
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
    "01-eno1" = {
      matchConfig.Name = "eno1";
      vlan = ["iot" "joenet"];
      networkConfig = {
        DHCP = "yes";
      };
      address = [
        "${dn42Ip}/64"
        "${dn42DnsPrimary2}/64"
        "${dn42BirdLg}/64"
        "${dn42Grafana}/64"
        "${dn42Prometheus}/64"
        "${dn42Paperless}/64"
        "${dn42GitWeb}/64"
        "${dn42Netbox}/64"
      ];
      routes = [
        {
          routeConfig = {
            Destination = "fd00::/8";
            Gateway = "${dn42Via}";
            PreferredSource = "${dn42Ip}";
          };
        }
      ];
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

    ensureDatabases = [
      "grafana"
      "hass"
      "pdns"
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
      {
        name = "pdns";
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
        unit_system = "us_customary";
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
    settings = {
      PAPERLESS_USE_X_FORWARD_HOST = true;
      PAPERLESS_USE_X_FORWARD_PORT = true;
      PAPERLESS_OCR_ROTATE_PAGES_THRESHOLD = "6";
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

      frontend lg
        bind [${dn42BirdLg}]:80
        option forwardfor except 127.0.0.1
        default_backend lg

      backend lg
        option forwardfor
        server lg1 [::1]:8080

      frontend grafana
        bind [${dn42Grafana}]:80
        option forwardfor except 127.0.0.1
        default_backend grafana

      backend grafana
        option forwardfor

        server grafana1 [::1]:3000

      frontend prometheus
        bind [${dn42Prometheus}]:80
        option forwardfor except 127.0.0.1
        default_backend prometheus

      backend prometheus
        option forwardfor

        server prometheus1 [::1]:${toString config.services.prometheus.port}

      frontend paperless
        bind [${dn42Paperless}]:80
        option forwardfor except 127.0.0.1
        default_backend paperless

      backend paperless
        option forwardfor

        server paperless1 127.0.0.1:${toString config.services.paperless.port}

      frontend public
        bind 192.168.2.33:80
        bind [${dn42Ip}]:80
        option forwardfor except 127.0.0.1

        default_backend homeassistant

      backend homeassistant
        option forwardfor

        server homeassistant1 [::1]:${toString config.services.home-assistant.config.http.server_port}

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
  users.users.netbox.extraGroups = ["nsd"];

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
    webExternalUrl = "http://${dn42Ip}/";
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

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "[::1]";
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
  #
  services.nginx = {
    enable = true;
    user = "netbox";
    virtualHosts.netbox = {
      listen = [
        {
          addr = "[${dn42Netbox}]";
          port = 80;
        }
      ];
      locations."/static/" = {
        alias = "/var/lib/netbox/static/";
      };
      locations."/" = {
        proxyPass = "http://${config.services.netbox.listenAddress}:${toString config.services.netbox.port}";
        recommendedProxySettings = true;
      };
    };

    virtualHosts.gitweb = {
      listen = [
        {
          addr = "[${dn42GitWeb}]";
          port = 80;
        }
      ];
    };

    gitweb = {
      enable = true;
      location = "";
      virtualHost = "gitweb";
      user = "netbox";
      group = "netbox";
    };
  };

  systemd.services.nginx.serviceConfig.AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];

  services.netbox = {
    enable = true;
    secretKeyFile = "/var/lib/netbox/secretKey";
    settings = {
      ALLOWED_HOSTS = ["*"];
      BASE_PATH = "";
      PLUGINS = [
        "netbox_bgp"
        "netbox_dns"
        "netbox_inventory"
      ];
      PLUGINS_CONFIG = {
        "netbox_dns" = {
          tolerate_underscores_in_labels = true;
          tolerate_leading_underscore_types = ["CNAME"];
        };
      };
    };
    plugins = python3Packages:
      with python3Packages; let
        netbox-bgp = buildPythonPackage rec {
          pname = "netbox-bgp";
          version = "0.12.1";
          format = "wheel";
          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/ca/ec/60104fedf87f8587145f3ec5578f0577867fb261d1d6f0abf5ee335631ca/netbox_bgp-0.12.1-py3-none-any.whl";
            sha256 = "16b98gn9x1iydpm63gc8l64pj443bmgmrif6dxp1s5yw2sf95ghd";
          };
        };
        netbox-dns = buildPythonPackage rec {
          pname = "netbox-dns";
          version = "0.22.4";
          format = "wheel";
          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/8d/06/0247b46e1e9a671167bc1335f55b051a1be6c6368e0cafcd30527322591b/netbox_plugin_dns-0.22.4-py3-none-any.whl";
            sha256 = "SMHNzsiMbZR8tRqmEduxWfiGW/BYNHmpNKGOczWPsDg=";
          };
        };
        netbox-inventory = buildPythonPackage rec {
          pname = "netbox-inventory";
          version = "1.5.2";
          format = "wheel";
          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/8a/bf/5945c7b0a26c11fef35e00c2b3efac494704a432c8201925c6d2d4312660/netbox_inventory-1.5.2-py3-none-any.whl";
            sha256 = "hRzLlKPvMc4QLvjc1FgxLm+YjoO7tKHKR1GlVl3tBNc=";
          };
        };
      in [
        dnspython
        netbox-bgp
        netbox-dns
        netbox-inventory
      ];
  };

  # On this smaller host, it takes more than 90 seconds to start the service. That's fine.
  systemd.services.netbox.serviceConfig.TimeoutStartSec = 3600;

  services.syncthing = {
    enable = true;
    guiAddress = "[::]:8384";
  };

  networking.firewall.allowedTCPPorts = [21 53 80 5001 8080 8952 22000];
  networking.firewall.allowedUDPPorts = [6696 53 22000 21027];

  services.znc = {
    enable = true;
    mutable = false; # Overwrite configuration set by ZNC from the web and chat interfaces.
    useLegacyConfig = false; # Turn off services.znc.confOptions and their defaults.
    openFirewall = true; # ZNC uses TCP port 5000 by default.
    config = {
      LoadModule = ["adminlog" "webadmin"];
      User.joe = {
        Admin = true;
        Pass.password = {
          Method = "sha256";
          Hash = "8fefbaab1771fc2a6267332f6834c376c8c206ba8b5fff88b1c1eadb19e7a24f";
          Salt = "XcDtD4q(JY3/m!lQxfeX";
        };
      };
    };
  };

  services.nsdjoe = let
    upstreamIds = [
      234
      237
      232
      231
      240
      233
      236
    ];
    upstreamIps = map (id: "fde7:76fd:7444:aaaa::${toString id}") upstreamIds;
    provideXfrs = lib.concatStringsSep "\n" (map (ip: "  provide-xfr: ${ip} NOKEY") upstreamIps);
    notifys = lib.concatStringsSep "\n" (map (ip: "  notify: ${ip} NOKEY") upstreamIps);
  in {
    enable = true;
    config =
      ''
        server:
          server-count: 1
          username: nsd
          ip-address: ${dn42DnsPrimary2}
          zonelistfile: /var/lib/nsd/zone.list
          pidfile: /var/run/nsd.pid
          xfrdfile: /var/lib/nsd/xfrd.state


        remote-control:
          control-enable: yes
          server-key-file: /var/lib/nsd/nsd_server.key
          server-cert-file: /var/lib/nsd/nsd_server.pem
          control-key-file: /var/lib/nsd/nsd_control.key
          control-cert-file: /var/lib/nsd/nsd_control.pem

        zone:
          name: "catalog.ibj"
          catalog: producer

          store-ixfr: yes
          allow-query: 0.0.0.0/0 BLOCKED
          allow-query: ::/0 BLOCKED
          outgoing-interface: ${dn42DnsPrimary2}
      ''
      + provideXfrs
      + notifys
      + ''

        pattern:
          name: standard
          zonefile: /var/lib/nsd/zones/%s.signed
          outgoing-interface: ${dn42DnsPrimary2}
          catalog-producer-zone: "catalog.ibj"
      ''
      + provideXfrs
      + notifys;
  };

  environment.systemPackages = with pkgs; [
    ldns.examples
    pdns
    whois
    paperless-ngx
  ];

  services.bird-lg.frontend = {
    enable = true;
    listenAddress = "[::1]:8080";
    netSpecificMode = "dn42";
    dnsInterface = "asn.dn42";
    domain = "joe.dn42";
    navbar.brand = "Joenet";
    servers = [
      "sjc01"
      "sea01"
      "chi01"
      "tyo01"
      "nyc01"
      "nyc02"
      "ire01"
      "mbi01"
      "joebox"
    ];
    nameFilter = "^(device|kernel|static|joenet_babel).*";
    proxyPort = 9999;
    whois = "fd42:d42:d42:43::1";
  };
}
