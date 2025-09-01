{...}: {
  services.paperless = {
    enable = true;
    dataDir = "/zpool/paperless";
    database.createLocally = true;
    settings = {
      PAPERLESS_USE_X_FORWARD_HOST = true;
      PAPERLESS_USE_X_FORWARD_PORT = true;
      PAPERLESS_OCR_ROTATE_PAGES_THRESHOLD = "6";
    };
  };
}
