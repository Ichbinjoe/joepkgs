{ nixpkgs, default, provisioning, broadcom-firmware }: with nixpkgs.lib.kernel;
{ config, ... }:
{
  imports = [
    default
    provisioning
  ];

  config = {
    boot.kernelPatches = [{
      name = "disable-strict-devmem";
      patch = null;
      extraStructuredConfig = {
        STRICT_DEVMEM = no;
        IO_STRICT_DEVMEM = option no;
      };
    }];

    environment.systemPackages = [
      broadcom-firmware.lnxfwupd
    ];
    
    # Allow the user to log in as root without a password.
    users.users.root.password = "password";
    users.users.joe.password = "password";
    users.users.joe.isNormalUser = true;
    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };

    joeos = {
      users = {
        joe = {
          description = "Joe";
          allowSudo = true;
        };
      };
      sshServer = false;
    };
  };
}
