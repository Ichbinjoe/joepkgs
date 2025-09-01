{...}: {
  dn42Expose.birdlg = {
    port = 8080;
    addr = "fde7:76fd:7444:eeee::100";
  };

  services.bird-lg.frontend = {
    enable = true;
    listenAddress = "[::1]:8080";
    netSpecificMode = "dn42";
    dnsInterface = "asn.dn42";
    domain = "joe.dn42";
    navbar.brand = "Joenet";
    servers = [
      "sjc01"
      "sea01"
      "chi01"
      "tyo01"
      "nyc01"
      "nyc02"
      "ire01"
      "mbi01"
      "joebox"
    ];
    nameFilter = "^(device|kernel|static|joenet_babel).*";
    proxyPort = 9999;
    whois = "fd42:d42:d42:43::1";
  };
}
