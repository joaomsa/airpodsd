{
  description = "AirPods battery reporting for Linux, with a NixOS service module";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in rec {
          airpodsd = pkgs.callPackage ./nix/package.nix { };
          default = airpodsd;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.airpodsd}/bin/airpodsd";
          meta.description = "Read AirPods battery information";
        };
      });

      nixosModules.airpodsd = import ./nix/module.nix;
      nixosModules.default = self.nixosModules.airpodsd;

      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          package = self.packages.${system}.airpodsd;
          machine = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              {
                services.airpodsd.enable = true;
                boot.isContainer = true;
                system.stateVersion = "26.05";
              }
            ];
          };
          config = machine.config;
        in {
          inherit package;
          cli = pkgs.runCommand "airpodsd-cli-check" { } ''
            ${package}/bin/airpodsd --help > "$out"
            ${package}/bin/airpodsd daemon --help > daemon-help
            ${package}/bin/airpodsd status --help > status-help
            grep -q keystore daemon-help
            grep -q short status-help
          '';
          module =
            assert config.hardware.bluetooth.enable;
            assert config.hardware.bluetooth.settings.General.Experimental;
            assert config.systemd.services.airpodsd.serviceConfig.StateDirectory == "airpodsd";
            assert nixpkgs.lib.all (a: a.assertion) config.assertions;
            pkgs.runCommand "airpodsd-module-check" { } ''
              printf '%s\n' '${config.systemd.services.airpodsd.serviceConfig.ExecStart}' > "$out"
            '';
        });
    };
}
