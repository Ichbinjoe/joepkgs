# We actually don't want to use the the udevd activation script (or populate a
# special firmware_class option) - instead, using a standard symlink direct on
# the disk to our firmware makes the most sense

{ config
, nixpkgs
, pkgs
, lib
, ...
}:
with lib;
let
  cfg = config.services.udev;
in
mkIf config.enable { 
  
}
