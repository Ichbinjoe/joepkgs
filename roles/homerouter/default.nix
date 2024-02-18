{
  config,
  lib,
  pkgs,
  nnf,
  ...
}:
with lib; {
  imports = [
    nnf.nixosModules.default
    ../../profiles/base.nix
    ../../profiles/defaults.nix
    ./dn42.nix
    ./dns.nix
    ./firewall.nix
    ./options.nix
    ./net.nix
    ./time.nix
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  boot.kernelParams = ["nomodeset"];

  environment.systemPackages = with pkgs; [
    ethtool
    sipcalc
    tshark
    wireguard-tools
  ];

  services.openssh.enable = true;

  services.prometheus.exporters = {
    bird = {
      enable = true;
      group = "bird2";
    };

    node = {
      enable = true;
      enabledCollectors = [
        "ethtool"
        "ksmd"
        "interrupts"
        "qdisc"
      ];
    };

    smartctl.enable = true;

    smokeping = {
      enable = true;
      hosts = ["1.1.1.1"];
    };

    systemd.enable = true;

    unbound = {
      enable = true;
      unbound = {
        key = null;
        certificate = null;
        ca = null;
        host = "unix:///run/unbound/unbound.socket";
      };
    };
  };
}
