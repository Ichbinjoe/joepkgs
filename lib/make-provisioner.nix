{nixpkgs}: s:
nixpkgs.lib.nixosSystem {
  modules = [
    ../modules/default.nix
    ../profiles/defaults.nix
    ../profiles/default-net.nix
    ../profiles/packaging/iso.nix
    ../roles/provisioner.nix
    ({pkgs, ...}: {
      networking.hostName = "provisioner";
      nixpkgs.localSystem = s.config.nixpkgs.localSystem;
      users = s.config.users;
      environment.systemPackages = [
        (pkgs.callPackage ./provision.nix s.config)
      ];
    })
  ];
  specialArgs = attrs;
}
