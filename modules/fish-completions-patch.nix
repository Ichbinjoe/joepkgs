{
  config,
  nixpkgs,
  pkgs,
  lib,
  ...
}:
with lib; {
  config = mkIf config.programs.fish.enable {
    environment.etc."fish/generated_completions".source = let
      patchedGenerator = pkgs.stdenv.mkDerivation {
        name = "fish_patched-completion-generator";
        srcs = [
          "${pkgs.fish}/share/fish/tools/create_manpage_completions.py"
          "${pkgs.fish}/share/fish/tools/deroff.py"
        ];
        unpackCmd = "cp $curSrc $(basename $curSrc)";
        sourceRoot = ".";
        patches = [
          (nixpkgs + "/nixos/modules/programs/fish_completion-generator.patch")
        ]; # to prevent collisions of identical completion files
        dontBuild = true;
        installPhase = ''
          mkdir -p $out
          cp * $out/
        '';
        preferLocalBuild = true;
        allowSubstitutes = false;
      };
      generateCompletions = package:
        pkgs.runCommand
        "${package.name}_fish-completions"
        (
          {
            inherit package;
            # this is the important part - we can't build this locally at least with my setup
            preferLocalBuild = true;
            allowSubstitutes = false;
          }
          // optionalAttrs (package ? meta.priority) {meta.priority = package.meta.priority;}
        )
        ''
          mkdir -p $out
          if [ -d $package/share/man ]; then
            find $package/share/man -type f | xargs ${pkgs.python3.pythonForBuild.interpreter} ${patchedGenerator}/create_manpage_completions.py --directory $out >/dev/null
          fi
        '';
    in
      mkForce (pkgs.buildEnv
        {
          name = "system_fish-completions";
          ignoreCollisions = true;
          paths = map generateCompletions config.environment.systemPackages;
        });
  };
}
