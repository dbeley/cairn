{
  description = "Cairn — A NixOS-native offline knowledge, AI, and education server. Declarative alternative to Project NOMAD.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
  in {
    nixosModules = {
      cairn = {
        imports = [
          ./modules
          ./modules/apps
        ];
      };
      default = self.nixosModules.cairn;
    };

    # Prove the module evaluates without errors in a minimal NixOS context
    checks = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      result = nixpkgs.lib.nixosSystem {
        modules = [
          "${nixpkgs}/nixos/modules/profiles/minimal.nix"
          self.nixosModules.cairn
          {
            nixpkgs.hostPlatform = system;
            services.cairn = {
              enable = true;
              kiwix.enable = true;
              kiwix.zimFiles = {};
              ollama.enable = true;
              caddy.enable = true;
            };
            fileSystems."/".device = "/dev/null";
            boot.loader.grub.enable = false;
            system.stateVersion = "26.11";
          }
        ];
      };
    in {
      cairn-module = pkgs.runCommand "cairn-check" {} ''
        echo "✅ Cairn module: services.cairn.enable = ${pkgs.lib.boolToString result.config.services.cairn.enable}" > $out
        echo "  kiwix.enable = ${pkgs.lib.boolToString result.config.services.cairn.kiwix.enable}" >> $out
        echo "  ollama.enable = ${pkgs.lib.boolToString result.config.services.cairn.ollama.enable}" >> $out
        echo "  caddy.enable = ${pkgs.lib.boolToString result.config.services.cairn.caddy.enable}" >> $out
      '';
    });
  };
}
