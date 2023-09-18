# nix-zig-packager

are you annoyed with zig 0.11.0 incompatibility with nix? me too! this is a fix
before the zig compiler people figure it out (which I'm sure they will)

## adding to your flake

this flake provides an overlay which provides `buildZig11Package`. here's
a simple flake to build a zig project for `x86_64-linux`:

*unfortunately, you will still need to use the `--impure` flag for this to work*

```nix
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
```