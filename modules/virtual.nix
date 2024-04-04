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
      heroic
      gnome.gnome-boxes
      virt-viewer
      quickemu
      quickgui
      (writeScriptBin "lxc" ''
        ${lib.getExe pkgs.incus} $@
      '')
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
      incus.enable = true;
    };

    programs.virt-manager.enable = true;
  };
}
