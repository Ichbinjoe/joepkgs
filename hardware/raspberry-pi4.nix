{nixos-hardware, ...}: {
  imports = [
    nixos-hardware.nixosModules.raspberry-pi-4
    ./arch/aarch64-linux.nix
    ./raspberry-pi-generic.nix
  ];

  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // {allowMissing = true;});
    })
  ];

  hardware = {
    raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";
    };
  };

  # and also disable serial-getty - that's not going to help us out
  # systemd.services."serial-getty@ttyS1".enable = false;
}
