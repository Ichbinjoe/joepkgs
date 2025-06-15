{
  pkgs,
  stdenv,
  lib,
}: rec {
  bm-fw-upgrade-utility-tar-gz = pkgs.requireFile {
    name = "Broadcom_NX1_Linux_FW_Upgrade_Utility_lnxfwupg-225.0.1.tar.gz";
    sha256 = "Mr2BcYbhuAjDWuQcC8jXI/wiqH7PzeHNQUXRS5dHKi8=";
    url = "";
  };

  bm-fw-upgrade-utility = stdenv.mkDerivation rec {
    name = "bm-fw-upgrade-utility";
    version = "225.0.1";
    # We need to refer to this in this way since this is non-redistributable
    src = bm-fw-upgrade-utility-tar-gz;

    unpackCmd = "tar -zxvf $curSrc";
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r x86_64/* "$out/"

      runHook postInstall
    '';

    meta = {
      description = "Broadcom firmware update utility package";
      license = lib.licenses.unfree;
      platforms = lib.platforms.linux;
    };
  };

  bmapilnx = stdenv.mkDerivation rec {
    name = "bmapilnx";
    version = "224.0.2";

    src = [(bm-fw-upgrade-utility + "/bmapilnx-${version}-0.x86_64.rpm")];

    buildInputs = [
      pkgs.pciutils
    ];

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.rpmextract
    ];

    unpackCmd = "rpmextract $curSrc";

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r . $out
      ln -s "$out/lib64/libbmapi_x64.so.6-${version}" "$out/lib64/libbmapi_x64.so.6"

      runHook postInstall
    '';

    meta = {
      description = "Broadcom API library";
      license = lib.licenses.unfree;
      platforms = lib.platforms.linux;
    };
  };

  lnxfwupd = stdenv.mkDerivation rec {
    name = "lnxfwupd";
    version = "225.0.1";

    src = [(bm-fw-upgrade-utility + "/lnxfwupg-${version}-1.x86_64.rpm")];

    buildInputs = [
      bmapilnx
      pkgs.stdenv.cc.cc.lib
    ];

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.rpmextract
    ];

    unpackCmd = "rpmextract $curSrc";

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r . "$out"
      mv $out/sbin $out/bin

      runHook postInstall
    '';

    meta = {
      description = "Broadcom Firmware utility";
      license = lib.licenses.unfree;
      platforms = lib.platforms.linux;
    };
  };
}
