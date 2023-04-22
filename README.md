# lint.nix

Simple linting and formatting framework using Nix.

`lint.nix` provides
  - derivations that only build successfully if your code conforms to linters and formatters
  - a script that automatically applies all formatters

The design goal is not to support 100% of possible linting setups, but to provide a very simple way of supporting 90% of setups.

## Example

In this simple example, we configure `lint.nix` to lint all Python files with `ruff`, format Python files with `black`, and format Nix files with `nixpkgs-fmt`:

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
          black.ext = ".py";
          black.cmd = "${pkgs.black}/bin/black $filename";

          nixpkgs-fmt.ext = ".nix";
          nixpkgs-fmt.cmd = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
          nixpkgs-fmt.stdin = true;
        };
        linters = {
          ruff.ext = ".py";
          ruff.cmd = "${pkgs.ruff}/bin/ruff $filename";
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
- **`formatters`**: An attribute set configuring individual formatters, each should define two fields explained below. Defaults to `{ }`.
  - **`ext`**: An extension, or list of extensions, that this formatter should be run on. Extensions should contain a leading period.
  - **`cmd`**: Formatting shell script. The way this is expected to work depends on the below `stdin` setting.
  - **`stdin`**: Controls whether the formatting script runs in-place or reads from `stdin`. Defaults to `false`.
    - If `true`, the shell script is expected to read its input from `stdin`, and output the formatted file to `stdout`.
    - If `false`, the shell script is expected to format the file pointed to by `$filename` in-place.
- **`linters`**: An attribute set configuring individual linters, each should define two fields explained below. Defaults to `{ }`.
  - **`ext`**: An extension, or list of extensions, that this linter should be run on. Extensions should contain a leading period.
  - **`cmd`**: A shell script that should fail if there is an issue in `$filename`. Unlike formatters, linters do not (currently) have a `stdin` option. If your linter expects its input from `stdin`, you have to pass it manually using `cat $filename | <linter>`.

The result of calling `lint-nix` is an attribute set containing the following fields:

- **`formats.*`**: An attribute set containing, for every formatter, a derivation that only builds successfully if that formatter found no difference.
- **`lints.*`**: An attribute set containing, for every linter, a derivation that only builds successfully if that linter found no issues.
- **`formatters.*`**: An attribute set containing, for every formatter, a shell script that will run that formatter on every applicable file in the current working directory.
- **`all-formats`**: A derivation that only builds if no formatter found a difference.
- **`all-lints`**: A derivation that only builds if no linter found any issues.
- **`all-checks`**: A derivation that only builds if `all-formats` and `all-lints` build successfully.
- **`format-all`**: A shell script that will run every formatter on every applicable file in the current working directory.
