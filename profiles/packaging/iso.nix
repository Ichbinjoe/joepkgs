# enables packaging the image up as an ISO, but without all the dumb stuff that
# NixOS does that assumes you just want to make an install CD
# Mostly, this does the bare minimum - it'll use the same boot loader a normal
# system does, only uses UEFI since it isn't 1998 anymore and spit out a USB
# bootable image (because again, not 1998 and everyone boots off USB these
# days)
# a lot of this is copied from the install CD thing, but trims out the fat
# this works by using the overlay pattern to generate a new shadow configuration
# which sets up ISO specific stuff
{
  config,
  nixpkgs,
  pkgs,
  lib,
  ...
} @ attrs:
with lib; let
  # systemdWithUkify = pkgs.systemd.override {
  #   withUkify = true;
  # };
  # kernel = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
  # preinitrds = concatMapStringsSep " " lib.escapeShellArg config.boot.initrd.prepend;
  # initrd = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
  # kernelArgs = builtins.concatStringsSep " " config.boot.kernelParams;
  # osRelease = lib.escapeShellArg "@${config.system.build.etc}/etc/os-release";
  # efiArch = pkgs.stdenv.buildPlatform.efiArch;
  # buildUki = topLevel: outPath:
  #   ''
  #     ${systemdWithUkify}/lib/systemd/ukify \
  #       "${kernel}" \
  #       ${preinitrds} \
  #       "${initrd}" \
  #       --cmdline "init=${topLevel}/init ${kernelArgs}" \
  #       --os-release ${osRelease} \
  #       --uname ${lib.escapeShellArg config.system.nixos.version} \
  #       --efi-arch ${efiArch} \
  #       --stub "${pkgs.systemd}/lib/systemd/boot/efi/linux${efiArch}.efi.stub" \
  #       --tools "${systemdWithUkify}/bin" \
  #       --tools "${pkgs.bintools}/bin" \
  #       --tools "${pkgs.libllvm}/bin" \
  #       --output "${outPath}"
  #   '';
  entryOpts = {name, ...}: {
    options = {
      # TODO: systemd supports more options here, this needs refactored to
      # look at things other than just Linux kernels
      # TODO: figure out how to deal with SecureBoot
      # TODO: figure out how to deal with Linux kernel stubs (combined
      # initrd & kernel) images. Do they improve perf?
      name = mkOption {
        type = types.str;
        description = ''
          Name of this individual entry.
        '';
      };

      display = mkOption {
        type = types.nullOr types.str;
        description = ''
          Display text which systemd-boot will display with this boot entry.
        '';
        default = null;
      };

      kernel = mkOption {
        type = types.str;
        description = ''
          Which kernel to boot for this entry
        '';
      };

      initrd = mkOption {
        type = types.str;
        description = ''
          Which initrd to load for this entry
        '';
      };

      init = mkOption {
        type = types.str;
        description = ''
          Which init to instruct the Kernel to start
        '';
      };

      kernelParams = mkOption {
        type = types.listOf types.str;
        description = ''
          Which params to pass to the kernel
        '';
      };
    };
    config = {
      name = mkDefault name;
      display = mkDefault name;
      kernel = mkDefault "Linux/${config.system.boot.loader.kernelFile}";
      initrd = mkDefault "Linux/${config.system.boot.loader.initrdFile}";
      init = mkDefault "$toplevel/init";
      kernelParams = mkDefault config.boot.kernelParams;
    };
  };
