{
  inputs.zig-packager.url = github:garrisonhh/nix-zig-packager;

  outputs = { self, nixpkgs, zig-packager, ... }:
    let
      system = "x86_64-linux";

      pkgs = (import nixpkgs) {
        inherit system;
        overlays = [
          zig-packager.overlays.default
        ];
      };
    in
    {
      packages.${system}.default = pkgs.buildZig11Package {
        src = self;
        inherit system;
      };
    };
}
