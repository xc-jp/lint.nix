{
  description = "simple linting toosl";
  outputs = _: { lib.mkLints = import ./.; };
}
