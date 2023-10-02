# This module is specifically thrown in the mix when we need to force
# cross-compilation on a x86_64 machine. Typically these are easier to
# bootstrap (versus a bunch of aarch64 machines) and really are only necessary
# when we don't have a aarch64 native builder
{...}: {
  nixpkgs.buildPlatform = {
    system = "x86_64-linux";
  };
}
