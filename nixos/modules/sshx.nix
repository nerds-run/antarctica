{pkgs, lib, config, ...}:
let
  cfg = config.antarctica.services.sshx;
in {
  options.antarctica.services.sshx = with lib; {
    enable = mkEnableOption "ssh-server";
    package = mkPackageOption pkgs "sshx-server" {};
    port = mkOption {
      type = types.port;
      description = "Port that sshx-server will be running from";
      default = 8051;
    };
    redisPort = mkOption {
      type = types.port;
      description = "Port for Redis instance that will serve session data";
      default = 5090;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.sshx-server = {
      description = "SSHX Server";

      serviceConfig = {
        Type = "exec";
        ExecStart = "${lib.getExe cfg.package} --listen 0.0.0.0 --redis-url redis://forgejo.dev.nerds.run:${toString cfg.redisPort}";
        Restart = "on-failure";
      };

      wantedBy = [ "default.target" ];
    };
    services.redis.servers.sshx-redis = {
      enable = true;
      port = cfg.redisPort;
    };
  };
}
