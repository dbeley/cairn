# Cairn — Apps: imports all service sub-modules
{ ... }:
{
  imports = [
    ./kiwix.nix
    ./ollama.nix
    ./open-webui.nix
    ./cyberchef.nix
    ./caddy.nix
  ];
}
