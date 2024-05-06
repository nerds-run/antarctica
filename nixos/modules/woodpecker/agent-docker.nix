{ config, lib, ... }:
let
  cfg = config.antarctica.services.woodpecker;

  hasRunner = (name: builtins.elem name cfg.runners);
in
{
  config = lib.mkIf (cfg.enable && hasRunner "docker") {
    services.woodpecker-agents = {
      agents.docker = {
        enable = true;

        environment = {
          WOODPECKER_SERVER = "woodpecker.dev.nerds.run:${toString cfg.rpcPort}";
          WOODPECKER_MAX_WORKFLOWS = "10";
          WOODPECKER_BACKEND = "docker";
          WOODPECKER_FILTER_LABELS = "type=docker";
          WOODPECKER_HEALTHCHECK = "false";
        };

        environmentFile = [ cfg.secretFile ];

        extraGroups = [ "docker" ];
      };
    };

    # FIXME: figure out the issue
    services.unbound.resolveLocalQueries = false;

    # Adjust runner service for nix usage
    systemd.services.woodpecker-agent-docker = {
      after = [ "docker.socket" ]; # Needs the socket to be available
      # might break deployment
      restartIfChanged = false;
      
      serviceConfig = {
        User = "root";
        BindPaths = [
          "/var/run/docker.sock"
        ];
      };
    };
  };
}
