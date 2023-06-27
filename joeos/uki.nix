# sets up a standard EFI bootloader which works with image
# creation stuff. Specifically, we don't use bootctl install
# or require any commands - we just replicate it with templates!
# additional benefit is that this doesn't require python and 
# builds natively w/ nix

{ config, pkgs, lib, ... }: with lib;

{
  options = {
    system.boot.loader.uki.enable = mkEnableOption "uki booting";
  };
  config = 
    let
      systemdWithUkify = pkgs.systemd.override {
        withUkify = true;
      };
      kernel = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
      preinitrds = concatMapStringsSep " " lib.escapeShellArg config.boot.initrd.prepend;
      initrd = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
      kernelArgs = builtins.concatStringsSep " " config.boot.kernelParams;
      osRelease = lib.escapeShellArg "@${config.system.build.etc}/etc/os-release";
      efiArch = pkgs.stdenv.buildPlatform.efiArch;
      buildUki = topLevel: outPath:
        ''
          ${systemdWithUkify}/lib/systemd/ukify \
            "${kernel}" \
            ${preinitrds} \
            "${initrd}" \
            --cmdline "init=${topLevel}/init ${kernelArgs}" \
            --os-release ${osRelease} \
            --uname ${lib.escapeShellArg config.system.nixos.version} \
            --efi-arch ${efiArch} \
            --stub "${pkgs.systemd}/lib/systemd/boot/efi/linux${efiArch}.efi.stub" \
            --tools "${systemdWithUkify}/bin" \
            --tools "${pkgs.bintools}/bin" \
            --tools "${pkgs.libllvm}/bin" \
            --output "${outPath}"
        '';
  in mkIf config.system.boot.loader.uki.enable {
    boot.loader.grub.enable = false;

    system.extraSystemBuilderCmds = buildUki "$out" "$out/uki";

    system.build.buildEspDir = ''
      mkdir -p $espDir/EFI/boot

      cp $toplevel/uki $espDir/EFI/boot/boot${efiArch}.efi
    '';
  };
}
