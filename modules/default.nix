# Cairn — Top-level module: imports core + all apps
{ lib, config, ... }:
{
  imports = [ ./core.nix ];

  # Sub-modules (apps) are imported via modules/apps/default.nix
  # when the user imports nixosModules.cairn in their flake.
}
