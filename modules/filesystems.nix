# This package replaces the standard nixos/modules/tasks/filesystems.nix module with one that does not generate /etc/fstabs anywhere
# This will surely make some software upset, but /etc/fstab is otherwise a fairly special case
{
  config,
  nixpkgs,
  pkgs,
  lib,
  ...
}:
with lib;
with utils; let
  addCheckDesc = desc: elemType: check:
    types.addCheck elemType check
    // {description = "${elemType.description} (with check: ${desc})";};

  isNonEmpty = s: (builtins.match "[ \t\n]*" s) == null;
  nonEmptyStr = addCheckDesc "non-empty" types.str isNonEmpty;

  fileSystems' = toposort fsBefore (attrValues config.fileSystems);

  fileSystems =
    if fileSystems' ? result
    then # use topologically sorted fileSystems everywhere
      fileSystems'.result
    else # the assertion below will catch this,
      # but we fall back to the original order
      # anyway so that other modules could check
      # their assertions too
      (attrValues config.fileSystems);

  specialFSTypes = ["proc" "sysfs" "tmpfs" "ramfs" "devtmpfs" "devpts"];

  nonEmptyWithoutTrailingSlash =
    addCheckDesc "non-empty without trailing slash" types.str
    (s: isNonEmpty s && (builtins.match ".+/" s) == null);
  coreFileSystemOpts = {
    name,
    config,
    ...
  }: {
    options = {
      mountPoint = mkOption {
        example = "/mnt/usb";
        type = nonEmptyWithoutTrailingSlash;
        description = lib.mdDoc "Location of the mounted file system.";
      };

      device = mkOption {
        default = null;
        example = "/dev/sda";
        type = types.nullOr nonEmptyStr;
        description = lib.mdDoc "Location of the device.";
      };

      fsType = mkOption {
        default = "auto";
        example = "ext3";
        type = nonEmptyStr;
        description = lib.mdDoc "Type of the file system.";
      };

      options = mkOption {
        default = ["defaults"];
        example = ["data=journal"];
        description = lib.mdDoc "Options used to mount the file system.";
        type = types.nonEmptyListOf nonEmptyStr;
      };

      depends = mkOption {
        default = [];
        example = ["/persist"];
        type = types.listOf nonEmptyWithoutTrailingSlash;
        description = lib.mdDoc ''
          List of paths that should be mounted before this one. This filesystem's
          {option}`device` and {option}`mountPoint` are always
          checked and do not need to be included explicitly. If a path is added
          to this list, any other filesystem whose mount point is a parent of
          the path will be mounted before this filesystem. The paths do not need
          to actually be the {option}`mountPoint` of some other filesystem.
        '';
      };
    };

    config = {
      mountPoint = mkDefault name;
      device = mkIf (elem config.fsType specialFSTypes) (mkDefault config.fsType);
    };
  };

  fileSystemOpts = {config, ...}: {
    options = {
      label = mkOption {
        default = null;
        example = "root-partition";
        type = types.nullOr nonEmptyStr;
        description = lib.mdDoc "Label of the device (if any).";
      };

      autoFormat = mkOption {
        default = false;
        type = types.bool;
        description = lib.mdDoc ''
          If the device does not currently contain a filesystem (as
          determined by {command}`blkid`, then automatically
          format it with the filesystem type specified in
          {option}`fsType`.  Use with caution.
        '';
      };

      formatOptions = mkOption {
        visible = false;
        type = types.unspecified;
        default = null;
      };

      autoResize = mkOption {
        default = false;
        type = types.bool;
        description = lib.mdDoc ''
          If set, the filesystem is grown to its maximum size before
          being mounted. (This is typically the size of the containing
          partition.) This is currently only supported for ext2/3/4
          filesystems that are mounted during early boot.
        '';
      };
    };

    config.options = mkMerge [
      (mkIf config.autoResize ["x-systemd.growfs"])
      (mkIf config.autoFormat ["x-systemd.makefs"])
      (mkIf (utils.fsNeededForBoot config) ["x-initrd.mount"])
    ];
  };
  stdMounts = builtins.attrValues config.fileSystems;
  earlyMounts = builtins.filter utils.fsNeededForBoot stdMounts;

  mkMountUnitForFs = fs: let
    escape = string: builtins.replaceStrings [" " "\t"] ["\\040" "\\011"] string;
    what =
      if fs.device != null
      then escape fs.device
      else if fs.label != null
      then "/dev/disk/by-label/${escape fs.label}"
      else throw "No device specified for mount point '${fs.mountPoint}'.";
  in {
    name = utils.escapeSystemdPath fs.mountPoint;
    value =
      {
        What = what;
        Where = escape fs.mountPoint;
      }
      // optionalAttrs (fs.fsType != "auto") {Type = fs.fsType;}
      // optionalAttrs (fs.options != []) {Options = escape (concatStringsSep "," fs.options);};
  };

  mkMountUnitForInitrdFs = fs: mkMountUnitForFs (fs // {mountPoint = "/sysroot${fs.mountPoint}";});
in {
  # this is a functional replacement of the stock filesystems
  disabledModules = ["${nixpkgs}/nixos/modules/tasks/filesystems.nix"];
  options = {
    fileSystems = mkOption {
      default = {};
      example = literalExpression ''
        {
          "/".device = "/dev/hda1";
          "/data" = {
            device = "/dev/hda2";
            fsType = "ext3";
            options = [ "data=journal" ];
          };
          "/bigdisk".label = "bigdisk";
        }
      '';
      type = types.attrsOf (types.submodule [coreFileSystemOpts fileSystemOpts]);
      description = lib.mdDoc ''
        The file systems to be mounted.  It must include an entry for
        the root directory (`mountPoint = "/"`).  Each
        entry in the list is an attribute set with the following fields:
        `mountPoint`, `device`,
        `fsType` (a file system type recognised by
        {command}`mount`; defaults to
        `"auto"`), and `options`
        (the mount options passed to {command}`mount` using the
        {option}`-o` flag; defaults to `[ "defaults" ]`).

        Instead of specifying `device`, you can also
        specify a volume label (`label`) for file
        systems that support it, such as ext2/ext3 (see {command}`mke2fs -L`).
      '';
    };

    system.fsPackages = mkOption {
      internal = true;
      default = [];
      description = lib.mdDoc "Packages supplying file system mounters and checkers.";
    };

    boot.supportedFilesystems = mkOption {
      default = [];
      example = ["btrfs"];
      type = types.listOf types.str;
      description = lib.mdDoc "Names of supported filesystem types.";
    };
  };
  config = {
    assertions = let
      ls = sep: concatMapStringsSep sep (x: x.mountPoint);
      resizableFSes = [
        "ext3"
        "ext4"
        "btrfs"
        "xfs"
      ];
      notAutoResizable = fs: fs.autoResize && !(builtins.elem fs.fsType resizableFSes);
    in [
      {
        assertion = ! (fileSystems' ? cycle);
        message = "The ‘fileSystems’ option can't be topologically sorted: mountpoint dependency path ${ls " -> " fileSystems'.cycle} loops to ${ls ", " fileSystems'.loops}";
      }
      {
        assertion = ! (any notAutoResizable fileSystems);
        message = let
          fs = head (filter notAutoResizable fileSystems);
        in ''
          Mountpoint '${fs.mountPoint}': 'autoResize = true' is not supported for 'fsType = "${fs.fsType}"'
          ${optionalString (fs.fsType == "auto") "fsType has to be explicitly set and"}
          only the following support it: ${lib.concatStringsSep ", " resizableFSes}.
        '';
      }
      {
        assertion = ! (any (fs: fs.formatOptions != null) fileSystems);
        message = let
          fs = head (filter (fs: fs.formatOptions != null) fileSystems);
        in ''
          'fileSystems.<name>.formatOptions' has been removed, since
          systemd-makefs does not support any way to provide formatting
          options.
        '';
      }
    ];

    # force systemd boot
    boot.initrd.systemd.enable = true;

    # pull in the correct filesystems
    boot.supportedFilesystems = map (fs: fs.fsType) stdMounts;
    boot.initrd.supportedFilesystems = map (fs: fs.fsType) earlyMounts;

    # Add the mount helpers to the system path so that `mount' can find them.
    # TODO: Do we need this?
    # system.fsPackages = [pkgs.dosfstools];

    # add these to the system env - this isn't actually *required*, just the kernel modules
    # environment.systemPackages = config.system.fsPackages;

    # we *do* need to get the path overriden for the following units however:

    # systemd-makefs@device.service
    # systemd-mkswap@device.service
    # systemd-growfs@mountpoint.service
    # systemd-growfs-root.service

    # we might need to also explicitly pull particular kernel modules in

    # define these mounts
    systemd.mounts = map mkMountUnitForFs stdMounts;
    boot.initrd.systemd.mounts = map mkMountUnitForInitrdFs earlyMounts;

    # this is a default nixos just assumes we have set up - so do that
    systemd.tmpfiles.rules = [
      "d /run/keys 0750 root ${toString config.ids.gids.keys}"
      "z /run/keys 0750 root ${toString config.ids.gids.keys}"
    ];
  };
}
