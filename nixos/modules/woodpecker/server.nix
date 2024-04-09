{ config, lib, ... }:
let
  cfg = config.antarctica.services.woodpecker;
in
{
  config = lib.mkIf cfg.enable {
    services.woodpecker-server = {
      enable = true;

      environment = {
        WOODPECKER_OPEN = "true";
        WOODPECKER_HOST = "http://woodpecker.dev.nerds.run:${toString cfg.port}";
        WOODPECKER_DATABASE_DRIVER = "postgres";
        WOODPECKER_DATABASE_DATASOURCE = "postgres:///woodpecker?host=/run/postgresql";
        WOODPECKER_ADMIN = "${cfg.admin}";
        WOODPECKER_SERVER_ADDR = ":${toString cfg.port}";
        WOODPECKER_GRPC_ADDR = ":${toString cfg.rpcPort}";

        WOODPECKER_GITEA = "true";
        WOODPECKER_GITEA_URL = config.services.forgejo.settings.server.ROOT_URL;        

        WOODPECKER_LOG_LEVEL = "debug";
      };
    };

    systemd.services.woodpecker-server = {
      serviceConfig = {
        # Set username for DB access
        User = "woodpecker";

        BindPaths = [
          # Allow access to DB path
          "/run/postgresql"
        ];

        EnvironmentFile = [
          cfg.secretFile
        ];
      };
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "woodpecker" ];
      ensureUsers = [{
        name = "woodpecker";
        ensureClauses.superuser = true;
      }];
    };
  };
}
