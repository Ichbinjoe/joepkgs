{
  stdenv,
  lib,
  fetchFromGitHub,
  linuxPackages,
  kernel ? linuxPackages.kernel,
  kmod,
}:
stdenv.mkDerivation rec {
  pname = "ugreen-leds";
  version = "0.3";

  src = fetchFromGitHub {
    owner = "miskcoo";
    repo = "ugreen_leds_controller";
    rev = "v${version}";
    hash = "sha256-eSTOUHs4y6n4cacpjQAp4JIfyu40aBJEMsvuCN6RFZc=";
  };

  sourceRoot = "source/kmod";
  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=$(out)"
  ];

  meta = {
    description = "A kernel module to trigger leds on the front of UGREEN NAS";
    homepage = "https://github.com/miskcoo/ugreen_leds_controller";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
