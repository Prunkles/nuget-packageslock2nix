{
  inputs = {
    nixpkgs.url = "github:Prunkles/nixpkgs?rev=2ef1fbeb11ca3fa0c350ba31c3b998a4e116bcc6";
    nuget-packageslock2nix = {
      #url = "github:mdarocha/nuget-packageslock2nix/main";
      url = "../.";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nuget-packageslock2nix, ... }: {
    packages.x86_64-linux.default =
      let
        pkgs = import nixpkgs { system = "x86_64-linux"; };
      in
      pkgs.buildDotnetModule {
        pname = "example";
        version = "0.0.1";
        src = ./.;
        nugetDeps = nuget-packageslock2nix.lib {
          system = "x86_64-linux";
          name = "example";
          nugetConfig = ./NuGet.Config;
          lockfiles = [
            ./packages.lock.json
          ];
        };
      };

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

    devShells.x86_64-linux.default = let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
      pkgs.mkShell {
        buildInputs = with pkgs; [
          dotnet-sdk
        ];
      };
  };
}
