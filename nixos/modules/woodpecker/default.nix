{ lib, ... }:
{
  imports = [
    ./agent-docker.nix
    ./server.nix
  ];

  options.antarctica.services.woodpecker = with lib; {
    enable = mkEnableOption "Woodpecker CI";
    runners = mkOption {
      type = with types; listOf (enum [ "exec" "docker" ]);
      default = [ "docker" ];
      example = [ "exec" "docker" ];
      description = "Types of runners to enable";
    };
    admin = mkOption {
      type = types.str;
      default = "abanna";
      example = "admin";
      description = "Name of the admin user";
    };
    port = mkOption {
      type = types.port;
      default = 3040;
      example = 8080;
      description = "Internal port of the Woodpecker UI";
    };
    rpcPort = mkOption {
      type = types.port;
      default = 3041;
      example = 8080;
      description = "Internal port of the Woodpecker UI";
    };
    secretFile = mkOption {
      type = types.str;
      default = "/run/secrets/woodpecker.env";
      description = "Secrets to inject into Woodpecker server";
    };
    sharedSecretFile = mkOption {
      type = types.str;
      default = "/run/secrets/woodpecker.shared.env";
      description = "Shared RPC secret to inject into server and runners";
    };
  };
}
