{
  description = "Router flake which produces various routery things";

  inputs = {
    joeos.url = "flake:joeos";
    private = {
      url = "path:./private";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, joeos, private, ... }@attrs: 
  let
    privData = import private;

    router = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [ ./configuration.nix ];
    };

    router-deploy-module = {
      environment.systemPackages = [
        router.config.system.build.bootstrapScript
      ];

      users.users.root = {
        inherit (privData.joe) hashedPassword;
        openssh.authorizedKeys.keys = privData.joe.sshKeys;
      };
    };

    router-bootstrap = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [
        joeos.nixosModules.deploy
        router-deploy-module
      ];
    };
  in
  {
    nixosConfigurations.router = router;
    nixosConfigurations.router-bootstrap = router-bootstrap;

    packages.x86_64-linux."router-toplevel" = router.config.system.build.toplevel;

    packages.x86_64-linux."router-bootstrap-iso" = router-bootstrap.config.system.build.isoImage;
  };
}