in {
  options.system.boot.loader.simple-systemd = {
    enable = mkEnableOption "simple-systemd";
    entries = mkOption {
      type = types.attrsOf (types.submodule entryOpts);
      description = ''
        Entries to use for the systemd-boot bootloader
      '';
      default = {
        "default.conf" = {};
      };
    };
    defaultBoot = mkOption {
      type = types.str;
      description = ''
        Default boot option
      '';
      default = "default.conf";
    };

    editor = mkOption {
      type = types.bool;
      description = ''
        Whether or not to allow systemd-boot into an editor state
      '';
      default = true;
    };
    extraFiles = mkOption {
      type = types.attrsOf types.path;
      description = ''
        Extra files to include in the EFI directory
      '';
      defaultText = "";
      default = {
        "Linux/${config.system.boot.loader.kernelFile}" = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
        "Linux/${config.system.boot.loader.initrdFile}" = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
      };
    };
  };
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
      default = with pkgs.stdenv.targetPlatform;
        "xz -Xdict-size 100% "
        + optionalString isx86 "-Xbcj x86"
        # Untested but should also reduce size for these platforms
        + optionalString isAarch "-Xbcj arm"
        + optionalString (isPower && is32bit && isBigEndian) "-Xbcj powerpc"
        + optionalString isSparc "-Xbcj sparc";
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

  config = {
    # unlike the installer iso-image which seems just poorly written, we use the
    # iso specific config to generate this
    isoImage.storeContents =
      [config.system.build.toplevel]
      ++ optional config.isoImage.includeSystemBuildDependencies
      config.system.build.toplevel.drvPath;

    # Create the squashfs image that contains the Nix store.
    system.build.iso.squashfsStore = pkgs.callPackage (nixpkgs + "/nixos/lib/make-squashfs.nix") {
      storeContents = config.isoImage.storeContents;
      comp = config.isoImage.squashfsCompression;
    };

    boot.kernelParams = [
      "root=LABEL=${config.isoImage.volumeID}"
      "boot.shell_on_fail"
    ];

    boot.loader.grub.enable = false;

    # system.extraSystemBuilderCmds = buildUki "$out" "$out/uki";

    system.build.espImage = let
      systemd = config.systemd.package;

      cfg = config.system.boot.loader.simple-systemd;

      systemdBootLoaderEntry = e: ''
        title ${e.display}
        linux ${e.kernel}
        initrd ${e.initrd}
        options init=${e.init} ${lib.concatStringsSep " " e.kernelParams}
      '';

      systemdLoaderConf = ''
        default ${cfg.defaultBoot}
        timeout ${toString config.boot.loader.timeout}
        editor ${
          if cfg.editor
          then "y"
          else "n"
        }
      '';

      # TODO: Figure out how to properly escape this
      writeTextToFile = filename: text: ''
        cat <<EOF > ${filename}
          ${text}
        EOF
      '';

      loaderEntryName = e: "$espDir/loader/entries/${e.name}";
      genLoaderCreationScript = e: writeTextToFile (loaderEntryName e) (systemdBootLoaderEntry e);

      allLoaderCreationScript = lib.concatStringsSep "\n" (map genLoaderCreationScript (attrValues cfg.entries));
      copyExtraFile = name: path: "cp -r ${path} $espDir/${name}";
      copyAllExtrasScript = lib.concatStringsSep "\n" (mapAttrsToList copyExtraFile cfg.extraFiles);
    in
      pkgs.runCommand "esp-image"
      {
        nativeBuildInputs = [
          pkgs.buildPackages.dosfstools
          pkgs.buildPackages.libfaketime
          pkgs.buildPackages.mtools
        ];

        strictDeps = true;
      }
      ''
        mkdir ./contents
        export espDir="$(pwd)/contents"
        export toplevel="${config.system.build.toplevel}"

        mkdir -p $espDir/loader/entries
        mkdir -p $espDir/EFI/boot
        echo "type1" > $espDir/loader/entries.srel

        # Next, populate our conf
        ${writeTextToFile "$espDir/loader/loader.conf" systemdLoaderConf}

        # Now, populate each of our boot loader entries
        ${allLoaderCreationScript}

        # Now, copy over the key EFI binary
        cp ${systemd}/lib/systemd/boot/efi/systemd-bootx64.efi $espDir/EFI/boot/bootx64.efi

        # TODO: Clean up
        mkdir -p $espDir/Linux
        # Copy over 'extraFiles'
        ${copyAllExtrasScript}

        find $espDir -exec touch --date=2000-01-01 {} +

        usage_size=$(( $(du -s --block-size=1M --apparent-size $espDir | tr -cd '[:digit:]') * 1024 * 1024 ))
        # Make the image 110% as big as the files need to make up for FAT overhead
        image_size=$(( ($usage_size * 110) / 100 ))
        # Make the image fit blocks of 1M
        block_size=$((1024*1024))
        image_size=$(( ($image_size / $block_size + 1) * $block_size ))
        echo "Usage size: $usage_size"
        echo "Image size: $image_size"

        truncate --size=$image_size "$out"
        mkfs.vfat --invariant -i 12345678 -n EFIBOOT "$out"

        cd $espDir
        for d in $(find * -type d | sort); do
          faketime "2000-01-01 00:00:00" mmd -i "$out" "::/$d"
        done

        for f in $(find * -type f | sort); do
          mcopy -pvm -i "$out" "$f" "::/$f"
        done

        fsck.vfat -vn "$out"
      '';

    # Individual files to be included on the CD, outside of the Nix
    # store on the CD.
    isoImage.contents = [
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

    fileSystems = {
      "/" =
        mkImageMediaOverride
        {
          fsType = "tmpfs";
          options = ["mode=0755"];
        };

      # Note that /dev/root is a symlink to the actual root device
      # specified on the kernel command line, created in the stage 1
      # init script.
      "/iso" =
        mkImageMediaOverride
        {
          device = "/dev/root";
          neededForBoot = true;
          noCheck = true;
        };

      # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
      # image) to make this a live CD.
      "/nix/.ro-store" =
        mkImageMediaOverride
        {
          fsType = "squashfs";
          device = "/iso/nix-store.squashfs";
          options = ["loop"];
          neededForBoot = true;
        };

      "/nix/.rw-store" =
        mkImageMediaOverride
        {
          fsType = "tmpfs";
          options = ["mode=0755"];
          neededForBoot = true;
        };

      "/nix/store" =
        mkImageMediaOverride
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

    boot = {
      initrd = {
        availableKernelModules = ["squashfs" "iso9660" "uas" "overlay"];
        kernelModules = ["loop" "overlay"];
        supportedFilesystems = ["vfat"];
        # iso packaging can't use systemd based initrd - it won't boot.
        systemd.enable = false;
      };
      postBootCommands = ''
        # After booting, register the contents of the Nix store on the
        # CD in the Nix database in the tmpfs.
        ${config.nix.package.out}/bin/nix-store --load-db < /nix/store/nix-path-registration

        # nixos-rebuild also requires a "system" profile and an
        # /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      '';
    };

    # Create the ISO image. When we only allow booting via UEFI, we can drop the
    # bios based boot options
    system.build.isoImage = pkgs.callPackage (nixpkgs + "/nixos/lib/make-iso9660-image.nix") {
      inherit (config.isoImage) isoName compressImage volumeID contents;
      usbBootable = true;
      isohybridMbrImage = "${pkgs.syslinux}/share/syslinux/isohdpfx.bin";
      efiBootable = true;
      efiBootImage = "/boot/esp.img";
    };

    system.build.copyIsoToDisk = pkgs.writeShellScriptBin "write-iso-to-disk" ''
      disk="$1"

      sudo diskutil unmountDisk "$disk"
      sudo dd if=${config.system.build.isoImage}/iso/${config.isoImage.isoName} of=$disk status=progress oflag=direct,fsync bs=4m
    '';
  };
}
