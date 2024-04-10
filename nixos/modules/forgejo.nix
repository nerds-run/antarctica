{ config, lib, ... }:

let 
  cfg = config.antarctica.services.forgejo;
in {
  options.antarctica.services.forgejo = with lib; {
    enable = mkEnableOption "Forgejo";
    actions = mkOption {
      type = types.submodule (_: {
        options.enable = mkEnableOption "Gitea Actions";
      });
    };
    name = mkOption {
      type = types.str;
      default = "Antarctica Forgejo Service";
      example = "Forgejo Instance";
    };
    port = mkOption {
      type = types.port;
      default = 3030;
      example = 8080;
      description = "Forgejo WebUI port + everything else";
    };
  };

  config = with lib; mkIf cfg.enable rec {
   antarctica.secrets.agenix = {
      enable = true;
      extraSecrets = { 
        forgejo = {
          file = ../../secrets/action-runner.age;
          path = "${config.antarctica.secrets.agenix.runtimeMount}/action-runner.env";
        };
      };
    };    
        
    services.forgejo = {
      enable = true;
      dump.enable = true;
      dump.type = "tar.zst";
      lfs.enable = true;
      settings = {
        DEFAULT.APP_NAME = cfg.name;
        server = {
          DOMAIN = "forgejo.dev.nerds.run";
          HTTP_PORT = cfg.port;
        };
        webhook = {
          ALLOWED_HOST_LIST = "external,loopback";
        };
      };
    };

    services.gitea-actions-runner.instances = mkIf cfg.actions.enable {
      antarctica = {
        enable = true;
        name = "antarctica";
        url = config.services.forgejo.settings.server.ROOT_URL;
        labels =
          [
            "debian-latest:docker://node:20-bullseye"
            "ubuntu-latest:docker://node:20-bullseye"
          ];
        tokenFile = antarctica.secrets.agenix.extraSecrets.forgejo.path;
      };
    };
  }; 
}
