mkdir -p $1/loader/entries
mkdir -p $1/EFI/boot

SYS_PROFILE_GENS="$(find '/nix/var/nix/profiles/system-\d+-link')";

echo "type1" > "$1/loader/entries.srel"
