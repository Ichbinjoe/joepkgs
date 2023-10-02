{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  # don't use resolved
  services = {
    resolved.enable = false;
    unbound = {
      # we want unbound to handle our DNS
      enable = true;
      settings = {
        server = {
          # answer from anywhere (this is controlled via nftables)
          # this handles cases where we may be in a confusing routing situation
          interface = ["internal" "untrustedap"];
          interface-automatic = true;
          access-control = ["0.0.0.0/0 allow" "::0/0 allow"];
        };
      };
    };
  };
}
