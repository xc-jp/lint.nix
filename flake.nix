{
  description = "simple Nix linting tools";
  outputs = _: { lib.mkLints = import ./.; };
}
