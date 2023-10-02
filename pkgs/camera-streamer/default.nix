{
  lib,
  stdenv,
  fetchFromGitHub,
  ffmpeg-headless,
  git,
  libcamera,
  libdatachannel,
  live555,
  nlohmann_json,
  pkg-config,
  unixtools,
  v4l-utils,
  which,
}:
stdenv.mkDerivation rec {
  pname = "camera-streamer";
  version = "v0.2.8";

  src = fetchFromGitHub {
    owner = "ayufan";
    repo = "camera-streamer";
    rev = version;
    fetchSubmodules = true;
    # necessary for version.h generation
    leaveDotGit = true;
    hash = "sha256-8vV8BMFoDeh22I1/qxk6zttJROaD/lrThBxXHZSPpT4=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    git
    pkg-config
    unixtools.xxd
    v4l-utils
    which
  ];

  buildInputs = [
    ffmpeg-headless
    libcamera
    libdatachannel.dev
    live555
    nlohmann_json
  ];

  patches = [
    ./0001-Correctly-catch-return-errors-within-device-links.c.patch
    ./0002-Correct-format-string-for-STREAM_PART.patch
    ./0003-Fix-inconsistencies-in-the-generation-of-version.h.patch
    ./0004-Explicitly-ignore-the-return-value-of-v4l2-ctl-list-.patch
    ./0005-Respect-asprintf-return.patch
    ./0006-Use-system-libdatachannel-instead-of-the-packaged-ve.patch
  ];

  preInstall = ''
    mkdir -p ${placeholder "out"}/bin/
  '';

  installFlags = [
    "DESTDIR=${placeholder "out"}"
    "PREFIX="
  ];

  postInstall = ''
    mkdir -p "${placeholder "out"}/lib/systemd/system/"
    cp service/* "${placeholder "out"}/lib/systemd/system/"
    sed -i\'\' -e 's,/usr/local/bin/camera-streamer,${placeholder "out"}/bin/camera-streamer,g' -e 's,/usr/bin/v4l2-ctl,${v4l-utils}/bin/v4l2-ctl,g' ${placeholder "out"}/lib/systemd/system/*
  '';

  enableParallelBuilding = true;

  meta = with lib; {
    homepage = "https://github.com/ayufan/camera-streamer";
    description = "High-performance low-latency camera streamer for Raspberry PI's";
    license = licenses.gpl3Only;
    platforms = ["aarch64-linux"];
  };
}
