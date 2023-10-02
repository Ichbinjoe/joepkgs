{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
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
      default = false;
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
  config = let
    # bind this to the systemd package
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
    mkIf cfg.enable {
      boot.loader.grub.enable = false;

      system.build.buildEspDir = ''
        # First, make our important directories
        mkdir -p $espDir/loader/entries
        mkdir -p $espDir/EFI/boot

        # Mark our entry store as a 'type1' entry store. Without this,
        # systemd-boot won't be able to figure out how to read our store
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
      '';
    };
}
