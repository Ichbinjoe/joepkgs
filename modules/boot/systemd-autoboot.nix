# This isn't finished yet!
{
  config,
  lib,
  ...
}:
with lib; let
  efi = config.boot.loader.efi;
  cfg = config.boot.loader.systemd-boot;
  generationBootBuilder = pkgs.writeShellScript "install-systemd-boot.sh" ''

    ${cfg.extraInstallCommands}
  '';
in {
  options.boot.loader.systemd-boot = {
    useAutoRollback = mkEnableOption "Use auto-rollback style of boot option generation";

    tries = mkOption {
      default = 3;
      type = types.int;
    };
  };

  config = mkIf (cfg.enable && cfg.useAutoRollback) {
    # system.build.installBootLoader = mkForce generationBootBuilder;
  };
}
