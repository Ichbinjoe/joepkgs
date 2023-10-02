{
  config,
  pkgs,
  ...
}: let
  camera-streamer = pkgs.callPackage ../pkgs/camera-streamer {};
in {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
  ];

  services.openssh.enable = true;

  environment.systemPackages = [
    pkgs.libraspberrypi
    pkgs.v4l-utils
  ];

  # use haproxy to actually front octoprint
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
        log     global
        mode    http
        compression algo gzip
        option  httplog
        option  dontlognull
        retries 3
        option redispatch
        option http-server-close
        option forwardfor
        maxconn 2000
        timeout connect 5s
        timeout client  15m
        timeout server  15m

      frontend public
        bind :::80 v4v6
        option forwardfor except 127.0.0.1
        use_backend webcam if { path_beg /webcam/ }
        use_backend webcam_hls if { path_beg /hls/ }
        use_backend webcam_hls if { path_beg /jpeg/ }
        default_backend octoprint

      backend octoprint
        acl needs_scheme req.hdr_cnt(X-Scheme) eq 0

        http-request replace-path ^([^\ :]*)\ /(.*) \1\ /\2
        http-request add-header X-Scheme https if needs_scheme { ssl_fc }
        http-request add-header X-Scheme http if needs_scheme !{ ssl_fc }
        option forwardfor
        server octoprint1 [::1]:${toString config.services.octoprint.port}

      backend webcam
        http-request replace-path /webcam/(.*) /\1
        server webcam1  [::1]:8080

      backend webcam_hls
        server webcam_hls_1 [::1]:28126
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];

  services.octoprint = {
    enable = true;
    host = "::1";
  };

  users.users."${config.services.octoprint.user}".extraGroups = ["video"];

  #   systemd.packages = [ camera-streamer ];

  #   users.users.webcam = {
  #     isSystemUser = true;
  #     group = "nogroup";
  #     extraGroups = [ "video" ];
  #   };

  #   systemd.services.camera-streamer-raspi-usb-cam = {
  #     enable = true;
  #     serviceConfig = {
  #       # TODO: fix this - for whatever reason it isn't working
  #       DynamicUser = "no";
  #       SupplimentaryGroups = [ "" ];
  #       User = "webcam";
  #     };
  #   };
}
