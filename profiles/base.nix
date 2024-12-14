# These are some generally not massive yet nice to have basics that you would expect on any system
{
  config,
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # EFI utilities
    pkgs.efibootmgr
    pkgs.efivar

    # Disk management / partitioning
    pkgs.btrfs-progs
    pkgs.lvm2
    pkgs.parted

    # System utilities
    pkgs.curl
    pkgs.git
    pkgs.htop
    pkgs.jq
    pkgs.tmux
    pkgs.wget

    # Network related utilities
    pkgs.conntrack-tools
    pkgs.dig
    pkgs.mtr
    pkgs.openssl
    pkgs.socat
    pkgs.tcpdump

    # Hardware-related tools.
    pkgs.sdparm
    pkgs.hdparm
    pkgs.smartmontools # for diagnosing hard disks
    pkgs.pciutils
    pkgs.usbutils
    pkgs.nvme-cli
    pkgs.dmidecode

    # Some compression/archiver tools.
    pkgs.unzip
    pkgs.zip
  ];
}
