{ config, lib, ... }:

let
  cfg = config.antarctica.services.forgejo;
in
{
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
      dump.enable = false;
      dump.type = "tar.zst";
      lfs.enable = true;
      settings = {
        DEFAULT.APP_NAME = cfg.name;
        server = {
          DOMAIN = "forgejo.dev.nerds.run";
          HTTP_PORT = cfg.port;
        };
        actions = {
          DEFAULT_ACTIONS_URL = "https://github.com";
        };
        webhook = {
          ALLOWED_HOST_LIST = "external,loopback,woodpecker.dev.nerds.run";
        };
      };
    };

    services.gitea-actions-runner.instances = mkIf cfg.actions.enable {
      antarctica = {
        enable = true;
        name = "antarctica";
        url = config.services.forgejo.settings.server.ROOT_URL;
        settings = {
          log = {
            level = "debug";
          };
          options = "-v /var/run/podman/podman.sock:/var/run/podman/podman.sock";
          runner = {
            capacity = 5;
            timeout = "45m";
          };
          container = {
            privileged = true;
            valid_volumes = ["*"];
            force_pull = false;
          };
        };
        labels =
          [
            "debian-latest:docker://catthehacker/ubuntu:act-latest"
            "ubuntu-latest:docker://catthehacker/ubuntu:act-latest"
            "ubuntu-22.04:docker://catthehacker/ubuntu:act-latest"
            "ubuntu-20.04:docker://catthehacker/ubuntu:act-latest"
            "ubuntu-18.04:docker://catthehacker/ubuntu:act-latest"
          ];
        tokenFile = antarctica.secrets.agenix.extraSecrets.forgejo.path;
      };
    };
  };
}
