{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./arch/aarch64-linux.nix
    ./raspberry-pi-generic.nix
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  hardware.deviceTree = {
    enable = true;
    filter = "*-rpi-zero-2-w.dtb";
    overlays = [
      {
        name = "uart1";
        dtsFile = ./pi-zero2-uart1.dts;
      }
    ];
  };
}
