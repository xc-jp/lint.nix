# lint.nix

Simple linting and formatting framework using Nix.

`lint.nix` provides
  - derivations that only build successfully if your code conforms to linters and formatters
  - a script that automatically applies all formatters

## Example

In this simple example, we configure `lint.nix` to check our Haskell files with `hlint`, and format our Nix files with `nixpkgs-fmt`:

```nix
{
  inputs.lint-nix.url = "github:xc-jp/lint.nix";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; };
      lints = inputs.lint-nix.lib.lint-nix {
        inherit pkgs;
        src = ./.;
        formatters = {
          nixpkgs-fmt.ext = ".nix";
          nixpkgs-fmt.cmd = "cat $filename | ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
        };
        linters = {
          hlint.ext = ".hs";
          hlint.cmd = "${pkgs.hlint}/bin/hlint $filename --hint=${./hlint.yaml}";
        };
      };
    in {
      legacyPackages.${system}.lints = lints;
    };
}
```

With this setup
  - running `nix build .#lints.all-checks` will only build successfully if our linters report no errors, and our formatters produce no changes.
  - running `nix run .#lints.format-all` will format our entire repo using the configured formatters.

## Usage

`lint.nix` is a function that takes a configuration attribute set, and returns a collection of checks, tools and scripts.

The configuration attribute set should contain the following fields:

- **`pkgs`**: A nixpkgs set
- **`src`**: A nix path pointing to (usually) the root of the repository. Only files in this directory are considered.
- **`linters`**: An attribute set configuring individual linters, each should define two fields explained below. Defaults to `{ }`.
  - **`ext`**: An extension, or list of extensions, that this linter should be run on. Extensions should contain a leading period.
  - **`cmd`**: A shell script that should fail if there is an issue in `$filename`.
- **`formatters`**: An attribute set configuring individual formatters, each should define two fields explained below. Defaults to `{ }`.
  - **`ext`**: An extension, or list of extensions, that this formatter should be run on. Extensions should contain a leading period.
  - **`cmd`**: A shell script that should output a formatted version of `$filename` to `stdout`.

The result of calling `lint-nix` is an attribute set containing the following fields:

- **`formats.*`**: An attribute set containing, for every formatter, a derivation that only builds successfully if that formatter found no difference.
- **`lints.*`**: An attribute set containing, for every linter, a derivation that only builds successfully if that linter found no issues.
- **`formatters.*`**: An attribute set containing, for every formatter, a shell script that will run that formatter on every applicable file in the current working directory.
- **`all-formats`**: A derivation that only builds if no formatter found a difference.
- **`all-lints`**: A derivation that only builds if no linter found any issues.
- **`all-checks`**: A derivation that only builds if `all-formats` and `all-lints` build successfully.
- **`format-all`**: A shell script that will run every formatter on every applicable file in the current working directory.
