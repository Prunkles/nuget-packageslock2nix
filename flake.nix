{
  #inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.nixpkgs = {
    url = "github:Prunkles/nixpkgs?rev=2ef1fbeb11ca3fa0c350ba31c3b998a4e116bcc6";
  };

  outputs = { nixpkgs, ... }:
    {
      lib = { system, name ? "project", lockfiles ? [], nugetConfig ? null }:
        with builtins;
        let
          pkgs = import nixpkgs { inherit system; };

          externalDeps = lockfile:
          let
            allDeps' = foldl' (a: b: a // b) { } (attrValues lockfile.dependencies);
            allDeps = map (name: { inherit name; } // (getAttr name allDeps')) (attrNames allDeps');
          in
          filter (dep: (hasAttr "contentHash" dep) && (hasAttr "resolved" dep)) allDeps;

          getNuget = { name, resolved, contentHash, ... }: pkgs.fetchurl {
            name = "${name}.${resolved}.nupkg";
            url = "https://www.nuget.org/api/v2/package/${name}/${resolved}";
            sha512 = contentHash;

            downloadToTemp = true;
            postFetch = ''
              mv $downloadedFile file.zip
              ${pkgs.zip}/bin/zip -d file.zip ".signature.p7s"
              mv file.zip $out
            '';
          };

          nugetConfigLib = import ./nuget-config/default.nix pkgs;

          getNugetWithConf =
            let
              nugetConfig' = nugetConfigLib.parseNugetConfig { nugetConfigText = builtins.readFile nugetConfig; };
            in
            { name, resolved, contentHash, ... }:
              let
                packageSourceIndex = nugetConfigLib.resolvePackageSourceIndex nugetConfig' name;
                r =
                  nugetConfigLib.fetchNuGetFromSourceIndex {
                    pname = name;
                    version = resolved;
                    inherit packageSourceIndex;
                    hash = "sha512-${contentHash}";
                  };
              in
              assert packageSourceIndex != null;
              r;

          getNuget' =
            if nugetConfig == null then
              getNuget
            else
              getNugetWithConf;

          joinWithDuplicates = name: deps: pkgs.runCommand name { preferLocalBuild = true; allowSubstitues = false; } ''
            mkdir -p $out
            cd $out
            ${pkgs.lib.concatMapStrings (x: ''
              mkdir -p "$(dirname ${pkgs.lib.escapeShellArg x.name})"
              ln -s -f ${pkgs.lib.escapeShellArg "${x}"} ${pkgs.lib.escapeShellArg x.name}
            '') deps}
          '';
          deps = map getNuget' (concatMap (src: externalDeps (fromJSON (readFile src))) lockfiles);
        in
        (joinWithDuplicates "${name}-deps" deps)
        // { sourceFile = null; };
    };
}

