# Cairn ⛰️

A **NixOS-native**, declarative, offline-first knowledge, AI, and education server.

Cairn is a spiritual alternative to [Project N.O.M.A.D.](https://github.com/Crosstalk-Solutions/project-nomad) — but built entirely on NixOS principles: declarative configuration, atomic updates, and reproducible builds.

## What it does

Cairn bundles best-in-class open-source tools into a single NixOS module:

| Capability | Powered By | Status |
|---|---|---|
| Offline Knowledge | [Kiwix](https://kiwix.org) (Wikipedia, ebooks, references) | ✅ Implemented |
| Local AI | [Ollama](https://ollama.com) with GPU acceleration | ✅ Implemented |
| AI Chat UI | [Open WebUI](https://openwebui.com) | 🔜 Planned |
| Semantic Search (RAG) | [Qdrant](https://qdrant.tech) | 🔜 Planned |
| Offline Maps | [ProtoMaps](https://protomaps.com) / tileserver | 🔜 Planned |
| Education | [Kolibri](https://learningequality.org/kolibri/) | 🔜 Planned |
| Ebook Library | [Calibre-Web](https://github.com/janeczku/calibre-web) | 🔜 Planned |
| Document Management | [Paperless-ngx](https://paperless-ngx.com) | 🔜 Planned |
| Music Streaming | [Navidrome](https://www.navidrome.org) | 🔜 Planned |
| Media Streaming | [Jellyfin](https://jellyfin.org) | 🔜 Planned |
| Photo Gallery | [Immich](https://immich.app) | 🔜 Planned |
| Recipe Manager | [Mealie](https://mealie.io) | 🔜 Planned |
| Data Tools | [CyberChef](https://gchq.github.io/CyberChef/) | 🔜 Planned |
| Notes | [FlatNotes](https://github.com/dullage/flatnotes) | 🔜 Planned |
| File Browser | [File Browser](https://filebrowser.org) | 🔜 Planned |
| Password Manager | [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | 🔜 Planned |
| File Sync | [Syncthing](https://syncthing.net) | 🔜 Planned |
| Git Server | [Gitea](https://about.gitea.com) | 🔜 Planned |

## Philosophy

- **Declarative**: Edit `configuration.nix`, run `nixos-rebuild switch`, done. No Docker Compose, no shell scripts.
- **Offline-first**: Download content while online, use it anywhere. No internet dependency after setup.
- **Read-only dashboard**: A clean landing page with links to each service. To change something, edit your Nix config — not a web UI.
- **Power users target**: You already know NixOS. Cairn gives you sensible defaults and content download automation.

## Quick Start

Add Cairn to your NixOS flake:

```nix
{
  inputs.cairn.url = "github:your-org/cairn";

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

Minimal configuration:

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
          sha256 = "sha256-...=";  # Get this after your first download
        };
      };
      autoUpdate = "monthly";
    };

    ollama = {
      enable = true;
      gpu = "cuda";
      models = [ "llama3.2:8b" ];
    };

    caddy = {
      enable = true;
      port = 8080;
    };
  };
}
```

Rebuild:

```bash
sudo nixos-rebuild switch
```

Open `http://cairn.local:8080` to see the dashboard.

## Architecture

```
configuration.nix
    │
    ▼
services.cairn = { ... }
    │
    ├── core.nix          → dataDir, user, groups
    ├── apps/kiwix.nix    → services.kiwix-serve + ZIM download script
    ├── apps/ollama.nix   → services.ollama + model pull script
    ├── apps/caddy.nix    → services.caddy reverse proxy + dashboard
    └── dashboard/        → Static HTML (served by Caddy)
```

Each sub-module wraps an existing NixOS service (from nixpkgs) with:
- Sensible defaults (ports, bind addresses, storage paths)
- Content download/update automation (systemd oneshot services + timers)
- No web-based configuration — everything is in your Nix config

## Content Management

ZIM files (Wikipedia, ebooks, etc.) are downloaded to `/var/lib/cairn/kiwix/` at boot time. A systemd oneshot service runs before `kiwix-serve` starts, verifying hashes and downloading missing files.

AI models are pulled via Ollama's API similarly — a oneshot service waits for Ollama to be ready, then pulls declared models.

Periodic updates are handled by systemd timers:

```nix
services.cairn.kiwix.autoUpdate = "monthly";  # or "weekly"
```

## License

Apache 2.0 — same as Project N.O.M.A.D.
