# The only distinction between this wpa_supplicant and the normal
# wpa_supplicant is that this does purposefully dumb stuff such that we can
# authenticate it with ATT's handshake BS
{
  pkgs,
  # wpa_supplicant we are basing ourselves off of - we make ourselves distinct
  # since we are going to purposefully make wpa_supplicant less secure
  wpa_supplicant,
}:
wpa_supplicant.overrideAttrs (old: {
  # ATT uses some ancient renegotiation which isn't really supported by anyone anymore
  patches =
    (old.patches or [])
    ++ [
      (pkgs.fetchpatch {
        url = "https://src.fedoraproject.org/rpms/wpa_supplicant/raw/rawhide/f/wpa_supplicant-allow-legacy-renegotiation.patch";
        hash = "sha256-wQ0Vnn3MG7AztWDcvEurYhlzvhXyIrxVoFyusJ25doc=";
      })
    ];

  postInstall = ''
    ${old.postInstall or ""}
    cd $out
    for fil in $(find ./etc/systemd/system/ -type f); do
      echo "$fil"
      to=$(echo "$fil" | sed 's/wpa_supplicant/wpa_supplicant_att/')
      echo "$to"
      mv "$fil" "$to"
    done
    ls ./etc/systemd/system/
  '';
})
