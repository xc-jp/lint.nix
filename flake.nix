{
  description = "simple linting";
  outputs = _: { lib.lint-nix = import ./lint.nix; };
}
