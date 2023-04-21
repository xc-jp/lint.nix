# lint.nix

Very simple linting/formatting infrastructure for Nix.
Will give you
  - derivations that only build successfully if your code conforms to linters and formatters, mainly for use on CI
  - a `format-all` script that automatically applies all formatters

### Overlay setup example

```nix
final: _:
let
  lint-nix = final.fetchFromGitHub {
    owner = "xc-jp" ;
    repo = "lint.nix" ;
  } ;
in
{
  lints = import lint-nix {
    inherit pkgs;
    src = ./..;
    linters = {
      hlint = {
        ext = ".hs";
        cmd = "${pkgs.hlint}/bin/hlint $filename --hint=${../hlint.ci.yaml}";
      };
    };
    formatters = {
      ormolu = {
        ext = ".hs";
        cmd = "${pkgs.ormolu}/bin/ormolu $filename";
      };
      nixpkgs-fmt = {
        ext = ".nix";
        cmd = "cat $filename | ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
      };
      cabal-fmt = {
        ext = ".cabal";
        cmd = "${pkgs.haskellPackages.cabal-fmt}/bin/cabal-fmt $filename";
      };
      clang-format = {
        ext = [ ".c" ".cpp" ".h" ".hpp" ".proto" ".cu" ".cuh" ];
        cmd = "${pkgs.clang-tools}/bin/clang-format $filename";
      };
    };
  };
}
```
