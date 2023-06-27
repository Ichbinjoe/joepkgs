#!/bin/bash
set -e
set -x
#nix flake update
result=$(nix build --system x86_64-linux "./#router-toplevel" --print-out-paths)
nix-copy-closure --to joe@192.168.2.1 "$result"
ssh -t joe@192.168.2.1 -- "bash -c \"sudo -- $result/bin/switch-to-configuration switch\""
