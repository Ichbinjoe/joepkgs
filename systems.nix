{
  nixpkgs,
  private,
  ...
} @ attrs: let
  assembleSystem = hostname: modules:
    nixpkgs.lib.nixosSystem {
      extraModules = import ./modules/module-list.nix;
      modules = modules ++ [{networking.hostName = hostname;}];
      specialArgs = attrs;
    };
in rec {
  buildbox-x64 = assembleSystem "buildbox-x64" [
    ./hardware/x86_64-generic.nix
    ./profiles/packaging/btrfs-root.nix
    ./roles/buildbox.nix
    ./profiles/joe-user.nix
    private.nixosModules.joe
    private.nixosModules.nixos-remote-build
  ];

  buildbox-rpi = assembleSystem "buildbox-rpi" [
    ./hardware/raspberry-pi4.nix
    ./profiles/packaging/sd-image-aarch64.nix
    ./roles/buildbox.nix
    ./profiles/joe-user.nix
    private.nixosModules.joe
    private.nixosModules.nixos-remote-build
  ];

  buildbox-rpi-cross = assembleSystem "buildbox-rpi" [
    ./hardware/raspberry-pi4.nix
    ./profiles/packaging/sd-image-aarch64.nix
    ./roles/buildbox.nix
    ./profiles/joe-user.nix
    private.nixosModules.joe
    private.nixosModules.nixos-remote-build
    ./profiles/cross-compile-on-x86.nix
  ];

  homerouter = assembleSystem "router" [
    ./hardware/router.nix
    ./profiles/packaging/btrfs-root.nix
    ./roles/homerouter
    ./profiles/joe-user.nix
    private.nixosModules.joe
    private.nixosModules.homerouter
  ];

  printerpi = assembleSystem "printerpi" [
    ./hardware/raspberry-pi3.nix
    ./profiles/packaging/sd-image-aarch64.nix
    ./roles/3dprinter.nix
    ./profiles/joe-user.nix
    private.nixosModules.joe
  ];

  homeautomation = assembleSystem "homeautomation" [
    ./hardware/x86_64-generic.nix
    ./profiles/packaging/btrfs-root.nix
    ./roles/homeautomation.nix
    ./profiles/joe-user.nix
    private.nixosModules.joe
  ];

  homeautomation-provision = assembleSystem "homeautomation-provision" [
    ./hardware/x86_64-generic.nix
    ./profiles/packaging/iso.nix
    ./roles/provisioner.nix
    ./profiles/joe-user.nix
    private.nixosModules.joe
    ({pkgs, ...}: {
      environment.systemPackages = [
        ((pkgs.callPackage
          ./lib/provision.nix
          {})
        homeautomation.config)
      ];
    })
  ];

  brewmonitor = assembleSystem "brewmonitor" [
    ./hardware/raspberry-pi-zero-2.nix
    ./profiles/packaging/sd-image-aarch64.nix
    ./roles/brewmonitor.nix
    ./profiles/joe-user.nix
    private.nixosModules.joe
    private.nixosModules.home-wifi
  ];
}
