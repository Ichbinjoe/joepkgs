{config, ...}: {
  imports = [
    ./arch/aarch64-linux.nix
    ./raspberry-pi-generic.nix
  ];
}
