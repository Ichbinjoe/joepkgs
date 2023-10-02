{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
    ../profiles/default-net.nix
  ];

  config = {
    services.openssh.enable = true;
  };
}
