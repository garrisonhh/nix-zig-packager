{
  description = "a utility for packaging zig projects";

  inputs = {
    zig-overlay.url = github:mitchellh/zig-overlay;
    flake-utils.url = github:numtide/flake-utils;
  };

  outputs =
    { nixpkgs
    , zig-overlay
    , flake-utils
    , ...
    }:
    let
      zigPackage = system: config:
        let
          # pkgs with zigpkgs
          pkgs = (import nixpkgs) {
            inherit system;
            overlays = [
              zig-overlay.overlays.default
            ];
          };

          inherit (pkgs.stdenv) mkDerivation;

          # config params
          params =
            {
              zigVersion = "master";
              zigBuildFlags = [ ];
            }
            // config;

          # get deps, name, version from zon
          zon =
            let
              z = (import ./parseZon.nix) {
                inherit (pkgs) lib;
                input = builtins.readFile "${params.src}/build.zig.zon";
              };
            in
            pkgs.lib.debug.traceSeq z z;
        in
        mkDerivation {
          inherit (zon) name version;
          inherit (params) src zigBuildFlags;

          nativeBuildInputs = [
            pkgs.zigpkgs.${params.zigVersion}
          ];

          patchPhase = ''
            # zig needs this to prevent it from trying to write to homeless
            # shelter
            export HOME="$NIX_BUILD_TOP"
          '';

          buildPhase = ''
            zig build
          '';

          installPhase = ''
            mkdir -p $out
            cp -r zig-out/* $out/
          '';
        };
    in
    flake-utils.lib.eachDefaultSystem (system: {
      packages.default = zigPackage system {
        src = ./hello;
      };

      templates.default = ./template;
      lib.zigPackage = zigPackage system;
      formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
    });
}
