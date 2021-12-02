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
    checks = { formatter, linter, ... }: {
      ormolu = formatter ".hs" ''
        ${pkgs.ormolu}/bin/ormolu $filename
      '';

      nixpkgs-fmt = formatter ".nix" ''
        cat $filename | ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt
      '';

      cabal-fmt = formatter ".cabal" ''
        ${pkgs.haskellPackages.cabal-fmt}/bin/cabal-fmt $filename
      '';

      hlint = linter ".hs" ''
        ${pkgs.hlint}/bin/hlint $filename --hint=${../hlint.ci.yaml}
      '';

      clang-format = formatter [ ".c" ".cpp" ".h" ".hpp" ".proto" ".cu" ".cuh" ] ''
        ${pkgs.clang-tools}/bin/clang-format $filename
      '';
    };
  };
}
```
