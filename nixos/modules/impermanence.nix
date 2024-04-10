{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.system.nixos.impermanence;
in
{
  options.system.nixos.impermanence = {
    enable = lib.mkEnableOption "impermanence";
    home = lib.mkOption {
      default = { };
      type = lib.types.submodule (_: {
        options = {
          enable = lib.mkEnableOption "impermanence";
        };
      });
    };
  };

  config = mkIf cfg.enable {
    boot.initrd.postDeviceCommands = lib.mkAfter ''
      mkdir /btrfs_tmp
      mount /dev/root_vg/root /btrfs_tmp
      if [[ -e /btrfs_tmp/root ]]; then
          mkdir -p /btrfs_tmp/old_roots
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
      fi

      delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(${pkgs.btrfs-progs}/bin/btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$1"
      }

      for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +10); do
          delete_subvolume_recursively "$i"
      done

      ${pkgs.btrfs-progs}/bin/btrfs subvolume create /btrfs_tmp/root
      umount /btrfs_tmp
    '';

    fileSystems."/persist".neededForBoot = true;
    environment.persistence."/persist/system" = {
      hideMounts = true;
      directories = [
        "/etc/nixos"
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/lib/containers"
        "/var/lib/machines"
        "/var/lib/agenix"
        "/var/lib/libvirt"
        "/var/lib/docker"
        "/etc/NetworkManager/system-connections"
        config.services.kasmweb.datastorePath
        config.services.forgejo.stateDir
        config.services.dockerRegistry.storagePath
      ] ++ config.services.hydra.buildMachinesFiles;
      files = [
        "/etc/machine-id"
      ];
    };

    programs.fuse.userAllowOther = true;
  };
}
