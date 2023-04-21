# lint.nix

Very simple linting/formatting infrastructure for Nix.
Will give you
  - derivations that only build successfully if your code conforms to linters and formatters, mainly for use on CI
  - a `format-all` script that automatically applies all formatters

## Configuration

The `lint.nix` file is a function that takes an argument set that should contain the following fields.

- **`pkgs`**: A nixpkgs set
- **`src`**: A nix path pointing to (usually) the root of the repository. Only files in this directory are considered.
- **`linters`**: An attribute set configuring the individual linters. Every linter should define two fields:
  - **`ext`**: An extension, or list of extensions that this linter should be run on. Extensions should contain a leading period.
  - **`cmd`**: A shell script that should fail if there is an issue in `$filename`.
- **`formatters`**: An attribute set configuring the individual formatters. Every formatter should define two fields:
  - **`ext`**: An extension, or list of extensions that this formatter should be run on. Extensions should contain a leading period.
  - **`cmd`**: A shell script that should output a formatted version of `$filename` to `stdout`.

## Usage

The result of calling `lint.nix` is an attribute set containing a number of fields.

- **`formats.*`**: An attribute set containing, for every formatter, a derivation that only builds successfully if that formatter found no difference.
- **`lints.*`**: An attribute set containing, for every linter, a derivation that only builds successfully if that linter found no issues.
- **`formatters.*`**: An attribute set containing, for every formatter, a shell script that will run that formatter on every applicable file in the current working directory.
- **`all-formats`**: A derivation that only builds if no formatter found a difference.
- **`all-lints`**: A derivation that only builds if no linter found any issues.
- **`all-checks`**: A derivation that only builds if `all-formats` and `all-lints` build successfully.
- **`format-all`**: A shell script that will run every formatter on every applicable file in the current working directory.
