{pkgs, ...}: {
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
    api=yes
    api-key=$scrypt$ln=10,p=1,r=8$xSd2/otVBUunVFeaI50a1A==$v5oqa0YvoT4r1pQLe68XNRjxvU4FZlsBn8BYPU9WiRc=
    webserver-address=0.0.0.0
    webserver-allow-from=192.168.2.0/24
  '';
}
