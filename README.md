# Cairn ⛰️

A **NixOS-native**, declarative, offline-first knowledge, AI, and education server.

Cairn is a spiritual alternative to [Project N.O.M.A.D.](https://github.com/Crosstalk-Solutions/project-nomad) — built entirely on NixOS principles: declarative configuration, atomic updates, and reproducible builds. No Docker, no shell scripts, no web-based admin panel. Just Nix.

## What's Inside

Every service is a single `enable = true` in your Nix config.

| Service | Backend | Access |
|---|---|---|
| **Offline Knowledge** | [Kiwix](https://kiwix.org) — Wikipedia, ebooks, reference materials | `/kiwix/` via dashboard |
| **Local AI** | [Ollama](https://ollama.com) — private LLMs with GPU acceleration | Backend only |
| **AI Chat** | [Open WebUI](https://openwebui.com) — chat interface with document upload & built-in RAG | Port 9091 (direct) |
| **Data Tools** | [CyberChef](https://gchq.github.io/CyberChef/) — encode, decode, encrypt, hash | `/tools/` via dashboard |
| **Reverse Proxy** | [Caddy](https://caddyserver.com) — auto-generated routes + static dashboard | Port 8080 |

## Philosophy

- **Declarative**. Edit `configuration.nix`, run `nixos-rebuild switch`, done. No Docker Compose, no shell installers, no runtime admin UI that mutates state.
- **Offline-first**. Download content while online, use it entirely offline after setup. Zero telemetry, zero cloud dependencies.
- **Read-only dashboard**. A clean landing page with links to each service. To change anything, edit your Nix config.
- **Power-user target**. Cairn assumes you already know NixOS. It provides sensible defaults and content-download automation — not a GUI for beginners.

## Quick Start

Add Cairn to your NixOS flake:

```nix
{
  inputs.cairn.url = "github:dbeley/cairn";

  outputs = { nixpkgs, cairn, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        cairn.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Minimal working configuration:

```nix
{ ... }:
{
  services.cairn = {
    enable = true;
    domain = "cairn.local";

    kiwix = {
      enable = true;
      zimFiles = {
        wikipedia = {
          filename = "wikipedia_en_all_maxi_2025-06.zim";
          url = "https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2025-06.zim";
          sha256 = "sha256-...=";
        };
      };
      autoUpdate = "monthly";
    };

    ollama = {
      enable = true;
      gpu = "cuda";                     # or "rocm", "vulkan", null (CPU)
      models = [ "llama3.2:8b" ];
    };

    open-webui.enable = true;           # AI Chat on port 9091
    cyberchef.enable = true;            # Data tools at /tools/
    caddy.enable = true;                # Dashboard on port 8080
  };
}
```

Rebuild and open `http://cairn.local:8080`:

```bash
sudo nixos-rebuild switch
```

## Architecture

```
configuration.nix
    │
    ▼
services.cairn = { ... }
    │
    ├── core.nix              → dataDir (/var/lib/cairn), user/group cairn
    ├── apps/kiwix.nix        → services.kiwix-serve + ZIM download + timer
    ├── apps/ollama.nix       → services.ollama + GPU selection + model pull
    ├── apps/open-webui.nix   → services.open-webui (chat + RAG)
    ├── apps/cyberchef.nix    → static files served by Caddy
    ├── apps/caddy.nix        → reverse proxy (auto-routes) + dashboard
    └── dashboard/index.html  → Static landing page
```

Each module wraps an existing NixOS service from nixpkgs and adds:

1. **Sensible defaults** — ports, bind addresses, storage paths, offline-friendly flags
2. **Content download automation** — systemd oneshot services download ZIMs, pull AI models
3. **Periodic updates** — systemd timers keep content fresh

## Content Management

Cairn is a *server*, not a build artifact. Content lives in `/var/lib/cairn/`, not the Nix store.

| Content Type | Storage | Update Mechanism |
|---|---|---|
| ZIM files (Wikipedia, ebooks) | `/var/lib/cairn/kiwix/` | oneshot download at boot + timer |
| AI models (Ollama) | `/var/lib/ollama/` (Ollama default) | oneshot `ollama pull` at boot |

Downloads are verified by SHA256 hash. Stale files (declared removed) are cleaned up automatically.

```nix
# Automatic content updates via systemd timers
services.cairn.kiwix.autoUpdate = "monthly";  # or "weekly"
```
