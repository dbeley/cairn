# Cairn — Open WebUI module: AI chat interface with RAG capabilities
# Connects to the Ollama backend for local LLM inference.
{ lib, config, ... }:
let
  cfg = config.services.cairn;
  webuiCfg = cfg.open-webui;
  inherit (lib) types;

  ollamaEnabled = cfg.ollama.enable or false;
  ollamaPort = cfg.ollama.port or 11434;
in
{
  options.services.cairn.open-webui = {
    enable = lib.mkEnableOption "Open WebUI — local AI chat interface with document upload and RAG";

    port = lib.mkOption {
      type = types.port;
      default = 9091;
      description = "Port for the Open WebUI interface.";
    };

    authEnabled = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to require authentication. When false, anyone on the local network
        can access the chat interface without login. Set to true for multi-user setups.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && webuiCfg.enable) {
    services.open-webui = {
      enable = true;
      host = "0.0.0.0";   # Direct access without reverse proxy
      port = webuiCfg.port;

      environment = {
        # ── Ollama connection ──
        OLLAMA_API_BASE_URL = "http://127.0.0.1:${toString ollamaPort}";

        # ── Telemetry: OFF ──
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";

        # ── Authentication ──
        WEBUI_AUTH = lib.mkIf (!webuiCfg.authEnabled) "False";

        # ── Offline-friendly settings ──
        # Disable online features that require internet
        ENABLE_COMMUNITY_SHARING = "False";
        SHOW_ADMIN_DETAILS = "False";
      };

      openFirewall = false;  # Caddy handles external access

      # Port 9091 is opened in networking.firewall by the user
    };

    # Open firewall if enabled
    networking.firewall.allowedTCPPorts = lib.mkIf webuiCfg.enable [ webuiCfg.port ];

    # Warn if Ollama is not enabled
    warnings = lib.optional (!ollamaEnabled) ''
      services.cairn.open-webui is enabled but services.cairn.ollama is not.
      Open WebUI needs an Ollama backend. Add: services.cairn.ollama.enable = true;
    '';
  };
}
