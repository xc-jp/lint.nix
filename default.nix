{ checks
, src
, pkgs
}:
let
  inherit (pkgs) lib stdenv linkFarmFromDrvs runCommandLocal glibcLocales;

  findPattern = lib.concatMapStringsSep " -or " (ext: "-type f -name '*${ext}'");
  gitPattern = lib.concatMapStringsSep " " (ext: "'*${ext}'");
  commaSep = lib.concatStringsSep ", ";
  ensureList = x: if builtins.isList x then x else [ x ];

  # Results in a derivation that logs diffs w.r.t. some formatter.
  # Builds succesfully only if there are no diffs.
  checkFormatting = name: exts: command:
    let
      localeAttrs.LC_ALL = "en_US.UTF-8";
      localeAttrs.buildInputs = [ pkgs.glibcLocales ];
    in
    runCommandLocal "${name}-formatting-check" localeAttrs ''
      echo "Running ${name} on ${commaSep exts} files"

      foundDiff=0
      diffs=()
      TEMP=$(mktemp -d)

      (
      while IFS= read -r -d "" filename; do

        formatted="$TEMP/formatter-${name}-res"

        (${command}) > $formatted

        if ! diff --unified "$filename" "$formatted" > "$formatted.diff" ; then

          foundDiff=1
          filenameClean=''${filename#${src}/}
          diffs+=($filenameClean)

          echo "${name} diff in $filenameClean:"

          # Make sure to indent the diff output so it doesn't trigger a
          # buildkite collapsable section.
          sed -e 's/^/    /' "$formatted.diff"
          echo
        fi

      done < <(find "${src}" ${findPattern exts} -print0)

      if [[ $foundDiff -eq 0 ]]; then
        echo "Success, ${name} found no differences."
      else
        echo "Error, ${name} found differences in:"
        printf '    %s\n' "''${diffs[@]}"
        exit 1
      fi
      ) | tee -a "$out"
    '';

  # Results in a shell script (string) that calls the given formatter
  runFormatter = name: exts: command:
    ''
      echo "Running ${name} on ${commaSep exts} files:"

      TEMP=$(mktemp -d)

      while IFS= read -r filename; do

        echo -n "  $filename... "
        formatted="$TEMP/formatter-${name}-res"

        (${command}) > $formatted

        if ! diff --unified "$filename" "$formatted" > "$formatted.diff" ; then

          echo "diff:"
          sed -e 's/^/      /' "$formatted.diff"
          echo
          if [[ -s "$formatted" ]]
          then
            cat $formatted > $filename
          else
            echo "Formatted file $(basename $filename) is empty"
          fi
        else
          echo "no change"
        fi

      done < <(git ls-files ${gitPattern exts})
    '';

  checkLinting = name: exts: command:
    runCommandLocal "${name}-lints" { } ''
      echo "Running ${name} on ${commaSep exts} files"

      foundErr=0
      errs=()

      (
      while IFS= read -r -d "" filename; do
        filenameClean=''${filename#${src}/}
        echo -n "Linting $filenameClean..."
        if !(${command}); then
          foundErr=1
          errs+=($filenameClean)
        fi
      done < <(find "${src}" ${findPattern exts} -print0)

      if [[ $foundErr -eq 0 ]]; then
        echo "Success, ${name} exited with code 0."
      else
        echo "Error, ${name} had non-zero exit code for:"
        printf '    %s\n' "''${errs[@]}"
        exit 1
      fi
      ) | tee -a "$out"
    '';

  named-checks = builtins.mapAttrs (name: drv: drv name) (checks {
    formatter = exts: cmd: name: checkFormatting name (ensureList exts) cmd;
    linter = exts: cmd: name: checkLinting name (ensureList exts) cmd;
  });

  named-runners = builtins.mapAttrs (name: drv: drv name) (checks {
    formatter = exts: cmd: name: runFormatter name (ensureList exts) cmd;
    linter = _: _: _: "";
  });

in
{
  all-lints = linkFarmFromDrvs "all-lints" (builtins.attrValues named-checks);
  format-all = pkgs.writeShellScriptBin "format-all" (pkgs.lib.concatStringsSep "\n" (builtins.attrValues named-runners));
} // named-checks
