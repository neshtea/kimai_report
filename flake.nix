{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    ocaml-overlay = {
      url = "github:nix-ocaml/nix-overlays";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      supportedSystems = with inputs.flake-utils.lib.system; [ aarch64-darwin ];
    in inputs.flake-utils.lib.eachSystem supportedSystems (system:
      let
        overlays = [ inputs.ocaml-overlay.overlays.default ];
        pkgs = import nixpkgs { inherit system overlays; };
        ocamlPackages = pkgs.ocaml-ng.ocamlPackages;
        ocamlDeps = [
          ocamlPackages.ptime
          ocamlPackages.cohttp
          ocamlPackages.cohttp-lwt
          ocamlPackages.cohttp-lwt-unix
          ocamlPackages.yojson
          ocamlPackages.cmdliner
        ];
        # Filtered sources (prevents unecessary rebuilds)
        sources = {
          ocaml = inputs.nix-filter.lib {
            root = ./.;
            include = [
              ".ocamlformat"
              "dune-project"
              (inputs.nix-filter.lib.inDirectory "bin")
              (inputs.nix-filter.lib.inDirectory "lib")
              (inputs.nix-filter.lib.inDirectory "test")
            ];
          };
          nix = inputs.nix-filter.lib {
            root = ./.;
            include = [ (inputs.nix-filter.lib.matchExt "nix") ];
          };
        };
      in {

        formatter = pkgs.nixfmt;

        packages = {
          default = self.packages.${system}.kimaiReport;
          kimaiReport = pkgs.ocamlPackages.buildDunePackage {
            pname = "kimai_report";
            version = "0.1.0";
            duneVersion = "3";
            dontDetectOcamlConflicts = true;
            src = sources.ocaml;
            strictDeps = true;
            buildInputs = ocamlDeps;
          };
        };

        apps = {
          default = self.apps.${system}.kimaiReport;
          kimaiReport = {
            type = "app";
            program = "${self.packages.${system}.kimaiReport}/bin/kimai_report";
          };
        };

        devShells = {
          default = pkgs.mkShell {
            packages = [
              pkgs.dune_3
              ocamlPackages.odoc
              ocamlPackages.merlin
              ocamlPackages.ocamlformat
              ocamlPackages.ocaml
              ocamlPackages.utop
              ocamlPackages.ocaml-lsp
            ] ++ ocamlDeps;

            inputsFrom = [ self.packages.${system}.kimaiReport ];
            dontDetectOcamlConflicts = true;
          };

          # Shell for checking the build before releasing it to opam.
          # Particularly, we need an environment with no ocaml (we'll fetch that
          # with an acutal switch).
          opamBuild = pkgs.mkShell {
            buildInputs = with pkgs; [ dune_3 opam pkgs.dune-release ];

          };
        };
      });
}

