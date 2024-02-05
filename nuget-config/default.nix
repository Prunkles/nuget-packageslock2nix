{ lib, ... }@pkgs: 
with builtins;
with lib.trivial;
let
  inherit (lib) escapeShellArg;
  maxBy = f: list: builtins.foldl' (acc: elem: if f elem > f acc then elem else acc) (builtins.head list) (builtins.tail list);
  parseXml = pkgs.callPackage ./parse-xml.nix {};
  parseNugetConfig = import ./parse-nuget-config.nix { inherit lib; inherit parseXml; };
  #nugetConfig = parseNugetConfig { nugetConfigText = readFile ./NuGet.Config; };

  findMostSpicificPattern = patterns:
    if patterns == [] then null else
    lib.findFirst
      (p: !lib.strings.hasInfix "*" p)
      (maxBy stringLength patterns)
      patterns;
  resolveNugetPackageSourceMappings = { packageSourceMapping }: packageName:
    pipe packageSourceMapping [
      (mapAttrs (_: { patterns }:
        let 
          matchingPatterns =
            filter (pattern:
              let patternRegex = "^${replaceStrings ["\\*"] [".*"] (lib.escapeRegex pattern)}$";
              in match patternRegex packageName != null
            ) patterns;
          bestMatchingPattern = findMostSpicificPattern matchingPatterns;
        in bestMatchingPattern
      ))
      (lib.filterAttrs (_: bestMatchingPattern: bestMatchingPattern != null))
      (lib.mapAttrsToList (packageSource: pattern: { inherit packageSource; inherit pattern; }))
      (groupBy (x: x.pattern))
      (gs:
        pipe gs [
          attrNames
          findMostSpicificPattern
          (p: getAttr p gs)
          (map (x: x.packageSource))
        ]
      )
    ];
  resolvePackageSourceIndex = { packageSources, packageSourceMapping }: packageName:
    let
      sourceMappingSources = resolveNugetPackageSourceMappings { inherit packageSourceMapping; } packageName;
      sourceMappingSource = lib.elemAt sourceMappingSources 0; # TODO
    in
    getAttr sourceMappingSource packageSources;

  fetchNuGetFromSourceIndex = { pname, version, packageSourceIndex, hash }:
    pkgs.fetchurl {
      name = "${pname}.${version}.nupkg";
      url = packageSourceIndex;
      downloadToTemp = true;
      postFetch = ''
        base_address=$(
          cat "$downloadedFile" \
          | ${pkgs.jq}/bin/jq -r '.resources[] | select(."@type" == "PackageBaseAddress/3.0.0")."@id"'
        )
        base_address="''${base_address%/}" # Remove a trailing slash if exists

        pkgFile="${escapeShellArg pname}.${escapeShellArg version}.nupkg"
        "''${curl[@]}" -C - --fail "$base_address/${escapeShellArg pname}/${escapeShellArg version}/$pkgFile" --output "$pkgFile"
        ${pkgs.zip}/bin/zip -d "$pkgFile" ".signature.p7s"
        mv "$pkgFile" $out
      '';
      inherit hash;
      passthru = {
        inherit pname;
        inherit version;
      };
    };
in
{
  #inherit nugetConfig;
  #nugetConfigFetchBaseAddresses = pkgs.callPackage ./nuget-config-fetch-base-addresses.nix {} { nugetConfigFile = ./NuGet.Config; };
  #res = resolvePackageSource { inherit (nugetConfig) packageSources packageSourceMapping; } "RonavBadapter";
  #res =
  #  fetchNuGetFromSourceIndex {
  #    pname = "FSharp.Core";
  #    version = "8.0.100";
  #    packageSourceIndex = "https://api.nuget.org/v3/index.json";
  #    hash = "sha512-ZOVZ/o+jI3ormTZOa28Wh0tSRoyle1f7lKFcUN61sPiXI7eDZu8eSveFybgTeyIEyW0ujjp31cp7GOglDgsNEg==";
  #  };
  inherit fetchNuGetFromSourceIndex;
  inherit parseNugetConfig;
  resolvePackageSourceIndex = nugetConfig: packageName:
    resolvePackageSourceIndex { inherit (nugetConfig) packageSources packageSourceMapping; } packageName;
}

