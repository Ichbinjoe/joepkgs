{config, pkgs, ...}: {
  imports = [
    # Intel x86
    ./arch/x86_64-linux.nix
  ];

  boot.extraModulePackages = [
    (pkgs.callPackage ../pkgs/ugreen-leds {})
  ];
}
