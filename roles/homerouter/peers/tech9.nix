{config, ...}: {
  dn42.peers."dn42_tech9" = {
    wg = {
      remoteEndpoint = "us-phx03.dn42.tech9.io:56610";
      localInterface = "internet";
      localPort = 50001;
      peerPublicKey = "bRkI8aGjwwgm1I6WeqsfL6jrxu72ifs3xSaTLCY22mw=";
    };

    linkIp4 = [
      {
        local = config.dn42.ip4Self;
        peer = "172.23.220.178";
      }
    ];

    linkIp6 = [
      {
        local = "fe80::100";
        peer = "fe80::1588";
      }
    ];

    bgp."dn42_tech9" = {
      peerAs = 4242421588;
      sourceAddress = "fe80::100";
      peerAddress = "fe80::1588";
    };
  };
}
