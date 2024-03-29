{ linters ? { }
, formatters ? { }
, src
, pkgs
, diffCmd ? ''diff --unified "$filename" "$formatted"''
}:
let
  inherit (pkgs) lib;

  ensureList = x: if builtins.isList x then x else [ x ];

  # Parse the configuration attrset and apply the arguments to f.
  # f will be one of checkLinting, checkFormatting, runFormatter.
  applyLint = f: builtins.mapAttrs (name: { ext, cmd }: f name (ensureList ext) cmd);
  applyFormat = f: builtins.mapAttrs (name: { ext, cmd, stdin ? false }: f name (ensureList ext) cmd stdin);

  # I would love to use a rec here but "formatters" would shadow
  result =
    let
      formats = applyFormat checkFormatting formatters;
      lints = applyLint checkLinting linters;
      all-formats = pkgs.linkFarmFromDrvs "all-formats" (builtins.attrValues formats);
      all-lints = pkgs.linkFarmFromDrvs "all-lints" (builtins.attrValues lints);
      formatter-runners = applyFormat runFormatter formatters;
    in
    {
      inherit lints formats all-lints all-formats;
      all-checks = pkgs.linkFarmFromDrvs "all-checks" [ all-formats all-lints ];
      format-all = pkgs.writeShellScriptBin "format-all" (lib.concatStringsSep "\n" (lib.mapAttrsToList (name: drv: "${drv}/bin/run-${name}") formatter-runners));
      formatters = formatter-runners;
    };

  findPattern = lib.concatMapStringsSep " -or " (ext: "-name '*${ext}'");
  gitPattern = lib.concatMapStringsSep " " (ext: "'*${ext}'");
  commaSep = lib.concatStringsSep ", ";

  formatCmd = command: stdin:
    if stdin then ''
      (${command}) < "$filename" > "$formatted"
    '' else ''
      cp -T --no-preserve=mode "$filename" "$formatted"
      filename="$formatted"
      (${command})
    '';

  # Results in a derivation that logs diffs w.r.t. some formatter.
  # Builds successfully only if there are no diffs.
  checkFormatting = name: exts: command: stdin:
    pkgs.runCommandLocal "${name}-formatting-check" { } ''
      echo "Running ${name} on ${commaSep exts} files"
      set -o pipefail

      foundDiff=0
      diffs=()
      TEMP=$(mktemp -d)

      (
      while IFS= read -r -d "" filename; do

        formatted="$TEMP/formatted.''${filename##*.}"

        (${formatCmd command stdin})

        if ! ${diffCmd} > "$formatted.diff" ; then

          foundDiff=1
          filenameClean=''${filename#${src}/}
          diffs+=($filenameClean)

          echo "${name} diff in $filenameClean:"

          # Make sure to indent the diff output so it doesn't trigger a
          # buildkite collapsable section.
          sed -e 's/^/    /' "$formatted.diff"
          echo
        fi

      done < <(find "${src}" -type f \( ${findPattern exts} \) -print0)

      if [[ ! $foundDiff -eq 0 ]]; then
        echo "Error, ${name} found differences in:"
        printf '    %s\n' "''${diffs[@]}"
        echo "When running the command:"
        filename='$filename'
        echo "    $(basename "${command}")${lib.optionalString stdin " < $filename"}"
        exit 1
      fi
      ) | tee -a "$out"
    '';

  # shell script that runs the given formatter in place
  runFormatter = name: exts: command: stdin:
    pkgs.writeShellScriptBin "run-${name}" ''
      echo "Running ${name} on ${commaSep exts} files:"
      set -o pipefail

      TEMP=$(mktemp -d)

      while IFS= read -r filename; do

        formatted="$TEMP/formatted.''${filename##*.}"

        (${formatCmd command stdin})

        if ! ${diffCmd} > "$formatted.diff" ; then

          echo "diff:"
          sed -e 's/^/      /' "$formatted.diff"
          echo
          if [[ -s "$formatted" ]]
          then
            cat $formatted > $filename
          else
            echo "Formatted file $(basename $filename) is empty"
          fi
        fi

      done < <(git ls-files ${gitPattern exts})
    '';

  checkLinting = name: exts: command:
    pkgs.runCommandLocal "${name}-lints" { } ''
      echo "Running ${name} on ${commaSep exts} files"

      foundErr=0
      errs=()

      (
      while IFS= read -r -d "" filename; do
        filenameClean=''${filename#${src}/}
        if !(${command}); then
          echo "Error in file $filenameClean"
          foundErr=1
          errs+=($filenameClean)
        fi
      done < <(find "${src}" -type f \( ${findPattern exts} \) -print0)

      if [[ $foundErr -eq 0 ]]; then
        echo "Success, ${name} exited with code 0."
      else
        echo "Error, ${name} had non-zero exit code for:"
        printf '    %s\n' "''${errs[@]}"
        echo "When running the command:"
        filename='$filename'
        echo "    $(basename "${command}")"
        exit 1
      fi
      ) | tee -a "$out"
    '';

in
result
