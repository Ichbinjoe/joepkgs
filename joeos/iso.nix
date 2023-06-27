# enables packaging the image up as an ISO, but without all the dumb stuff that
# NixOS does that assumes you just want to make an install CD

# Mostly, this does the bare minimum - it'll use the same boot loader a normal
# system does, only uses UEFI since it isn't 1998 anymore and spit out a USB
# bootable image (because again, not 1998 and everyone boots off USB these
# days)

# a lot of this is copied from the install CD thing, but trims out the fat

# this works by using the overlay pattern to generate a new shadow configuration
# which sets up ISO specific stuff
{ config, nixpkgs, pkgs, lib, ... }@attrs: with lib;

{
  options.isoImage = {
    # we use this strategy as nixos does some pretty wonky stuff if you start mucking with options
    isoName = mkOption {
      default = "${config.isoImage.isoBaseName}.iso";
      description = mdDoc ''
        Name of the generated ISO image file.
      '';
    };

    isoBaseName = mkOption {
      default = config.system.nixos.distroId;
      description = mdDoc ''
        Prefix of the name of the generated ISO image file.
      '';
    };

    compressImage = mkOption {
      default = false;
      description = mdDoc ''
        Whether the ISO image should be compressed using
        {command}`zstd`.
      '';
    };

    squashfsCompression = mkOption {
      default = with pkgs.stdenv.targetPlatform; "xz -Xdict-size 100% "
        + optionalString isx86 "-Xbcj x86"
        # Untested but should also reduce size for these platforms
        + optionalString isAarch "-Xbcj arm"
        + optionalString (isPower && is32bit && isBigEndian) "-Xbcj powerpc"
        + optionalString (isSparc) "-Xbcj sparc";
      description = mdDoc ''
        Compression settings to use for the squashfs nix store.
      '';
      example = "zstd -Xcompression-level 6";
    };

    edition = mkOption {
      default = "";
      description = mdDoc ''
        Specifies which edition string to use in the volume ID of the generated
        ISO image.
      '';
    };

    volumeID = mkOption {
      # nixos-$EDITION-$RELEASE-$ARCH
      default = "nixos${optionalString (config.isoImage.edition != "") "-${config.isoImage.edition}"}-${config.system.nixos.release}-${pkgs.stdenv.hostPlatform.uname.processor}";
      description = mdDoc ''
        Specifies the label or volume ID of the generated ISO image.
        Note that the label is used by stage 1 of the boot process to
        mount the CD, so it should be reasonably distinctive.
      '';
    };

    contents = mkOption {
      example = literalExpression ''
        [ { source = pkgs.memtest86 + "/memtest.bin";
            target = "boot/memtest.bin";
          }
        ]
      '';
      description = lib.mdDoc ''
        This option lists files to be copied to fixed locations in the
        generated ISO image.
      '';
    };

    storeContents = mkOption {
      example = literalExpression "[ pkgs.stdenv ]";
      description = lib.mdDoc ''
        This option lists additional derivations to be included in the
        Nix store in the generated ISO image.
      '';
    };

    includeSystemBuildDependencies = mkOption {
      default = false;
      description = mdDoc ''
        Set this option to include all the needed sources etc in the
        image. It significantly increases image size. Use that when
        you want to be able to keep all the sources needed to build your
        system or when you are going to install the system on a computer
        with slow or non-existent network connection.
      '';
    };
  };

  config.lib.isoFileSystems = {
    "/" = mkImageMediaOverride
      {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };

    # Note that /dev/root is a symlink to the actual root device
    # specified on the kernel command line, created in the stage 1
    # init script.
    "/iso" = mkImageMediaOverride
      {
        device = "/dev/root";
        neededForBoot = true;
        noCheck = true;
      };

    # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
    # image) to make this a live CD.
    "/nix/.ro-store" = mkImageMediaOverride
      {
        fsType = "squashfs";
        device = "/iso/nix-store.squashfs";
        options = [ "loop" ];
        neededForBoot = true;
      };

    "/nix/.rw-store" = mkImageMediaOverride
      {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
        neededForBoot = true;
      };

    "/nix/store" = mkImageMediaOverride
      {
        fsType = "overlay";
        device = "overlay";
        options = [
          "lowerdir=/nix/.ro-store"
          "upperdir=/nix/.rw-store/store"
          "workdir=/nix/.rw-store/work"
        ];
        depends = [
          "/nix/.ro-store"
          "/nix/.rw-store/store"
          "/nix/.rw-store/work"
        ];
      };
    };

  imports = [
    ./default.nix
  ];

  config = {
    # unlike the installer iso-image which seems just poorly written, we use the 
    # iso specific config to generate this
    isoImage.storeContents =
      [ config.system.build.toplevel ] ++
      optional config.isoImage.includeSystemBuildDependencies
        config.system.build.toplevel.drvPath;


    # Create the squashfs image that contains the Nix store.
    system.build.iso.squashfsStore = pkgs.callPackage (nixpkgs + "/nixos/lib/make-squashfs.nix") {
      storeContents = config.isoImage.storeContents;
      comp = config.isoImage.squashfsCompression;
    };

    # Individual files to be included on the CD, outside of the Nix
    # store on the CD.
    isoImage.contents =
      [
        {
          source = config.system.build.iso.squashfsStore;
          target = "/nix-store.squashfs";
        }
        {
          source = pkgs.writeText "version" config.system.nixos.label;
          target = "/version.txt";
        }
        {
          source = config.system.build.espImage;
          target = "/boot/esp.img";
        }
      ];

    # Prevent installation media from evacuating persistent storage, as their
    # var directory is not persistent and it would thus result in deletion of
    # those entries.
    environment.etc."systemd/pstore.conf".text = ''
      [PStore]
      Unlink=no
    '';

    # TODO: This should probably freak out if you specify multiple roots, but whatever
    boot.kernelParams = [
      "root=LABEL=${config.isoImage.volumeID}"
      "nomodeset"
    ];

    system.boot.loader.simple-systemd.enable = true;
    fileSystems = config.lib.isoFileSystems;

    boot.initrd.availableKernelModules = [ "squashfs" "iso9660" "uas" "overlay" ];

    boot.initrd.kernelModules = [ "loop" "overlay" ];

    # TODO: Do we actually need this? How can we pre-load this?
    boot.postBootCommands =
      ''
        # After booting, register the contents of the Nix store on the
        # CD in the Nix database in the tmpfs.
        ${config.nix.package.out}/bin/nix-store --load-db < /nix/store/nix-path-registration

        # nixos-rebuild also requires a "system" profile and an
        # /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      '';


    # Add vfat support to the initrd to enable people to copy the
    # contents of the CD to a bootable USB stick.
    boot.initrd.supportedFilesystems = [ "vfat" ];

    # Create the ISO image. When we only allow booting via UEFI, we can drop the
    # bios based boot options
    system.build.isoImage = pkgs.callPackage (nixpkgs + "/nixos/lib/make-iso9660-image.nix") ({
      inherit (config.isoImage) isoName compressImage volumeID contents;
      usbBootable = true;
      isohybridMbrImage = "${pkgs.syslinux}/share/syslinux/isohdpfx.bin";
      efiBootable = true;
      efiBootImage = "/boot/esp.img";
    });
  };
}
