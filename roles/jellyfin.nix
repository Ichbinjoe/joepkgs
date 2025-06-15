{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
  ];

  # basic ssh
  services.openssh.enable = true;

  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
  };

  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
    ];
  };

  environment.systemPackages = [
    pkgs.intel-gpu-tools
    pkgs.jellyfin
    pkgs.jellyfin-web
    pkgs.jellyfin-ffmpeg
    pkgs.transmission
    pkgs.wireguard-tools
  ];

  services.jellyfin = {
    enable = true;
    openFirewall = false;
  };

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
        use_backend jellyfin

      backend jellyfin
        option httpchk
        option forwardfor
        http-check send meth GET uri /health
        http-check expect string Healthy
        server jellyfin 127.0.0.1:8096
    '';
  };

  networking.firewall.allowedTCPPorts = [80 22000];
  networking.firewall.allowedUDPPorts = [22000 21027];

  fileSystems = {
    "/media" = {
      device = "/dev/mapper/media-lvol0";
      fsType = "xfs";
    };
  };
}
