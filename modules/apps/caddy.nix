# Cairn — Caddy reverse proxy: auto-generates routes for all enabled services
# and serves the static dashboard at /
{ lib, config, pkgs, ... }:
let
  cfg = config.services.cairn;
  caddyCfg = cfg.caddy;
  inherit (lib) types;

  kiwixEnabled = cfg.kiwix.enable or false;
  ollamaEnabled = cfg.ollama.enable or false;
  webuiEnabled = cfg.open-webui.enable or false;
  cyberchefEnabled = cfg.cyberchef.enable or false;
  kiwixPort = cfg.kiwix.port or 9090;
  ollamaPort = cfg.ollama.port or 11434;
  webuiPort = cfg.open-webui.port or 9091;

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

      # Use the configured port as the HTTP port (default is 80, which conflicts
      # with other services like Hermes)
      httpPort = caddyCfg.port;
      httpsPort = lib.mkDefault 443;  # Explicitly not listening on 443 by default

      virtualHosts = lib.mkMerge ([
        {
          "${cfg.domain}" = {
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
              # ── Ollama API proxy ──
              handle_path /ollama* {
                reverse_proxy http://127.0.0.1:${toString ollamaPort}
              }
              ''}

              ${lib.optionalString webuiEnabled ''
              # ── Open WebUI chat interface ──
              handle_path /chat* {
                reverse_proxy http://127.0.0.1:${toString webuiPort}
                # Open WebUI uses WebSocket for streaming
              }
              # Proxy /ws for Open WebUI's WebSocket connections
              handle_path /ws* {
                reverse_proxy http://127.0.0.1:${toString webuiPort}
              }
              handle_path /api/v1* {
                reverse_proxy http://127.0.0.1:${toString webuiPort}
              }
              ''}

              ${lib.optionalString cyberchefEnabled ''
              # ── CyberChef static files ──
              handle_path /tools* {
                root * ${pkgs.cyberchef}/share/cyberchef
                file_server
              }
              ''}
            '';
          };
        }
      ]);
    };
  };
}
