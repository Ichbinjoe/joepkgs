{...}: {
  nixpkgs.hostPlatform = {
    config = "armv7l-unknown-linux-gnu";
    system = "armv7l-linux";
  };
}
