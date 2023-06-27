{ config, pkgs, lib, ... }: with lib;
{
  options = {
    system.boot.loader = {
      kernelPath = mkOption {
        type = types.path;
        default = "/boot/${config.system.boot.loader.kernelFile}";
      };
      initrdPath = mkOption {
        type = types.path;
        default = "/boot/${config.system.boot.loader.initrdPath}";
      };
      esp.imageSize = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Size to create / withold for the efi image
        '';
      };
    };
    system.build.buildEspDir = mkOption {
      type = (types.either types.str types.package);
    };
    system.build.applyEfiVars = mkOption {
      type = (types.either types.str types.package);
    };
  };
  config =
    let
      systemd = config.systemd.package;
    in
    {
      # always set installBootLoader - any boot loaders we create should be buildable without being on the live system,
      # so this arrangement allows us to plug in different esps
      system.build.installBootLoader = pkgs.writeScript "install-bootloader" '' 
        #!${pkgs.runtimeShell}

        export espDir="${config.boot.loader.efi.efiSysMountPoint}"
        export toplevel="$1"
        ${config.system.build.buildEspDir}
        
        ${if config.boot.loader.efi.canTouchEfiVariables then config.system.build.applyEfiVars else ""}
        '';

      # separately, enable the build of the efiDir itself
      system.build.espImage =
        let
          imageSize =
            if config.system.boot.loader.esp.imageSize != null then ''
              image_size=${system.boot.loader.esp.imageSize}
              echo "Image size: $image_size"
            '' else ''
              usage_size=$(( $(du -s --block-size=1M --apparent-size $espDir | tr -cd '[:digit:]') * 1024 * 1024 ))
              # Make the image 110% as big as the files need to make up for FAT overhead
              image_size=$(( ($usage_size * 110) / 100 ))
              # Make the image fit blocks of 1M
              block_size=$((1024*1024))
              image_size=$(( ($image_size / $block_size + 1) * $block_size ))
              echo "Usage size: $usage_size"
              echo "Image size: $image_size"
            '';
        in
        pkgs.runCommand "esp-image"
          {
            nativeBuildInputs = [
              pkgs.buildPackages.dosfstools
              pkgs.buildPackages.libfaketime
              pkgs.buildPackages.mtools
            ];

            strictDeps = true;
          } ''
          mkdir ./contents
          export espDir="$(pwd)/contents"
          export toplevel="${config.system.build.toplevel}"

          ${config.system.build.buildEspDir}

          find $espDir -exec touch --date=2000-01-01 {} +

          ${imageSize}

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
    };
}
