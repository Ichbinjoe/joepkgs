{
  nixpkgs,
  lib,
  config,
  ...
} @ attrs:
with lib; {
  system.build.provisioner = nixpkgs.lib.nixosSystem {
    modules = [
      ./default.nix
      ../profiles/defaults.nix
      ../profiles/default-net.nix
      ../profiles/packaging/iso.nix
      ../roles/provisioner.nix
      {
        networking.hostName = "provisioner";
        nixpkgs = config.nixpkgs;
        users = config.users;
        environment.systemPackages = [
          (pkgs.callPackage ../lib/provision.nix config)
        ];
      }
    ];
    specialArgs = attrs;
  };
}
