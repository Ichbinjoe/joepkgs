{}: {
  imports = [
    ../profiles/base.nix
    ../profiles/defaults.nix
  ];

  # enable the kubelet
  services.kubernetes.kubelet = {
    enable = true;
  };

  # enable the proxy
  services.kubernetes.proxy = {
    enable = true;
  };

  services.podman = {
    enable = true;
  };

  services.openssh = {
    enable = true;
  };
}
