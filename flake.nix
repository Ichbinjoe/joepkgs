{
  description = "A collection of modules specific for JoeOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    private.url = "joeprivate";
    tempmonitor.url = "tempmonitor";
  };

  outputs = {nixpkgs, ...} @ attrs:
    with nixpkgs.lib; let
      systems = import ./systems.nix attrs;
      defaultSystems = ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"];
      systemPkgs = system: let
        legacy = nixpkgs.legacyPackages.${system};
      in
        legacy; # // (map (pkg: legacy.callPackage { }) (import ./pkgs/all-packages.nix));
      eachSystem = f: foldAttrs mergeAttrs {} (map (s: {"${s}" = f s;}) defaultSystems);
    in rec {
      formatter = eachSystem (s: (systemPkgs s).alejandra);

      nixosConfigurations = {
        "buildbox-x64" = systems.buildbox-x64;
        "buildbox-rpi" = systems.buildbox-rpi;
        "buildbox-rpi-cross" = systems.buildbox-rpi-cross;
        "homerouter" = systems.homerouter;
        "printerpi" = systems.printerpi;
        "homeautomation" = systems.homeautomation;
        "brewmonitor" = systems.brewmonitor;
        "jellyfin" = systems.jellyfin;
        "livebox" = systems.livebox;
        "bonniebox" = systems.bonniebox;
        "bassbox" = systems.bassbox;
        "joebox" = systems.joebox;
        "lucasbox" = systems.lucasbox;
        "nasbox" = systems.nasbox;
      };

      packages = eachSystem (s: mapAttrs (variant: variant-config: variant-config.config.system.build.transferScripts (systemPkgs s)) nixosConfigurations);
    };
}
