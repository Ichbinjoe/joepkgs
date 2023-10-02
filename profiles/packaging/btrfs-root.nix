# Assume we have a standard two partition setup, one labeled boot (vfat) and
# one labeled root (btrfs). The root exists on the 'root' partlabel'd partition.
{config, ...}: {
  imports = [
    ../boot/systemd-boot.nix
  ];

  boot.kernelParams = ["root=/dev/disk/by-partlabel/root"];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-partlabel/root";
      fsType = "btrfs";
      options = ["compress=zstd"];
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/boot";
      fsType = "vfat";
    };
    "/var" = {
      device = "/dev/disk/by-partlabel/root";
      fsType = "btrfs";
      options = ["compress=zstd" "subvol=var"];
    };
    "/nix" = {
      device = "/dev/disk/by-partlabel/root";
      fsType = "btrfs";
      options = ["compress=zstd" "subvol=nix"];
    };
    "/home" = {
      device = "/dev/disk/by-partlabel/root";
      fsType = "btrfs";
      options = ["compress=zstd" "subvol=home"];
    };
  };
}
