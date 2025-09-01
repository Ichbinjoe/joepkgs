{config, ...}: {
  dn42Expose.paperless = {
    port = config.services.paperless.port;
    addr = "fde7:76fd:7444:eeee::103";
  };

  services.paperless = {
    enable = true;
    address = "::1";
    dataDir = "/zpool/paperless";
    database.createLocally = true;
    settings = {
      PAPERLESS_USE_X_FORWARD_HOST = true;
      PAPERLESS_USE_X_FORWARD_PORT = true;
      PAPERLESS_OCR_ROTATE_PAGES_THRESHOLD = "6";
    };
  };
}
