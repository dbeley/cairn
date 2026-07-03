# Cairn — CyberChef module: static data analysis tools
# Served directly by Caddy — no backend, no systemd service needed.
{ lib, config, pkgs, ... }:
let
  cfg = config.services.cairn;
  cyCfg = cfg.cyberchef;
  inherit (lib) types;
in
{
  options.services.cairn.cyberchef = {
    enable = lib.mkEnableOption "CyberChef — the Cyber Swiss Army Knife (encode, decode, encrypt, hash)";

    package = lib.mkPackageOption pkgs "cyberchef" { };

    # Path prefix for the reverse proxy
    prefix = lib.mkOption {
      type = types.str;
      default = "tools";
      description = "URL path prefix for CyberChef on the dashboard.";
    };
  };

  config = lib.mkIf (cfg.enable && cyCfg.enable) {
    # CyberChef is static — nothing to configure at the service level.
    # Caddy serves it via the reverse proxy routes in modules/apps/caddy.nix.
  };
}
