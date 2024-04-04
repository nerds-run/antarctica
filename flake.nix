# This flake was initially generated by fh, the CLI for FlakeHub (version 0.1.10)
{

  description = "Development environment for remote usage";


  inputs = {
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/*.tar.gz";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
  };


  outputs =
    { self
    , flake-schemas
    , nixpkgs
    , disko
    , home-manager
    , impermanence
    } @ inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });

      generateSystemConfiguration = hostName: system: device: nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs;
        };

        modules = [
          inputs.disko.nixosModules.disko
          inputs.impermanence.nixosModules.impermanence
          inputs.home-manager.nixosModules.home-manager
          (import ./disko-config.nix { inherit device; })
          ./configuration/${hostName}.nix
        ];
      };

    in
    {
      schemas = flake-schemas.schemas;

      nixosConfigurations = rec {
        default = antarctica;
        antarctica = generateSystemConfiguration "antarctica" "x86_64-linux" "/dev/vda";
      };

      formatter = forEachSupportedSystem ({ pkgs }: pkgs.nixpkgs-fmt);

      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            curl
            jq
            nixpkgs-fmt
          ];
        };
      });
    };
}
