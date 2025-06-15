{config, ...}: {
  imports = [
    # Intel x86
    ./arch/x86_64-linux.nix
  ];

  # The ugreen NAS comes with watchdog which needs to be enabled in software
  systemd.watchdog.runtimeTime = "180s";
}
