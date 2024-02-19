{config, ...}: {
  dn42.peers."dn42_fmepnet" = {
    wg = {
      remoteEndpoint = "fergus.fmepnet.org:52823";
      localInterface = "internet";
      localPort = 50002;
      peerPublicKey = "p+vuFQshD+xQDXvx3XLEYPJbjHdw4VaeszSgzNwDJAI=";
    };

    linkIp4 = [
      {
        local = config.dn42.ip4Self;
        peer = "172.20.159.228";
      }
    ];

    linkIp6 = [
      {
        local = "fe80::100";
        peer = "fe80::1234";
      }
    ];

    bgp."dn42_fmepnet" = {
      peerAs = 4242423703;
      template = "fmepnet";
      sourceAddress = "fe80::100";
      peerAddress = "fe80::1234";
    };
  };
}
