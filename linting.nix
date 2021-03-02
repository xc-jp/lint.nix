{ checkers
, src
, pkgs
}:
let
  inherit (pkgs) lib stdenv linkFarmFromDrvs runCommandLocal glibcLocales;

  # Results in a derivation that logs diffs w.r.t. some formatter.
  # Builds succesfully only if there are no diffs.
  checkFormatting = name: ext: command:
    let
      attrs =
        {
          LANG = "en_US.UTF-8";
          LC_ALL = "en_US.UTF-8";
        } // lib.optionalAttrs stdenv.isLinux {
          LOCALE_ARCHIVE = "${glibcLocales}/lib/locale/locale-archive";
        };
    in
    runCommandLocal "${name}-formatting-check" attrs ''
      echo "--- Running ${name} on ${ext} files"

      foundDiff=0
      diffs=()

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

      done < <(find "${src}" -type f -name '*${ext}' -print0)

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
  runFormatter = name: ext: command: ''
    echo "Running ${name} on *${ext} files:"

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

    done < <(git ls-files '*${ext}')
  '';

  linter = name: ext: command:
    runCommandLocal "${name}-lints" { } ''
      echo "--- Running ${name} on ${ext} files"

      foundErr=0
      errs=()

      (
      while IFS= read -r -d "" filename; do
        filenameClean=''${filename#${src}/}
        echo "Linting $filenameClean..."
        if !(${command}); then
          foundErr=1
          errs+=($filenameClean)
        fi
      done < <(find "${src}" -type f -name '*${ext}' -print0)

      if [[ $foundErr -eq 0 ]]; then
        echo "Success, ${name} exited with code 0."
      else
        echo "Error, ${name} had non-zero exit code for:"
        printf '    %s\n' "''${errs[@]}"
        exit 1
      fi
      ) | tee -a "$out"
    '';

  all-drvs = checkers checkFormatting linter;
  linkfarm = linkFarmFromDrvs "all-lints" all-drvs;
  format-all = pkgs.writeShellScriptBin "format-all" (pkgs.lib.concatStringsSep "\n" (checkers runFormatter (_: _: _: "")));
in
builtins.listToAttrs (map (drv: { name = drv.name; value = drv; }) (all-drvs ++ [ format-all linkfarm ]))
