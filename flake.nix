{
  description = "Reproducible QuickNotes build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f system;
          }) systems
        );
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          quicknotes = pkgs.buildGoModule {
            pname = "quicknotes";
            version = "0.1.0";

            src = ./app;

            vendorHash = null;

            env.CGO_ENABLED = "0";

            ldflags = [
              "-s"
              "-w"
            ];

            meta = {
              description = "QuickNotes";
              mainProgram = "quicknotes";
            };
          };
        in
        {
          inherit quicknotes;
          default = quicknotes;
        }
        // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          docker = pkgs.dockerTools.buildImage {
            name = "quicknotes";
            tag = "0.1.0";

            copyToRoot = pkgs.buildEnv {
              name = "quicknotes-root";
              paths = [
                quicknotes
              ];
              pathsToLink = [
                "/bin"
              ];
            };

            extraCommands = ''
              mkdir -p ./app
              install -d -m 0777 ./data
              cp ${./app/seed.json} ./app/seed.json
            '';

            config = {
              Entrypoint = [ "/bin/quicknotes" ];

              ExposedPorts = {
                "8080/tcp" = {};
              };

              User = "1000:1000";

              Env = [
                "ADDR=:8080"
                "DATA_PATH=/data/notes.json"
                "SEED_PATH=/app/seed.json"
              ];
            };
          };
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              go
              gopls
              golangci-lint
            ];
          };
        }
      );
    };
}
