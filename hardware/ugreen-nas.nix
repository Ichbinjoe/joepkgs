{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Intel x86
    ./arch/x86_64-linux.nix
  ];

  boot.extraModulePackages = [
    (pkgs.callPackage ../pkgs/ugreen-leds {})
  ];

  services.udev.extraRules = with lib; let
    rule = n: "SUBSYSTEM==\"block\", KERNELS==\"ata${n}\", SUBSYSTEMS==\"pci\", TAGS==\"nas\", SYMLINK+=\"bay${n}\"";
    all_rules = concatMapStringsSep "\n" rule (map toString [1 2 3 4 5 6 7 8]);
  in
    all_rules;

  networking.hostId = "f1c09415";
  boot.supportedFilesystems.zfs = true;

  services.rsyncd = {
    enable = true;
    settings = {
      globalSection = {
        address = "0.0.0.0";
      };

      sections.media = {
        path = "/zpool/media";
        comment = "Media mount";
        "auth users" = "media";
        "secrets file" = "/var/lib/rsync/media.secrets";
        "uid" = "root";
        "gid" = "root";
        "use chroot" = true;
        "read only" = false;
        "write only" = false;
      };
    };
  };
}
