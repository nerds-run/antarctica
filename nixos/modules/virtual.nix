{ config
, pkgs
, lib
, ...
}:
with lib; let
  cfg = config.virtualisation.managed;
in
{
  options.virtualisation.managed.enable = lib.mkEnableOption "virtual";

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      quickemu
    ];

    virtualisation = {
      podman = {
        enable = true;
        autoPrune.enable = true;
        dockerSocket.enable = !(config.virtualisation.docker.enable);
        dockerCompat = !(config.virtualisation.docker.enable);
        defaultNetwork.settings.dns_enabled = true;
      };
      docker = {
        enable = true;
        daemon.settings = {
          insecure-registries = [
            "fqdn"
            "forgejo.dev.nerds.run:3030"
            "localhost:3030"
          ];
        };
      };
      libvirtd.enable = true;
    };
  };
}
