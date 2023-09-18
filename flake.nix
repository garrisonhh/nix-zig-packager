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
      # this is a ridiculous hack but it works. stolen from zls
      readZon = filepath:
        with builtins; let
          text = readFile filepath;

          name =
            elemAt
              (match ".*name = \"(.*)\".*" text)
              0;

          version =
            elemAt
              (match ".*version = \"(.*)\".*" text)
              0;

          dependencies = fromJSON (
            concatStringsSep "" [
              "{"
              (replaceStrings [ "},\n" ] [ "}" ]
                (replaceStrings [ " ." " =" "\n" ", }" ] [ "\"" "\" :" "" "}" ]
                  (replaceStrings [ ".{" ] [ "{" ]
                    (concatStringsSep " "
                      (filter isString
                        (split "[ \n]+"
                          (elemAt
                            (match ".*dependencies = .[{](.*)[}].*" text)
                            0)))))))
            ]
          );
        in
        {
          inherit name version dependencies;
        };

      zigPackage = system: config:
        let
          inherit (pkgs.stdenv) mkDerivation;

          # config params
          params =
            {
              zigVersion = "master";
              zigBuildFlags = [ ];
            }
            // config;

          pkgs = (import nixpkgs) {
            inherit system;
            overlays = [
              zig-overlay.overlays.default
            ];
          };

          # read zon file
          zon = readZon "${params.src}/build.zig.zon";
        in
        mkDerivation {
          inherit (zon) name version;
          inherit (params) src zigBuildFlags;

          nativeBuildInputs = [
            pkgs.zigpkgs.${params.zigVersion}.hook
          ];
        };
    in
    flake-utils.lib.eachDefaultSystem (system: {
      templates.default = ./template;
      lib.zigPackage = zigPackage system;
      formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
    });
}
