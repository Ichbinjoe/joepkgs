{...}: {
  dn42Expose.syncthing = {
    port = 8384;
    addr = "fde7:76fd:7444:eeee::105";
    reqHeaders = ["Host localhost"];
    allowlist = "fde7:76fd:7444::/48";
  };

  services.syncthing = {
    enable = true;
    guiAddress = "[::1]:8384";
    dataDir = "/zpool/syncthing";
  };
}
