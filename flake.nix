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
      buildZig11Package = config:
        let
          # config params
          params =
            {
              src = null;
              system = "x86_64-linux";
              isDependency = false;
              zigVersion = "0.11.0";
              zigBuildFlags = [ ];
              extraAttrs = {};
            }
            // config;

          inherit (params) system isDependency extraAttrs;

          # pkgs with zigpkgs
          pkgs = (import nixpkgs) {
            inherit system;
            overlays = [
              zig-overlay.overlays.default
            ];
          };

          nativeBuildInputs = with pkgs; [
            zigpkgs.${params.zigVersion}
            tree
          ];

          buildFlags = builtins.concatStringsSep " " params.zigBuildFlags;

          # get deps, name, version from zon
          zon = (import ./parseZon.nix) {
            inherit (pkgs) lib;
            input = builtins.readFile "${params.src}/build.zig.zon";
          };

          zigCacheDir = "~/.cache/zig";

          # shell script for caching deps
          cacheZigInputs =
            with builtins;
            let
              zigInputs =
                attrValues
                  (mapAttrs
                    (name: meta: {
                      inherit name;
                      inherit (meta) hash url;
                      src = buildZig11Package {
                        inherit system;
                        isDependency = true;
                        src = fetchTarball {
                          inherit (meta) url;
                        };
                      };
                    })
                    zon.dependencies);
            in
            concatStringsSep
              "\n"
              (map
                (meta: ''
                  ln -s ${meta.src.outPath}/source ${zigCacheDir}/p/${meta.hash}
                  cp -r ${meta.src.outPath}/cache/* ${zigCacheDir}/
                '')
                zigInputs);

          # helps propagate source code and zig cache for dependencies
          dependencyDerivation = pkgs.stdenvNoCC.mkDerivation {
            inherit (zon) name version;
            inherit (params) src zigBuildFlags;

            nativeBuildInputs = with pkgs; [
              zigpkgs.${params.zigVersion}
            ];

            dontConfigure = true;

            patchPhase = ''
              HOME=$NIX_BUILD_TOP

              mkdir -p ${zigCacheDir}/{p,z,tmp}
              ${cacheZigInputs}
            '';

            dontBuild = true;

            installPhase = ''
              mkdir -p $out
              cp -r ${params.src} $out/source
              cp -r ${zigCacheDir} $out/cache
            '';
          };

          packageDerivation = pkgs.stdenvNoCC.mkDerivation (extraAttrs // {
            inherit (zon) name version;
            inherit (params) src zigBuildFlags;

            nativeBuildInputs = with pkgs; [
              zigpkgs.${params.zigVersion}
              tree
            ];

            dontConfigure = true;

            patchPhase = ''
              HOME=$NIX_BUILD_TOP

              mkdir -p ${zigCacheDir}/{p,z,tmp}
              ${cacheZigInputs}

              tree -l ${zigCacheDir}
            '';

            buildPhase = ''
              zig build ${buildFlags} --global-cache-dir ${zigCacheDir}
            '';

            installPhase = ''
              cp -r zig-out/ $out
            '';
          });
        in
        if isDependency then dependencyDerivation else packageDerivation;
    in
    {
      templates.default = {
        path = ./template;
        description = "a basic zig packager template";
      };

      overlays.default = final: prev: {
        inherit buildZig11Package;
      };
    } // flake-utils.lib.eachDefaultSystem (system: {
      formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
    });
}
