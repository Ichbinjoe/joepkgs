{...}: {
  config.boot.zfs = {
    pools = let
      pdef = devNodes: {
        devNodes = map (d: builtins.toPath "/dev/disk/by-id/${d}-part1") devNodes;
      };
    in {
      zpool = {
        devNodes = "/dev/disk/by-id";
      };
      zflash = {
        devNodes = "/dev/disk/by-id";
      };
    };

    extraPools = [
      "zpool"
      "zflash"
    ];
  };
}
