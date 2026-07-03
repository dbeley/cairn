# Cairn — Kiwix module: offline Wikipedia, ebooks, and reference material
{ lib, config, pkgs, ... }:
let
  cfg = config.services.cairn;
  kiwixCfg = cfg.kiwix;
  inherit (lib) types;

  hasZimFiles = kiwixCfg.zimFiles != {};

  # Build the download script for all declared ZIM files
  downloadScript = pkgs.writeShellScriptBin "cairn-kiwix-download" ''
    set -euo pipefail

    ZIM_DIR="${kiwixCfg.dataDir}"
    mkdir -p "$ZIM_DIR"

    # Declared ZIM files: name → filename, url, sha256
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: zim: ''
      echo "📦 Checking ${name}..."
      ZIM_FILE="$ZIM_DIR/${zim.filename}"

      if [ -f "$ZIM_FILE" ]; then
        # Verify existing file hash
        ACTUAL_HASH=$(${lib.getExe pkgs.nix} hash file --type sha256 "$ZIM_FILE" 2>/dev/null || echo "missing")
        if [ "$ACTUAL_HASH" = "${zim.sha256}" ]; then
          echo "  ✅ ${name} — up to date"
        else
          echo "  ⚠️  ${name} — hash mismatch, re-downloading..."
          rm -f "$ZIM_FILE"
        fi
      fi

      if [ ! -f "$ZIM_FILE" ]; then
        echo "  ⬇️  Downloading ${name} (''${ZIM_FILE##*/})..."
        ${lib.getExe pkgs.curl} -L --progress-bar -o "$ZIM_FILE.tmp" "${zim.url}"
        mv "$ZIM_FILE.tmp" "$ZIM_FILE"
        echo "  ✅ ${name} — downloaded"
      fi
    '') kiwixCfg.zimFiles)}

    # Remove stale ZIMs that aren't in the declared list
    DECLARED_FILES="${lib.concatStringsSep " " (lib.mapAttrsToList (_: zim: zim.filename) kiwixCfg.zimFiles)}"
    for existing in "$ZIM_DIR"/*.zim; do
      [ -f "$existing" ] || continue
      basename="''${existing##*/}"
      if ! echo "$DECLARED_FILES" | grep -qF "$basename"; then
        echo "  🗑️  Removing stale ZIM: $basename"
        rm -f "$existing"
      fi
    done

    echo "✅ All ZIM files ready."
  '';

  # Build the library attrset for kiwix-serve
  libraryFromConfig = lib.mapAttrs (name: zim: "${kiwixCfg.dataDir}/${zim.filename}") kiwixCfg.zimFiles;

  # Empty library XML for when no ZIM files are declared
  emptyLibraryXml = pkgs.writeText "empty-library.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <library version="20110515"/>
  '';
in
{
  options.services.cairn.kiwix = {
    enable = lib.mkEnableOption "Kiwix offline knowledge server (Wikipedia, ebooks, etc.)";

    port = lib.mkOption {
      type = types.port;
      default = 9090;
      description = "Port for the Kiwix web interface.";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "${cfg.dataDir}/kiwix";
      description = "Directory to store downloaded ZIM files.";
    };

    zimFiles = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          filename = lib.mkOption {
            type = types.str;
            description = "Filename of the ZIM file on disk (e.g. 'wikipedia_en_all_maxi_2025-06.zim').";
          };
          url = lib.mkOption {
            type = types.str;
            description = "URL to download the ZIM file.";
          };
          sha256 = lib.mkOption {
            type = types.str;
            description = "SHA256 hash of the ZIM file (for integrity verification).";
          };
        };
      });
      default = {};
      description = ''
        Declares which ZIM files to download and serve.
        Each entry specifies a filename, download URL, and SHA256 hash.

        ZIM files are downloaded to `dataDir` at boot time (via a systemd oneshot service).
        Find ZIM files at: https://download.kiwix.org/zim/
      '';
      example = lib.literalExpression ''
        {
          wikipedia = {
            filename = "wikipedia_en_all_maxi_2025-06.zim";
            url = "https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2025-06.zim";
            sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          };
          gutenberg = {
            filename = "gutenberg_en_all_2025-06.zim";
            url = "https://download.kiwix.org/zim/gutenberg/gutenberg_en_all_2025-06.zim";
            sha256 = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
          };
        }
      '';
    };

    autoUpdate = lib.mkOption {
      type = types.nullOr (types.enum [ "weekly" "monthly" ]);
      default = null;
      description = "Schedule periodic ZIM file updates. Null = manual only (download at boot).";
    };
  };

  config = lib.mkIf (cfg.enable && kiwixCfg.enable) {
    # ── Download service (oneshot, runs before kiwix-serve) ──
    # Only create if we have ZIM files to download

    systemd.services.cairn-kiwix-download = lib.mkIf hasZimFiles {
      description = "Cairn Kiwix ZIM downloader";
      wantedBy = [ "multi-user.target" ];
      before = [ "kiwix-serve.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe downloadScript}";
        User = "cairn";
        Group = "cairn";
        PrivateNetwork = false;
        ReadWritePaths = [ kiwixCfg.dataDir ];
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    # Download the ZIMs first, then start kiwix-serve (only if download service exists)
    systemd.services.kiwix-serve = lib.mkMerge [
      (lib.mkIf hasZimFiles {
        requires = [ "cairn-kiwix-download.service" ];
        after = [ "cairn-kiwix-download.service" ];
      })
    ];

    # ── Auto-update timer (optional) ──
    # Only create if we have ZIM files and auto-update is enabled

    systemd.timers.cairn-kiwix-update = lib.mkIf (hasZimFiles && kiwixCfg.autoUpdate != null) {
      description = "Cairn Kiwix periodic ZIM update";
      timerConfig = {
        OnCalendar = if kiwixCfg.autoUpdate == "weekly" then "weekly" else "monthly";
        Persistent = true;
        RandomizedDelaySec = 3600;
      };
      wantedBy = [ "timers.target" ];
    };

    systemd.services.cairn-kiwix-update = lib.mkIf (hasZimFiles && kiwixCfg.autoUpdate != null) {
      description = "Cairn Kiwix ZIM updater (timer)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe downloadScript}";
        User = "cairn";
        Group = "cairn";
        PrivateNetwork = false;
        ReadWritePaths = [ kiwixCfg.dataDir ];
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    # ── Kiwix-serve configuration ──

    services.kiwix-serve = {
      enable = true;
      port = kiwixCfg.port;
      address = "127.0.0.1";
    } // (if hasZimFiles then {
      library = libraryFromConfig;
    } else {
      libraryPath = emptyLibraryXml;
    });
  };
}
