# lint.nix

Simple linting and formatting framework using Nix.

`lint.nix` makes it easy to add a simple formatting/linting setup to your project.
It provides:
  - derivations that only build successfully if your code conforms to linters and formatters
  - scripts to automatically run formatters locally

## Example

In this simple example flake, we configure `lint.nix` to
- lint Python files with `ruff`,
- format Python files with `black`
- format C-like files with `clang-format`

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
        linters = {
          ruff.ext = ".py";
          ruff.cmd = "${pkgs.ruff}/bin/ruff $filename";
        };
        formatters = {
          black.ext = ".py";
          black.cmd = "${pkgs.black}/bin/black $filename";

          clang-format.ext = [ ".c" ".cpp" ".h" ".hpp" ".proto" ".cu" ".cuh" ];
          clang-format.cmd = "${pkgs.clang-tools}/bin/clang-format";
          clang-format.stdin = true;
        };
      };

    in {
      legacyPackages.${system}.lints = lints;
    };
}
```

With this setup,
  - running `nix build .#lints.all-checks` will only build successfully if no linter reports any errors, and no formatter produces any changes.
  - running `nix run .#lints.format-all` will format all files in the current directory using the configured formatters.

There are also more granular versions of the above commands, as described in the usage section below.

## Usage

`lint.nix` is a function that takes a configuration attribute set, and returns a collection of checks, tools and scripts.
The flake exposes this function under `lib.lint-nix`.

The configuration attribute set should contain the following fields:

- **`pkgs`**: A nixpkgs set
- **`src`**: A nix path pointing to (usually) the root of the repository. Only files in this directory are considered.
- **`formatters`**: An attribute set configuring individual formatters. Each should define the fields listed below. Defaults to `{ }`.
  - **`ext`**: An extension, or list of extensions, that this formatter should be run on. Extensions should contain a leading period.
  - **`cmd`**: Formatting shell script. The way this is expected to work depends on the below `stdin` setting.
  - **`stdin`**: Controls whether the formatting script reads from `stdin` (`true`) or runs in-place (`false`). Defaults to `false`.
    - If `true`, the shell script is expected to read its input from `stdin`, and output the formatted file to `stdout`.
    - If `false`, the shell script is expected to format the file pointed to by `$filename` in-place.
- **`linters`**: An attribute set configuring individual linters. Each should define the fields listed below. Defaults to `{ }`.
  - **`ext`**: An extension, or list of extensions, that this linter should be run on. Extensions should contain a leading period.
  - **`cmd`**: A shell script that should fail if there is an issue in `$filename`. Unlike formatters, linters do not (currently) have a `stdin` option. If your linter expects its input from `stdin`, you have to pass it manually using `cat $filename | <linter>`.
- **`diffCmd`**: Command to produce formatting diffs. Defaults to `diff --unified "$filename" "$formatted"`, but you might want to configure this to use something like [delta](https://github.com/dandavison/delta).

The result of calling `lint-nix` is an attribute set containing the following fields:

- **`formats.*`**: An attribute set containing, for every formatter, a derivation that only builds successfully if that formatter found no difference.
- **`lints.*`**: An attribute set containing, for every linter, a derivation that only builds successfully if that linter found no issues.
- **`formatters.*`**: An attribute set containing, for every formatter, a shell script that will run that formatter on every applicable file in the current working directory.
- **`all-formats`**: A derivation that only builds if no formatter found a difference.
- **`all-lints`**: A derivation that only builds if no linter found any issues.
- **`all-checks`**: A derivation that only builds if `all-formats` and `all-lints` build successfully.
- **`format-all`**: A shell script that will run every formatter on every applicable file in the current working directory.
