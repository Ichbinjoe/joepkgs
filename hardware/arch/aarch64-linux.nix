{...}: {
  nixpkgs.hostPlatform = {
    config = "aarch64-unknown-linux-gnu";
    system = "aarch64-linux";
  };
}
