# packaging helpers - often it is easier to just take these and move them
# around instead of entire systems
{ config, nixpkgs, pkgs, lib, ... }@attrs: with lib;
{
  config = {
    # unlike the iso, we just build a REALLY BIG TARBALL
    # everyone loves a good tarball!
    system.build.nixstoreTar = pkgs.stdenvNoCC.mkDerivation {
      name = "nixstore.tar.gz";

      buildCommand = ''
        closureInfo=${pkgs.closureInfo { rootPaths = config.system.build.toplevel; }}

        tar -cz --file=$out --hard-dereference --group=root --owner=root --directory=/ $(cat $closureInfo/store-paths) 
      '';
    };
    
    # also, put the path registration somewhere. not in the tarball, we don't care
    # if it ends up on the end system
    system.build.nixPathRegistration = pkgs.stdenvNoCC.mkDerivation {
      name = "nix-path-registration";

      buildCommand = ''
        closureInfo=${pkgs.closureInfo { rootPaths = config.system.build.toplevel; }}
        cp $closureInfo/registration $out
      '';
    };
    system.build.bootstrapScript = pkgs.writeShellScriptBin "bootstrap" ''
      # at this point, we assume that
      # 1) the filesystem passed in as an argument is set up correctly for a chroot
      # 2) we are root

      set -x

      # first, extract out the nixstore
      tar -xz --file=${config.system.build.nixstoreTar} --directory=$1
              
      # touch /etc/NIXOS so that it is happy
      touch $1/etc/NIXOS
              
      # run activate. I don't know whether this is required or not, but shouldn't hurt
      chroot $1 ${config.system.build.toplevel}/activate

      # then, jump in and register stuff to the nix-store.
      chroot $1 ${config.nix.package.out}/bin/nix-store --load-db < ${config.system.build.nixPathRegistration}
              
      # finally, use switch-to-configuration to get bootloader stuff flipped over - this 
      # should allow the system to reboot clean into the new system
      chroot $1 ${config.system.build.toplevel}/bin/switch-to-configuration boot
    '';

  };
}
