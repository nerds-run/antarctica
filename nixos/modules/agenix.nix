{ config, lib, ... }:
let
  cfg = config.antarctica.secrets.agenix;

  secretType = with lib; types.submodule ({ config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = config._module.args.name;
        defaultText = literalExpression "config._module.args.name";
        description = ''
          Name of the file used in {option}`age.secretsDir`
        '';
      };
      file = mkOption {
        type = types.path;
        description = ''
          Age file the secret is loaded from.
        '';
      };
      path = mkOption {
        type = types.str;
        default = "${cfg.secretsDir}/${config.name}";
        defaultText = literalExpression ''
          "''${cfg.secretsDir}/''${config.name}"
        '';
        description = ''
          Path where the decrypted secret is installed.
        '';
      };
      mode = mkOption {
        type = types.str;
        default = "0400";
        description = ''
          Permissions mode of the decrypted secret in a format understood by chmod.
        '';
      };
      owner = mkOption {
        type = types.str;
        default = "0";
        description = ''
          User of the decrypted secret.
        '';
      };
      group = mkOption {
        type = types.str;
        default = "0";
        description = ''
          Group of the decrypted secret.
        '';
      };
      symlink = mkEnableOption "symlinking secrets to their destination" // { default = true; };
    };
  });

in
{
  options.antarctica.secrets.agenix = with lib; rec {
    enable = mkEnableOption "Agenix";
    rootDir = mkOption rec {
      description = "Root path of agenix operations";
      type = types.str;
      default = "/var/lib/agenix";
      example = default;
    };
    secretsDir = mkOption rec {
      description = "Path where secrets will be created to";
      type = types.str;
      default = "${rootDir.default}/keys";
      example = default;
    };
    secretsMountPoint = mkOption rec {
      description = "Path where secrets will be mounted to";
      type = types.str;
      default = "${rootDir.default}/secret-generations";
      example = default;
    };
    runtimeMount = mkOption rec {
      description = "Path where secrets must be mounted to on runtime";
      type = types.str;
      default = "/run/secrets";
      example = default;
    };
    sshdHostKeyDir = mkOption rec {
      description = "Path where host keys for SSH will be generated to";
      type = types.str;
      default = "${rootDir.default}/sshd";
      example = default;
    };
    extraSecrets = mkOption {
      type = types.attrsOf secretType;
      default = { };
      example = {
        very_cool = {
          file = "path";
          path = "/mount";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    age.identityPaths = [
      "/persist/system/${cfg.sshdHostKeyDir}/ssh_host_ed25519_key"
      "/persist/system/${cfg.sshdHostKeyDir}/ssh_host_rsa_key"
    ];
    age.secretsMountPoint = cfg.secretsMountPoint;
    age.secretsDir = cfg.secretsDir;
    age.secrets = lib.mkMerge [{
      action-runner = {
        file = ../../secrets/action-runner.age;
        path = "/run/secrets/action-runner.env";
      };
    }
      cfg.extraSecrets];
  };
}
