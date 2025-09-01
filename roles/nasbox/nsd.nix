{lib, ...}: let
  primaryIp = "fde7:76fd:7444:eeee::ffff";
in {
  dn42.addrs = ["${primaryIp}/128"];
  services.nsdjoe = let
    upstreamIds = [
      234
      237
      232
      231
      240
      233
      236
    ];
    upstreamIps = map (id: "fde7:76fd:7444:aaaa::${toString id}") upstreamIds;
    provideXfrs = lib.concatStringsSep "\n" (map (ip: "  provide-xfr: ${ip} NOKEY") upstreamIps);
    notifys = lib.concatStringsSep "\n" (map (ip: "  notify: ${ip} NOKEY") upstreamIps);
  in {
    enable = true;
    config =
      ''
        server:
          server-count: 1
          username: nsd
          ip-address: ${primaryIp}
          zonelistfile: /var/lib/nsd/zone.list
          pidfile: /var/run/nsd.pid
          xfrdfile: /var/lib/nsd/xfrd.state


        remote-control:
          control-enable: yes
          server-key-file: /var/lib/nsd/nsd_server.key
          server-cert-file: /var/lib/nsd/nsd_server.pem
          control-key-file: /var/lib/nsd/nsd_control.key
          control-cert-file: /var/lib/nsd/nsd_control.pem

        zone:
          name: "catalog.ibj"
          catalog: producer

          store-ixfr: yes
          allow-query: 0.0.0.0/0 BLOCKED
          allow-query: ::/0 BLOCKED
          outgoing-interface: ${primaryIp}
      ''
      + provideXfrs
      + notifys
      + ''

        pattern:
          name: standard
          zonefile: /var/lib/nsd/zones/%s.signed
          outgoing-interface: ${primaryIp}
          catalog-producer-zone: "catalog.ibj"
      ''
      + provideXfrs
      + notifys;
  };
}
