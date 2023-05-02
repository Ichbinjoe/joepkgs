{
  description = "Router flake which produces various routery things";

  inputs = {
    joeos.url = "../joeos";
    private = {
      url = "path:./private";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, joeos, ... }@attrs: rec {

    packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

    nixosConfigurations.router = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [ ./configuration.nix ];
    };
    
    packages.x86_64-linux."router-toplevel" = nixosConfigurations.router.config.system.build.toplevel;
    packages.x86_64-linux."router-disk-image" =
      nixosConfigurations.router.config.system.build.diskImage;
  };
}
