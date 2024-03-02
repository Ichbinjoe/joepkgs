{
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    sqlite
    pdns
  ];

  services.powerdns.enable = true;
  services.powerdns.extraConfig = ''
    launch=gsqlite3
    gsqlite3-database=/var/lib/powerdns/pdns.sqlite3
    gsqlite3-dnssec
    local-address=172.20.170.224 fde7:76fd:7444:ffff::53
  '';
}
