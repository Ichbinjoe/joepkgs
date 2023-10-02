{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  wiredWpaOpts = {name, ...}: {
    options = {
      interface = mkOption {
        type = types.str;
        description = "name of the interface to generate the wpa_supplicant config for";
      };
      caCert = mkOption {
        type = types.path;
        description = "System path of wpa_supplicant-wired CA certificate";
      };
      clientCert = mkOption {
        type = types.path;
        description = "System path of wpa_supplicant-wired client certificate";
      };
      clientKey = mkOption {
        type = types.path;
        description = "System path of wpa_supplicant-wired client key";
      };
      identity = mkOption {
        type = types.str;
        description = "wpa_supplicant interface identity";
      };
    };
    config = {
      interface = mkDefault name;
    };
  };
in {
  options.wpa_supplicant_att = mkOption {
    description = "wpa_supplicant att wired interfaces";
    type = types.attrsOf (types.submodule wiredWpaOpts);
    default = {};
  };
  config = let
    makeWpaConfigForIface = i: {
      name = "wpa_supplicant/wpa_supplicant-wired-${i.interface}.conf";
      value = {
        text = ''
          openssl_ciphers=DEFAULT@SECLEVEL=0
          eapol_version=1
          ap_scan=0
          fast_reauth=1
          network={
              ca_cert="${i.caCert}"
              client_cert="${i.clientCert}"
              private_key="${i.clientKey}"
              eap=TLS
              eapol_flags=0
              identity="${i.identity}"
              key_mgmt=IEEE8021X
              phase1="allow_canned_success=1"
          }
        '';
      };
    };
    makeWpaServiceForIface = i: {
      name = "wpa_supplicant_att-wired@${i.interface}";
      value = {
        overrideStrategy = "asDropin";
        wantedBy = ["multi-user.target"];
      };
    };
  in
    mkIf (config.wpa_supplicant_att != {}) {
      # add the wpa_supplicant package to systemd if we have a config
      systemd.packages = [(pkgs.callPackage ../pkgs/wpa_supplicant_att {})];
      # add configurations for each interface we need to generate
      environment.etc = listToAttrs (map makeWpaConfigForIface (attrValues config.wpa_supplicant_att));
      # add a systemd service for each interface and enable it
      systemd.services = listToAttrs (map makeWpaServiceForIface (attrValues config.wpa_supplicant_att));
    };
}
