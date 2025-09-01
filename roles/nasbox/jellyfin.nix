{...}: {
  dn42Expose.jellyfin = {
    port = 8096;
    addr = "fde7:76fd:7444:eeee::106";
    allowlist = "fde7:76fd:7444::/48";
  };

  services.jellyfin = {
    enable = true;
    openFirewall = false;
  };
}
