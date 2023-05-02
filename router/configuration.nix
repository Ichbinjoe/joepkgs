{ config, pkgs, nixpkgs, lib, joeos, private, ... }:
let
  privData = import private;
in
{
  imports = [
    joeos.nixosModules.default
    joeos.nixosModules.network
  ];

  config.boot.loader = {
    grub.enable = false;
    systemd-boot.enable = true;
  };

  config.environment = {
    systemPackages = [
      pkgs.btrfs-progs
    ];
  };

  config.fileSystems = {
    "/" = {
      label = "root";
      options = [ "compress=zstd" ];
    };
    "/boot" = {
      label = "boot";
    };
    "/var" = {
      label = "root";
      options = [ "compress=zstd" "subvol=var" ];
    };
    "/nix" = {
      label = "root";
      options = [ "compress=zstd" "subvol=nix" ];
    };
    "/home" = {
      label = "root";
      options = [ "compress=zstd" "subvol=home" ];
    };
  };

  config.joeos = {
    users = {
      joe = {
        description = "Joe Hirschfeld";
        allowSudo = true;
        inherit (privData.joe);
      };
    };

    server = true;
    sshServer = true;

    network = {
      enable = true;
      interfaces =
        let
          defaultRouter = {
            ipv4Router = {
              forward = true;
            };
            ipv6Router = {
              forward = true;
            };
          };
          internalAuthoritativeRouter = subnetId: defaultRouter // {
            address = [ "192.168.${toString subnetId}.1/24" ];
            ipv4Router.dhcp.enable = true;
            ipv6Router = {
              sendRa = true;
              prefixDelegation = {
                inherit subnetId;
                enable = true;
              };
            };
          };
        in
        {
          externalNet = {
            # this is our network to the outside world. it has a very specific configuration
            match.path = "pci-0000:03:00.0";
            macAddress = privData.net.extern.mac;
            wiredWpaSupplicant = {
              enable = true;
              caCert = privData.net.extern.caPem;
              clientCert = privData.net.extern.clientPem;
              clientKey = privData.net.extern.keyPem;
            };
            network = {
              blackhole = true;
              vlans = {
                externalVlanNet = {
                  id = 0;
                  network =
                    let
                      duid = {
                        raw = privData.net.extern.duid;
                      };
                    in
                    {
                      dhcpv4Client = {
                        inherit duid;
                        enable = true;
                        sendHostname = false;
                        useDns = false;
                      };
                      dhcpv6Client = {
                        inherit duid;
                        enable = true;
                        useDns = false;
                        prefixDelegationHint = "::/60";
                      };
                      # TODO: This control sucks and should be controlled by nftables
                      ipv4Router.masquerade = true;
                    } // defaultRouter;
                };
              };
            };
          };

          internalNet = {
            match.path = "pci-0000:03:00.1";
            network = internalAuthoritativeRouter 2;
          };

          homelabNet = {
            match.path = "pci-0000:04:00.0";
            network = (internalAuthoritativeRouter 1) // {
              mtu = 9000;
            };
          };
          lhAHNet = {
            match.path = "pci-0000:04:00.1";
            network = internalAuthoritativeRouter 4;
          };
        };
    };
  };
}
