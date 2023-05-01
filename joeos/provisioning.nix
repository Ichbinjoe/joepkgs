# provisioning-specific configuration / setup
# this is an importable module which exists to set up a system as one which
# boots, gets to a steady state, runs a provisioning script, then
# reboots

# we only support EFI boot directly to EFISTUB to keep it fast & dead simple
{ nixpkgs }: with nixpkgs; with lib;
{ config, pkgs, ... }:
let
  systemd = config.systemd.package;
  efiSysMountPoint = config.boot.loader.efi.efiSysMountPoint;
  efiDir = pkgs.runCommand "efi-directory"
    {
      buildInputs = [ pkgs.systemd ];
      strictDeps = true;
    } ''
    mkdir -p $out${efiSysMountPoint}/loader/entries/
    mkdir -p $out${efiSysMountPoint}/EFI/linux
    mkdir -p $out${efiSysMountPoint}/EFI/systemd
    mkdir -p $out${efiSysMountPoint}/EFI/boot
    mkdir -p $out${efiSysMountPoint}/boot

    cat <<EOF > $out${efiSysMountPoint}/loader/entries/default.conf
    title default
    linux /boot/${config.system.boot.loader.kernelFile}
    initrd /boot/${config.system.boot.loader.initrdFile}
    options init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
    EOF

    cat <<EOF > $out${efiSysMountPoint}/loader/loader.conf
    default default.conf
    timeout 0
    editor n
    EOF

    echo "type1" > $out${efiSysMountPoint}/loader/entries.srel

    cp ${systemd}/lib/systemd/boot/efi/systemd-bootx64.efi $out${efiSysMountPoint}/EFI/systemd/
    cp ${systemd}/lib/systemd/boot/efi/systemd-bootx64.efi $out${efiSysMountPoint}/EFI/boot/bootx64.efi

    cp ${config.system.build.kernel}/${config.system.boot.loader.kernelFile} $out${efiSysMountPoint}/boot/${config.system.boot.loader.kernelFile}
    cp ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} $out${efiSysMountPoint}/boot/${config.system.boot.loader.initrdFile}
  '';
  efiImg = pkgs.runCommand "efi-image_eltorito"
    {
      nativeBuildInputs = [ pkgs.buildPackages.mtools pkgs.buildPackages.libfaketime pkgs.buildPackages.dosfstools ];
      strictDeps = true;
    }
    # Be careful about determinism: du --apparent-size,
    #   dates (cp -p, touch, mcopy -m, faketime for label), IDs (mkfs.vfat -i)
    ''
      mkdir ./contents && cd ./contents
      cp -rp "${efiDir}"/${efiSysMountPoint}/* .

      # Rewrite dates for everything in the FS
      find . -exec touch --date=2000-01-01 {} +

      # Round up to the nearest multiple of 1MB, for more deterministic du output
      usage_size=$(( $(du -s --block-size=1M --apparent-size . | tr -cd '[:digit:]') * 1024 * 1024 ))
      # Make the image 110% as big as the files need to make up for FAT overhead
      image_size=$(( ($usage_size * 110) / 100 ))
      # Make the image fit blocks of 1M
      block_size=$((1024*1024))
      image_size=$(( ($image_size / $block_size + 1) * $block_size ))
      echo "Usage size: $usage_size"
      echo "Image size: $image_size"
      truncate --size=$image_size "$out"
      mkfs.vfat --invariant -i 12345678 -n EFIBOOT "$out"

      # Force a fixed order in mcopy for better determinism, and avoid file globbing
      for d in $(find EFI -type d | sort); do
        faketime "2000-01-01 00:00:00" mmd -i "$out" "::/$d"
      done

      for f in $(find EFI -type f | sort); do
        mcopy -pvm -i "$out" "$f" "::/$f"
      done
      
      for d in $(find loader -type d | sort); do
        faketime "2000-01-01 00:00:00" mmd -i "$out" "::/$d"
      done

      for f in $(find loader -type f | sort); do
        mcopy -pvm -i "$out" "$f" "::/$f"
      done
      
      for d in $(find boot -type d | sort); do
        faketime "2000-01-01 00:00:00" mmd -i "$out" "::/$d"
      done

      for f in $(find boot -type f | sort); do
        mcopy -pvm -i "$out" "$f" "::/$f"
      done
      
      # Verify the FAT partition.
      fsck.vfat -vn "$out"
    ''; # */
