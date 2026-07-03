# Cairn — Apps: imports all service sub-modules
{ ... }:
{
  imports = [
    ./kiwix.nix
    ./ollama.nix
    ./open-webui.nix
    ./caddy.nix
  ];
}
