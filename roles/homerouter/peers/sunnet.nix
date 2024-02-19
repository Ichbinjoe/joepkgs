{config, ...}: {
  dn42.peers."dn42_sunnet" = {
    wg = {
      remoteEndpoint = "v6.sjc1-us.dn42.6700.cc:20157";
      localInterface = "internet";
      localPort = 53088;
      peerPublicKey = "G/ggwlVSy5jKWFlJM01hxcWnL8VDXsD5EXZ/S47SmhM=";
    };

    linkIp4 = [
      {
        local = config.dn42.ip4Self;
        peer = "172.21.100.191";
      }
    ];

    linkIp6 = [
      {
        local = "fe80::abcd";
        peer = "fe80::3088:191";
      }
    ];

    bgp."dn42_sunnet" = {
      peerAs = 4242423088;
      sourceAddress = "fe80::abcd";
      peerAddress = "fe80::3088:191";
    };
  };
}
