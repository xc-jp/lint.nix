{
  # Remove all null values in an attribute set
  removeNulls = obj:
    let nulls = builtins.filter (name: builtins.getAttr name obj == null)
      (builtins.attrNames obj);
    in builtins.removeAttrs obj nulls;
}
