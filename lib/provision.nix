{
  pkgs,
  lib,
  ...
}:
with lib;
  config: let
    name = "${config.system.name}-${config.system.nixos.label}";
    closureInfo = pkgs.closureInfo {rootPaths = config.system.build.toplevel;};
    bootstrapUnderLock = pkgs.writeShellScript "bootstrapUnderLock-${name}" ''
      set -x

      # copy over relevant closures into /nix/store using the closureInfo
      ${pkgs.rsync}/bin/rsync -ar --files-from="${closureInfo}/store-paths" "/" "$1"

      # activate the environment
      chroot $1 ${config.system.build.toplevel}/activate

      # register the paths to the nix store
      chroot $1 ${config.nix.package.out}/bin/nix-store --load-db < ${closureInfo}/registration
    '';
  in
    pkgs.writeShellScriptBin "bootstrap-${name}" ''
      # at this point, we assume that
      # 1) the filesystem passed in as an argument is set up correctly for a chroot
      # 2) we are root

      set -x

      # touch /etc/NIXOS so that it is happy
      if [[ ! -d $1/etc ]]; then
        mkdir $1/etc
      fi
      touch $1/etc/NIXOS

      bootctl --esp-path=$1/boot install
      mkdir -p $1/tmp
      mkdir -p $1/nix/var/nix/profiles
      ln -sf '${config.system.build.toplevel}' "$1/nix/var/nix/profiles/system-1-link"

      # when we lock the GC we can then bulk copy all of our closures in
      # TODO: is this usage of flock valid?
      flock $1/nix/var/nix/gc.lock ${bootstrapUnderLock} $1

      # finally, use switch-to-configuration to get bootloader stuff flipped over - this
      # should allow the system to reboot clean into the new system
      chroot $1 ${config.system.build.toplevel}/bin/switch-to-configuration boot

      # sync for good measure
      sync
    ''
