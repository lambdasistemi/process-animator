{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    purescript-overlay = {
      url = "github:paolino/purescript-overlay/fix/remove-nodePackages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mkSpagoDerivation = {
      url = "github:jeslie0/mkSpagoDerivation";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      purescript-overlay,
      mkSpagoDerivation,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              purescript-overlay.overlays.default
              mkSpagoDerivation.overlays.default
            ];
          };
          nodeModules = pkgs.importNpmLock.buildNodeModules {
            npmRoot = ./.;
            nodejs = pkgs.nodejs_20;
          };
          mkBundle =
            { pname, module }:
            pkgs.mkSpagoDerivation {
              inherit pname;
              version = "0.1.0";
              src = ./.;
              spagoYaml = ./spago.yaml;
              spagoLock = ./spago.lock;
              nativeBuildInputs = [
                pkgs.purs
                pkgs.spago-unstable
                pkgs.esbuild
                pkgs.nodejs_20
              ];
              buildPhase = ''
                ln -s ${nodeModules}/node_modules node_modules
                # 1. Bundle npm deps (oxigraph → global)
                esbuild src/bootstrap.js \
                  --bundle \
                  --outfile=dist/deps.js \
                  --format=iife \
                  --platform=browser \
                  --loader:.wasm=binary \
                  --minify
                # 2. Bundle PureScript
                spago bundle --offline --module ${module}
                # 3. Concatenate: deps first, then app
                cat dist/deps.js dist/index.js > dist/bundle.js
                mv dist/bundle.js dist/index.js
                rm dist/deps.js
              '';
              installPhase = ''
                mkdir -p $out
                cp dist/index.html $out/
                cp dist/index.js $out/
              '';
            };
        in
        {
          default = mkBundle {
            pname = "process-animator";
            module = "Main";
          };
          lib = mkBundle {
            pname = "process-animator-lib";
            module = "Lib";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ purescript-overlay.overlays.default ];
          };
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.purs
              pkgs.spago-unstable
              pkgs.purs-tidy-bin.purs-tidy-0_10_0
              pkgs.purescript-language-server
              pkgs.esbuild
              pkgs.nodejs_20
              pkgs.just
            ];
          };
        }
      );
    };
}
