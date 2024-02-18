{pkgs}: {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
  ];

  # Coordinators have two networks: the management network and the etcd peer network
  systemd.network.netdevs = {
    "01-management" = {
      netdevConfig = {
        Kind = "vlan";
        Name = "management";
      };
      vlanConfig = {
        Id = 100;
      };
    };
    "01-etcdpeer" = {
      netdevConfig = {
        Kind = "vlan";
        Name = "etcdpeer";
      };
      vlanConfig = {
        Id = 101;
      };
    };
  };

  systemd.network.networks = {
    "99-default" = {
      vlans = ["management" "etcdpeer"];
    };
  };

  services.openssh = {
    enable = true;
  };

  # Each coordinator contains a etcd and kubeapi
  # The etcd is only locally accessible w/ the kubeapi
  services.etcd = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    etcd # TODO
  ];

  services.kubernetes.apiserver = {
    enable = true;
  };
}
