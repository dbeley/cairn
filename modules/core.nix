# Cairn — Core options shared by all sub-modules
{ lib, config, ... }:
let
  cfg = config.services.cairn;
in
{
  options.services.cairn = {
    enable = lib.mkEnableOption "Cairn — offline knowledge, AI, and education server";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/cairn";
      description = ''
        Root directory for all Cairn data (ZIM files, AI models, content, etc.).
        This is NOT stored in the Nix store — content is downloaded at runtime.
      '';
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "cairn.local";
      description = "Domain name used for the web dashboard and reverse proxy.";
    };

    dashboard = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to serve the Cairn dashboard as a landing page.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port for the Cairn dashboard (reverse proxy).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Create the data directory on activation
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 cairn cairn - -"
    ];

    # Create a dedicated user/group
    users.users.cairn = {
      isSystemUser = true;
      group = "cairn";
      description = "Cairn offline knowledge server";
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.cairn = { };
  };
}
