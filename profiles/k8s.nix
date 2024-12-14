{pkgs, ...}: let
  json = pkgs.formats.toml {};
  toml = pkgs.formats.toml {};
  yaml = pkgs.formats.yaml {};

  cni-crio-bridge = json.generate "10-crio-bridge.conflist" {
    cniVersion = "1.0.0";
    name = "crio";
    plugins = [
      {
        type = "bridge";
        bridge = "cni0";
        isGateway = true;
        ipMasq = true;
        hairpinMode = true;
        ipam = {
          type = "host-local";
          routes = [
            {dst = "0.0.0.0/0";}
            {dst = "::/0";}
          ];
          ranges = [
            {subnet = "192.168.200.0/24";}
            {subnet = "fde7:76fd:7444:fff0::/64";}
          ];
        };
      }
    ];
  };

  crioSocket = "/var/run/crio/crio.sock";
  crioConfig = toml.generate "crio.conf" {
    storage_driver = "overlay";

    crio.api = {
      listen = crioSocket;
    };
    crio.runtime = {
      default_runtime = "${pkgs.crun}/bin/crun";
      pinns_path = "${pkgs.cri-o}/bin/pinns";
      timezone = "Local";
    };
  };

  kubeletConfig = yaml.generate "kubelet.yaml" {
    apiVersion = "kubelet.config.k8s.io/v1beta1";
    kind = "KubeletConfiguration";
    containerRuntimeEndpoint = crioSocket;
  };
in {
  imports = [
    ./profiles/base.nix
    ./profiles/defaults.nix
  ];

  environment.systemPackages = with pkgs; [
    crun
    cri-tools
  ];

  etc."crio/crio.conf".source = crioConfig;

  systemd.services.crio = {
    description = "CRI-O";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "notify";
      ExecStart = "${pkgs.cri-o}/bin/crio";
      ExecReload = "/bin/kill -s HUP $MAINPID";
      TasksMax = "infinity";
      LimitNOFILE = "1048576";
      LimitNPROC = "1048576";
      LimitCORE = "infinity";
      OOMScoreAdjust = "-999";
      TimeoutStartSec = "0";
      Restart = "on-abnormal";
    };

    restartTriggers = [crioConfig];
  };

  # We home-spin our k8s here since we use a special & skinny setup
  systemd.services.kubelet = {
    description = "K8s Kubelet Service";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "1000ms";
      ExecStart = ''
        ${pkgs.k8s.kubelet}/bin/kubelet
          --config ${kubeletConfig}
      '';
    };
  };
}
