# Cairn — Caddy reverse proxy: auto-generates routes for all enabled services
# and serves the static dashboard at /
{ lib, config, pkgs, ... }:
let
  cfg = config.services.cairn;
  caddyCfg = cfg.caddy;
  inherit (lib) types;

  kiwixEnabled = cfg.kiwix.enable or false;
  ollamaEnabled = cfg.ollama.enable or false;
  kiwixPort = cfg.kiwix.port or 9090;
  ollamaPort = cfg.ollama.port or 11434;

  # Package the static dashboard as a Nix store path
  dashboardDir = builtins.path {
    name = "cairn-dashboard";
    path = ../../dashboard;
  };
in
{
  options.services.cairn.caddy = {
    enable = lib.mkEnableOption "Caddy reverse proxy and dashboard";

    port = lib.mkOption {
      type = types.port;
      default = cfg.dashboard.port or 8080;
      description = "Port for the Caddy reverse proxy (main entry point).";
    };
  };

  config = lib.mkIf (cfg.enable && caddyCfg.enable) {
    services.caddy = {
      enable = true;

      virtualHosts = lib.mkMerge ([
        {
          "${cfg.domain}" = {
            listenAddresses = [ ":${toString caddyCfg.port}" ];
            extraConfig = ''
              # ── Dashboard (root) ──
              handle / {
                root * ${dashboardDir}
                file_server
              }

              ${lib.optionalString kiwixEnabled ''
              # ── Kiwix proxy ──
              handle_path /kiwix* {
                reverse_proxy http://127.0.0.1:${toString kiwixPort}
              }
              ''}

              ${lib.optionalString ollamaEnabled ''
              # ── Ollama API proxy (for Open WebUI later) ──
              handle_path /ollama* {
                reverse_proxy http://127.0.0.1:${toString ollamaPort}
              }
              ''}
            '';
          };
        }
      ]);
    };
  };
}
