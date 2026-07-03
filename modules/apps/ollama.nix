# Cairn — Ollama module: local AI with GPU acceleration
{ lib, config, pkgs, ... }:
let
  cfg = config.services.cairn;
  ollamaCfg = cfg.ollama;
  inherit (lib) types;
in
{
  options.services.cairn.ollama = {
    enable = lib.mkEnableOption "Ollama local LLM server with optional GPU acceleration";

    port = lib.mkOption {
      type = types.port;
      default = 11434;
      description = "Port for the Ollama API.";
    };

    gpu = lib.mkOption {
      type = types.nullOr (types.enum [ "cuda" "rocm" "vulkan" ]);
      default = null;
      example = "cuda";
      description = ''
        GPU acceleration backend.
        - `"cuda"` — NVIDIA GPUs (requires nixpkgs.config.cudaSupport = true)
        - `"rocm"` — AMD GPUs
        - `"vulkan"` — Cross-vendor via Vulkan
        - `null` — CPU-only inference (default)
      '';
    };

    models = lib.mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "llama3.2:8b" "mistral:7b" "nomic-embed-text" ];
      description = ''
        List of Ollama models to pull at first boot. Model names use Ollama's
        naming convention (e.g. 'llama3.2:8b', 'mistral:7b').

        Models are downloaded to Ollama's default model directory
        (`/var/lib/ollama` by default in nixpkgs).
        Pulling is idempotent — existing models are not re-downloaded.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && ollamaCfg.enable) {
    services.ollama = {
      enable = true;
      host = "127.0.0.1";     # Bind to localhost; Caddy proxies external access
      port = ollamaCfg.port;
      package = if ollamaCfg.gpu == "cuda"  then pkgs.ollama-cuda
           else if ollamaCfg.gpu == "rocm"  then pkgs.ollama-rocm
           else if ollamaCfg.gpu == "vulkan" then pkgs.ollama-vulkan
           else pkgs.ollama;
    };

    # Oneshot service to pull declared models at boot
    systemd.services.cairn-ollama-pull = lib.mkIf (ollamaCfg.models != []) {
      description = "Cairn Ollama model puller";
      wantedBy = [ "multi-user.target" ];
      after = [ "ollama.service" ];
      requires = [ "ollama.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "cairn-ollama-pull" ''
          set -euo pipefail
          OLLAMA_HOST="127.0.0.1:${toString ollamaCfg.port}"

          # Wait for Ollama to be ready
          for i in $(seq 1 30); do
            if curl -s "http://$OLLAMA_HOST/api/tags" > /dev/null 2>&1; then
              break
            fi
            sleep 1
          done

          ${lib.concatStringsSep "\n" (map (model: ''
            echo "📦 Pulling model: ${model}..."
            ${lib.getExe pkgs.curl} -s -X POST "http://$OLLAMA_HOST/api/pull" \
              -d '{"name":"${model}"}' > /dev/null
            echo "  ✅ ${model} ready"
          '') ollamaCfg.models)}
        '';
        User = "cairn";
        Group = "cairn";
        # Need network to pull models
        PrivateNetwork = false;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };
  };
}
