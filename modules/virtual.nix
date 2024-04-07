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
      docker.enable = true;
      libvirtd.enable = true;
    };
  };
}
