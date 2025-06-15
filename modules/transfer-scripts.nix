# helper module which hands us a nice shell script which will build & upload a
# configuration to a given ssh server
{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  updateProfiles = pkgs.writeShellScriptBin "update-profiles" ''
    lastgen=$(find /nix/var/nix/profiles/ -name 'system-*-link' -type l -printf '%P\n' | awk -F'-' '{print $2}' | sort -nr | head -n1)
    if [ -z $lastgen ]; then
      lastgen="-1"
    fi
    newgen="/nix/var/nix/profiles/system-$((lastgen + 1))-link"
    ln -sn "${config.system.build.toplevel}" "$newgen"
    ln -sfn "$newgen" "/nix/var/nix/profiles/system"
  '';

  switchAndCreateGeneration = pkgs.writeShellScriptBin "switch-and-create-gen" ''
    # record the new generation
    flock /nix/var/nix/profiles.lock -c ${updateProfiles}/bin/update-profiles

    # actually perform the switch
    ${config.system.build.toplevel}/bin/switch-to-configuration $1
  '';
in {
  config.system.build.transferScripts = localPkgs: rec {
    toplevel = config.system.build.toplevel;
    uploadViaSsh = localPkgs.writeShellScriptBin "upload-via-ssh" ''
      ${localPkgs.nix}/bin/nix-copy-closure --to "$1" "${switchAndCreateGeneration}"
      ssh -t "$1" -- "bash -c \"sudo -- ${switchAndCreateGeneration}/bin/switch-and-create-gen $2\""
    '';

    # This is specifically designed for MacOS
    writeSdImage = localPkgs.writeShellScriptBin "write-sd-image" ''
      disk="$1"

      sudo diskutil unmountDisk "$disk"
      ${
        if config.sdImage.compressImage
        then ''
          sudo ${localPkgs.zstd.bin}/bin/zstd -d --no-progress --stdout -- ${config.system.build.sdImage}/sd-image/${config.sdImage.imageName}.zst | sudo dd of=$disk bs=4m status=progress oflag=direct,fsync
        ''
        else ''
          sudo dd if=${config.system.build.sdImage}/sd-image/${config.sdImage.imageName} of=$disk status=progress oflag=direct,fsync bs=4m
        ''
      }
    '';

    writeIso = config.system.build.copyIsoToDisk;
    writeProvisionerIso = (config.system.build.provisioner.config.system.build.transferScripts localPkgs).writeIso;
  };
}
