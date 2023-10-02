{...}: {
  nixpkgs.hostPlatform = {
    config = "x86_64-unknown-linux-gnu";
    system = "x86_64-linux";
  };
}
