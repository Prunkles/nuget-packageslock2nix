{ pkgs, lib, dotnet-sdk }:
{ nugetConfigFile }:
pkgs.writeScriptBin "nuget-config-fetch-base-addresses" ''
  set -e
  export PATH="${lib.makeBinPath [
    pkgs.jq
    pkgs.curl
    pkgs.gnugrep
    pkgs.gawk
    dotnet-sdk
  ]}"
  dotnetNugetListOutput="$(
    dotnet nuget list source --configfile ${lib.escapeShellArg nugetConfigFile}
  )"
  mapfile -t sources < <(
      echo "$dotnetNugetListOutput" \
      | awk '$3 == "[Enabled]" { print $2 }'
  )
  mapfile -t addresses < <(
      echo "$dotnetNugetListOutput" \
      | grep --no-group-separator -A1 '\[Enabled\]' \
      | grep -v '\[Enabled\]' \
      | awk '{ $1=$1; print }'
  )
  echo "{"
  for i in "''${!sources[@]}"; do
    source="''${sources[$i]}"
    index="''${addresses[$i]}"
    base_address=$(
      curl --compressed --netrc -fsL "$index" \
      | jq -r '.resources[] | select(."@type" == "PackageBaseAddress/3.0.0")."@id"'
    )
    base_address="''${base_address%/}" # Remove a trailing slash if exists
    echo "  \"$source\" = { packageBaseAddress = \"$base_address\"; };"
  done
  echo "}"
''
