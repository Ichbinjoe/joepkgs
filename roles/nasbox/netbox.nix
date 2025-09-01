{...}: {
  # services.nginx = {
  #   enable = true;
  #   user = "netbox";
  #   virtualHosts.netbox = {
  #     listen = [
  #       {
  #         addr = "[${dn42Netbox}]";
  #         port = 80;
  #       }
  #     ];
  #     locations."/static/" = {
  #       alias = "/var/lib/netbox/static/";
  #     };
  #     locations."/" = {
  #       proxyPass = "http://${config.services.netbox.listenAddress}:${toString config.services.netbox.port}";
  #       recommendedProxySettings = true;
  #     };
  #   };
  # };
  #
  # systemd.services.nginx.serviceConfig.AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];

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
          version = "0.15.0";
          format = "wheel";
          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/e4/a1/58c6eecf0decb83bd45d018c8fd15ad8d519c6a3bc68bfb10002ecab05e9/netbox_bgp-0.15.0-py3-none-any.whl";
            sha256 = "4f67569176b13c4615f39e795fc4d042447f86cee4c14513e5223b5a11a71154";
          };
        };
        netbox-dns = buildPythonPackage rec {
          pname = "netbox-dns";
          version = "1.2.14";
          format = "wheel";
          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/ec/e0/34155edda9ab16656fd5fcf32d9bfeebbd68e22d3b62a446a24f05b025a0/netbox_plugin_dns-1.2.14-py3-none-any.whl";
            sha256 = "2b98bfaf6b20025cee1eaa6a28e11860ff6eb2b33d2b0d788fae7aa95ab8b98d";
          };
        };
        netbox-inventory = buildPythonPackage rec {
          pname = "netbox-inventory";
          version = "2.3.1";
          format = "wheel";
          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/e9/0c/3180c191b9493ee27d1658614d0cd61312eb8b302733e4ef6b74d31f3001/netbox_inventory-2.3.1-py3-none-any.whl";
            sha256 = "e9b8e603a9e800ed688945f56b48b1d2502669b95f0b8e5d4f2179769ed17678";
          };
        };
      in [
        dnspython
        netbox-bgp
        netbox-dns
        netbox-inventory
      ];
  };
}
