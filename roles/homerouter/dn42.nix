{lib, ...}: {
  imports = lib.filesystem.listFilesRecursive ./peers;
  dn42 = {
    enable = true;
    asNumber = 4242420157;
    ip4Self = "172.20.170.224";
    ip6Self = "fde7:76fd:7444:ffff::1";
    ip4SelfNet = "172.20.170.224/27";
    ip6SelfNet = "fde7:76fd:7444::/48";
    ip4Advertisements = ''
      route 172.20.170.224/29 via lo;
    '';
    ip6Advertisements = ''
      route fde7:76fd:7444:fffe::/64 via lan;
      route fde7:76fd:7444:ffff::/64 via lo;
    '';
  };
}