in
{
  imports = [ ];

  options = {
    isoImage.isoName = mkOption {
      default = "${config.isoImage.isoBaseName}.iso";
      description = lib.mdDoc ''
        Name of the generated ISO image file.
      '';
    };

    isoImage.isoBaseName = mkOption {
      default = config.system.nixos.distroId;
      description = lib.mdDoc ''
        Prefix of the name of the generated ISO image file.
      '';
    };

    isoImage.compressImage = mkOption {
      default = false;
      description = lib.mdDoc ''
        Whether the ISO image should be compressed using
        {command}`zstd`.
      '';
    };

    isoImage.squashfsCompression = mkOption {
      default = with pkgs.stdenv.targetPlatform; "xz -Xdict-size 100% "
        + lib.optionalString isx86 "-Xbcj x86"
        # Untested but should also reduce size for these platforms
        + lib.optionalString isAarch "-Xbcj arm"
        + lib.optionalString (isPower && is32bit && isBigEndian) "-Xbcj powerpc"
        + lib.optionalString (isSparc) "-Xbcj sparc";
      description = lib.mdDoc ''
        Compression settings to use for the squashfs nix store.
      '';
      example = "zstd -Xcompression-level 6";
    };

    isoImage.edition = mkOption {
      default = "";
      description = lib.mdDoc ''
        Specifies which edition string to use in the volume ID of the generated
        ISO image.
      '';
    };

    isoImage.volumeID = mkOption {
      # nixos-$EDITION-$RELEASE-$ARCH
      default = "nixos${optionalString (config.isoImage.edition != "") "-${config.isoImage.edition}"}-${config.system.nixos.release}-${pkgs.stdenv.hostPlatform.uname.processor}";
      description = lib.mdDoc ''
        Specifies the label or volume ID of the generated ISO image.
        Note that the label is used by stage 1 of the boot process to
        mount the CD, so it should be reasonably distinctive.
      '';
    };

    isoImage.contents = mkOption {
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

    isoImage.storeContents = mkOption {
      example = literalExpression "[ pkgs.stdenv ]";
      description = lib.mdDoc ''
        This option lists additional derivations to be included in the
        Nix store in the generated ISO image.
      '';
    };

    isoImage.includeSystemBuildDependencies = mkOption {
      default = false;
      description = lib.mdDoc ''
        Set this option to include all the needed sources etc in the
        image. It significantly increases image size. Use that when
        you want to be able to keep all the sources needed to build your
        system or when you are going to install the system on a computer
        with slow or non-existent network connection.
      '';
    };
  };

  # store them in lib so we can mkImageMediaOverride the
  # entire file system layout in installation media (only)
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

  config = {
    system.nixos.variant_id = "provisioner";

    # dump us straight into a root shell on boot
    services.getty.autologinUser = "root";

    # Tell the Nix evaluator to garbage collect more aggressively.
    # This is desirable in memory-constrained environments that don't
    # (yet) have swap set up.
    environment.variables.GC_INITIAL_HEAP_SIZE = "1M";

    # Make the installer more likely to succeed in low memory
    # environments.  The kernel's overcommit heustistics bite us
    # fairly often, preventing processes such as nix-worker or
    # download-using-manifests.pl from forking even if there is
    # plenty of free memory.
    boot.kernel.sysctl."vm.overcommit_memory" = "1";

    system.extraDependencies = with pkgs;
      [
        stdenv
        stdenvNoCC
        busybox
        jq
        makeInitrdNGTool
        systemdStage1
      ];


    # Prevent installation media from evacuating persistent storage, as their
    # var directory is not persistent and it would thus result in deletion of
    # those entries.
    environment.etc."systemd/pstore.conf".text = ''
      [PStore]
      Unlink=no
    '';

    # we actually want to create the simplest possible boot process. A lot of 
    # this is ripped from 'iso-image' but isn't reusing 'iso-image' as we 

    # In stage 1 of the boot, mount the CD as the root FS by label so
    # that we don't need to know its device.  We pass the label of the
    # root filesystem on the kernel command line, rather than in
    # `fileSystems' below.  This allows CD-to-USB converters such as
    # UNetbootin to rewrite the kernel command line to pass the label or
    # UUID of the USB stick.  It would be nicer to write
    # `root=/dev/disk/by-label/...' here, but UNetbootin doesn't
    # recognise that.
    boot.kernelParams =
      [
        "root=LABEL=${config.isoImage.volumeID}"
        "boot.shell_on_fail"
        "nomodeset"
      ];

    fileSystems = config.lib.isoFileSystems;

    boot.initrd.availableKernelModules = [ "squashfs" "iso9660" "uas" "overlay" ];

    boot.initrd.kernelModules = [ "loop" "overlay" ];

    # Closures to be copied to the Nix store on the CD, namely the init
    # script and the top-level system configuration directory.
    isoImage.storeContents =
      [ config.system.build.toplevel ] ++
      optional config.isoImage.includeSystemBuildDependencies
        config.system.build.toplevel.drvPath;

    # Create the squashfs image that contains the Nix store.
    system.build.squashfsStore = pkgs.callPackage (nixpkgs + "/nixos/lib/make-squashfs.nix") {
      storeContents = config.isoImage.storeContents;
      comp = config.isoImage.squashfsCompression;
    };

    # Individual files to be included on the CD, outside of the Nix
    # store on the CD.
    isoImage.contents =
      [
        {
          source = config.boot.kernelPackages.kernel + "/" + config.system.boot.loader.kernelFile;
          target = "/boot/" + config.system.boot.loader.kernelFile;
        }
        {
          source = config.system.build.initialRamdisk + "/" + config.system.boot.loader.initrdFile;
          target = "/boot/" + config.system.boot.loader.initrdFile;
        }
        {
          source = config.system.build.squashfsStore;
          target = "/nix-store.squashfs";
        }
        {
          source = pkgs.writeText "version" config.system.nixos.label;
          target = "/version.txt";
        }
        {
          source = efiImg;
          target = "/boot/efi.img";
        }
        {
          source = "${efiDir}/${efiSysMountPoint}";
          target = "/${efiSysMountPoint}";
        }
      ];

    boot.loader.timeout = 0;
    boot.loader.grub.enable = false;

    # Create the ISO image.
    system.build.isoImage = pkgs.callPackage (nixpkgs + "/nixos/lib/make-iso9660-image.nix") ({
      inherit (config.isoImage) isoName compressImage volumeID contents;
      # bootable = true;
      # bootImage = "/isolinux/isolinux.bin";
      # syslinux = pkgs.syslinux;
      usbBootable = true;
      isohybridMbrImage = "${pkgs.syslinux}/share/syslinux/isohdpfx.bin";
      efiBootable = true;
      efiBootImage = "/boot/efi.img";
    });

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

    boot.loader.efi.efiSysMountPoint = "/";

    # Add vfat support to the initrd to enable people to copy the
    # contents of the CD to a bootable USB stick.
    boot.initrd.supportedFilesystems = [ "vfat" ];
  };
}
