{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
  ];

  config = {
    services.openssh.enable = true;

    users.users.root = {
      password = "password";
      shell = pkgs.bashInteractive;
    };
  };
}
