{lib}:
with lib; {
  base64 =
    (types.strMatching ''[A-Za-z0-9\+\/]+=*'')
    // {
      name = "base64String";
      description = "base64 string";
    };

  ip4Addr =
    (types.strMatching ''((25[0-5]|(2[0-4]|1[0-9]|[1-9])[0-9])\.?){4}'')
    // {
      name = "ip4Addr";
      description = "ip4 address";
    };

  ip6Addr =
    (types.strMatching ''[0-9a-fA-F:.]+'')
    // {
      name = "ip6Addr";
      description = "ip6 address";
    };

  ip4Net =
    (types.strMatching ''((25[0-5]|(2[0-4]|1[0-9]|[1-9])[0-9])\.?){4}/[0-9]{1,2}'')
    // {
      name = "ip4Net";
      description = "ip4 network";
    };

  ip6Net =
    (types.strMatching ''[0-9a-fA-F:.]{1,253}/[0-9]{1,3}'')
    // {
      name = "ip6Net";
      description = "ip6 network";
    };

  netEndpoint =
    (types.strMatching ''[a-zA-Z0-9-:.]{1,253}'')
    // {
      name = "networkEndpoint";
      description = "network endpoint";
    };

  netPortEndpoint =
    (types.strMatching ''\[?[a-zA-Z0-9-:.]{1,253}]?:[0-9]{1,5}'')
    // {
      name = "networkPortEndpoint";
      description = "network port endpoint";
    };
}
