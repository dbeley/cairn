# Cairn — Apps: imports all service sub-modules
{ ... }:
{
  imports = [
    ./kiwix.nix
    ./ollama.nix
    ./caddy.nix
  ];
}
