{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  imports = [
    ../../profiles/base.nix
    ../../profiles/defaults.nix
    ./dns.nix
    ./options.nix
    ./net.nix
    ./nftables.nix
    ./time.nix
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  boot.kernelParams = ["nomodeset"];

  environment.systemPackages = [pkgs.wireguard-tools];

  services.openssh.enable = true;
}
