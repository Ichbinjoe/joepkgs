{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../profiles/base.nix
    ../../profiles/defaults.nix
    ./bird-lg.nix
    ./bird
    ./buildbox.nix
    ./dn42.nix
    ./dn42-expose.nix
    ./grafana.nix
    ./haproxy.nix
    ./jellyfin.nix
    ./netbox.nix
    ./nsd.nix
    ./paperless.nix
    ./prometheus.nix
    ./postgres.nix
    ./syncthing.nix
    ./unbound.nix
    ./wireguard.nix
    ./zfs.nix
    ./znc.nix
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  networking.firewall.enable = false;
  networking.useNetworkd = true;
  networking.dhcpcd.enable = false;

  systemd.network.enable = true;
  systemd.network.wait-online.anyInterface = true;

  # basic ssh
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    zfs
    ldns.examples
  ];

  dn42.addrs = [
    "fde7:76fd:7444:eeee::1"
  ];

  dn42.advertisements6 = [
    "fde7:76fd:7444:eeee::/64"
  ];

  dn42Ca = true;
}
