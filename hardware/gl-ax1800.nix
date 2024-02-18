{...}: {
  imports = [
    ./arch/armv7l.nix
  ];
  deviceTree = {
    enable = true;
    overlays = [
      {
        name = "base";
        dtsFile = ./gl-ax1800.dts;
      }
    ];
  };
}
