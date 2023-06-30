{ config, pkgs, nixpkgs, lib, joeos, private, ... }:
let
  privData = import private;
in
{
  imports = [
    (nixpkgs + "/nixos/modules/profiles/base.nix")
    (nixpkgs + "/nixos/modules/profiles/minimal.nix")
    (nixpkgs + "/nixos/modules/hardware/cpu/amd-microcode.nix")
    joeos.nixosModules.default
  ];

  config =
    let
      # Allow legacy renegotiations. My ISP requires this...
      wpa_supplicant_legacy_connect = final: prev: {
        wpa_supplicant = prev.wpa_supplicant.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            (prev.fetchpatch {
              url = "https://src.fedoraproject.org/rpms/wpa_supplicant/raw/rawhide/f/wpa_supplicant-allow-legacy-renegotiation.patch";
              hash = "sha256-wQ0Vnn3MG7AztWDcvEurYhlzvhXyIrxVoFyusJ25doc=";
            })
          ];
        });
      };
    in
    {
      networking.hostName = "router";

      boot.kernelParams = [ "root=/dev/disk/by-partlabel/root" "nomodeset" "boot.shell_on_fail" ];
      boot.supportedFilesystems = [ "btrfs" "vfat" ];
      boot.initrd.supportedFilesystems = [ "btrfs" "vfat" ];
      boot.initrd.availableKernelModules = [ "btrfs" "vfat" ];

      # TODO: fallback to uki
      # system.boot.loader.uki.enable = true;
      system.boot.loader.simple-systemd.enable = true;

      nixpkgs.overlays = [
        wpa_supplicant_legacy_connect
      ];

      nix.registry = {
        "nixpkgs" = {
          from = {
            type = "indirect";
            id = "nixpkgs";
          };
          to = {
            type = "github";
            owner = "NixOS";
            repo = "nixpkgs";
            ref = "nixpkgs-unstable";
          };
        };
      };

      environment = {
        systemPackages = [
          # TODO: sort this
          pkgs.btrfs-progs
          pkgs.dig
          pkgs.efibootmgr
          pkgs.git
          pkgs.neovim
          pkgs.parted
          pkgs.socat
          pkgs.tmux
          pkgs.sdparm
          pkgs.hdparm
          pkgs.smartmontools
          pkgs.pciutils
          pkgs.usbutils
          pkgs.unzip
          pkgs.zip
          pkgs.openssl
          pkgs.mtr
        ];
      };

      fileSystems = {
        "/" = {
          device = "/dev/disk/by-partlabel/root";
          options = [ "compress=zstd" ];
        };
        "/boot" = {
          device = "/dev/disk/by-partlabel/boot";
        };
        "/var" = {
          device = "/dev/disk/by-partlabel/root";
          options = [ "compress=zstd" "subvol=var" ];
        };
        "/nix" = {
          device = "/dev/disk/by-partlabel/root";
          options = [ "compress=zstd" "subvol=nix" ];
        };
        "/home" = {
          device = "/dev/disk/by-partlabel/root";
          options = [ "compress=zstd" "subvol=home" ];
        };
      };

      joeos = {
        users = {
          joe = {
            description = "Joe Hirschfeld";
            allowSudo = true;
            inherit (privData.joe) hashedPassword sshKeys;
          };
        };

        server = true;
        sshServer = true;

        network = {
          enable = true;
          interfaces =
            let
              defaultRouter = {
                requiredForOnline = false;
              };
              # use cloudflare for dns for now
              internalDns = {
                ipv4Router.dhcp.dns = [ "_server_address" ];
                ipv6Router.sendRa.dns = [ "_link_local" ];
              };
              cloudflareDns = {
                ipv4Router.dhcp.dns = [ "1.1.1.1" "1.0.0.1" ];
                ipv6Router.sendRa.dns = [ "2606:4700:4700::1111" "2606:4700:4700::1001" ];
              };
              internalAuthoritativeRouter = subnetId: defaultRouter // {
                address = [ "192.168.${toString subnetId}.1/24" ];
                ipv4Router.dhcp = {
                  enable = true;
                };
                ipv6Router = {
                  sendRa = {
                    enable = true;
                  };
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
                  # blackhole = true;
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
                          ipv6Router = {
                            prefixDelegation = {
                              subnetId = 7;
                              enable = true;
                            };
                          };
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
                        } // defaultRouter;
                    };
                  };
                };
              };

              internalNet = {
                match.path = "pci-0000:03:00.1";
                network = (internalAuthoritativeRouter 2) // internalDns;
              };

              homelabNet = {
                match.path = "pci-0000:04:00.0";
                network = (internalAuthoritativeRouter 1) // {
                  mtu = 9000;
                } // internalDns;
              };
              lhAHNet = {
                match.path = "pci-0000:04:00.1";
                network = (internalAuthoritativeRouter 4) // cloudflareDns;
              };
            };
        };
      };

      # also enable ipv4 & ipv6 forwarding somewhere
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = true;
        "net.ipv6.conf.all.forwarding" = true;
      };

      # the actual nftables ruleset
      # TODO: There is something messed up with the ipv6 tracking here - seems like conntrack isn't keeping up?
      networking.nftables.ruleset = ''
        flush ruleset

        table inet global {
          chain inbound_internet {

            # just allow ipv6, for whatever reason we aren't tracking it right
            meta protocol ip6 accept
            
            # drop any opportunistic DNS resolution from the outside - TODO should not be two rules
            # TODO not stopping external queriers
            udp dport 53 drop
            tcp dport 53 drop

            # Let pings in at a ratelimit
            icmp type echo-request limit rate 5/second accept
            icmpv6 type echo-request limit rate 5/second accept

            # also allow opportunistic router & neighbor solicitations
            icmpv6 type { nd-router-advert, nd-neighbor-advert, nd-redirect } accept

            # otherwise, ignore
          }

          chain inbound_private {
            # just allow ipv6, for whatever reason we aren't tracking it right
            meta protocol ip6 accept

            # always allow unbounded icmp internally
            icmp type echo-request accept
            icmpv6 type {echo-request, nd-router-solicit, nd-neighbor-solicit, mld-listener-query } accept

            # allow DHCP on v4
            meta nfproto ipv4 udp dport 67 accept

            # allow SSH
            tcp dport 22 accept

            # allow dns
            udp dport 53 accept
            tcp dport 53 accept

            # all else gets dropped inbound
          }

          chain inbound_isolate {
            # just allow ipv6, for whatever reason we aren't tracking it right
            meta protocol ip6 accept

            # we only allow DHCP to ourselves locally
            meta nfproto ipv4 udp dport 67 accept

            # otherwise, drop anything coming to us. should have gone to the forward chain
          }

          chain inbound {
            type filter hook input priority 0; policy drop;

            # Allow traffic from established & related packets, drop invalid
            ct state vmap { established : accept, related : accept, invalid : drop }

            # Defer further eval to other inbound chains
            iifname vmap { lo : accept, externalVlanNet : jump inbound_internet, internalNet : jump inbound_private, homelabNet : jump inbound_private , lhAHNet : jump inbound_isolate } accept

            # Everything else is dropped
          }

          chain forward {
            type filter hook forward priority 0; policy drop;

            # just allow ipv6, for whatever reason we aren't tracking it right
            meta protocol ip6 accept

            # Allow traffic from established & related packets, drop invalid
            ct state vmap { established : accept, related : accept, invalid : drop }

            # Allow anyone internally to be forwarded wherever
            iifname internalNet accept

            # lhAH can route out, but not anywhere inside
            iifname lhAHNet oifname externalVlanNet accept
            iifname lhAHNet drop
          
            # all else gets dropped. shouldn't be soliciting 
          }

          chain postrouting {
            type nat hook postrouting priority 100; policy accept;

            # masquerade anything heading out of ipv4
            meta nfproto ipv4 meta oifname externalVlanNet masquerade
          }
        }
      '';
      # don't use resolved
      services.resolved.enable = false;
      services.unbound = {
        # we want unbound to handle our DNS
        enable = true;
        settings = {
          server = {
            # answer from anywhere (this is controlled via nftables)
            # this handles cases where we may be in a confusing routing situation
            interface = [ "internalNet" "lhAHNet" "homelabNet" ];
            interface-automatic = true;
            access-control = [ "0.0.0.0/0 allow" "::0/0 allow" ];
          };
        };
      };
    };
}
