{
  config,
  lib,
  pkgs,
  tempmonitor,
  ...
}:
with lib; {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
  ];

  # We want this to have Wifi
  networking.wireless.enable = true;

  environment.systemPackages = with pkgs; [
    bluez
    bluez-tools
    minicom
    tempmonitor.packages.${config.nixpkgs.hostPlatform.system}
    screen
    setserial
  ];

  programs.fish.enable = false;
  programs.neovim.enable = false;
  users.defaultUserShell = mkForce pkgs.bashInteractive;

  boot.kernelParams = ["nomodeset"];
  console.enable = false;
  systemd.services."serial-getty@ttyS1".enable = false;

  services.openssh.enable = true;
}
