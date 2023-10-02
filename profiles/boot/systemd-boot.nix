{
  config,
  lib,
  ...
}:
with lib; {
  boot.loader.systemd-boot = {
    enable = true;
    editor = mkDefault false;
  };
}
