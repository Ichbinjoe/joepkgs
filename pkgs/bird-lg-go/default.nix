{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "bird-lg-go";
  version = "v1.3.8";

  src = fetchFromGitHub {
    owner = "xddxdd";
    repo = "bird-lg-go";
    rev = version;
    hash = "sha256-8vV8BMFoDeh22I1/qxk6zttJROaD/lrThBxXHZSPpT4=";
  };

  strictDeps = true;

  modRoot = "./frontend/";

  meta = with lib; {
    homepage = "https://github.com/xddxdd/bird-lg-go";
    description = "BIRD looking glass in Go, for better maintainability, easier deployment & smaller memory footprint";
    license = licenses.gpl3Only;
    platforms = ["aarch64-linux"];
  };
}
