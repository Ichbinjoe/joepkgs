{config, lib, ...}:
{
  options = {
    dn42Ca = lib.mkEnableOption "dn42Ca";
  };

  config = lib.mkIf config.dn42Ca {
    security.pki.certificateFiles = [./burble-ca.crt ./dn42-root.crt];
  };
}
