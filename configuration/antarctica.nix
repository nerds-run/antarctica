{ inputs
, pkgs
, config
, ...
}: rec {
  imports = [
    ./hardware-configuration.nix
    ../modules/virtual.nix
    ../modules/impermanence.nix
  ];

  system = {
    stateVersion = "24.05";
    nixos.impermanence.enable = true;
  };

  boot = {
    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 5;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_latest;
    kernel.sysctl."kernel.sysrq" = 1;
    binfmt = {
      emulatedSystems = [
        "aarch64-linux"
      ];
    };
  };

  services.qemuGuest.enable = true;

  services.cockpit = {
    enable = true;
    openFirewall = true;
  };

  services.openvscode-server = {
    user = "antarctica";
    enable = true;
    extraPackages = with pkgs; [
      (python3.withPackages
          (p: with p; [
            python-lsp-server
            pylsp-mypy
            pylsp-rope
            python-lsp-ruff
          ])
        )
        yaml-language-server
        tailwindcss-language-server
        clang-tools
        nil
        zls
        marksman
        rust-analyzer
        gopls
        ruff
        docker-ls
        vscode-langservers-extracted
        clojure-lsp
        dockerfile-language-server-nodejs    
    ];
  };

  users = {
    defaultUserShell = pkgs.nushell;
    mutableUsers = true;
    users.antarctica = {
      isNormalUser = true;
      initialPassword = "antarctica";
      extraGroups = [ "wheel" "libvirtd" "incus-admin" "qemu" ];
      shell = config.users.defaultUserShell;
    };
  };

  environment.localBinInPath = true;

  networking = {
    networkmanager.enable = true;
    hostName = "antarctica";
    nftables.enable = true;
  };

  zramSwap.enable = true;
  zramSwap.memoryPercent = 75;

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  hardware = {
    bluetooth.enable = true;
    opentabletdriver = {
      enable = true;
      daemon.enable = true;
    };
  };

  services.system76-scheduler.enable = true;

  nix = {
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 2d";
    };
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      use-xdg-base-directories = true;
    };
  };

  environment.systemPackages = with pkgs; [
    fuse
  ];

  nixpkgs.config.allowUnfree = true;
  virtualisation.managed.enable = true;
  security.sudo.enable = false;
  security.sudo-rs.enable = !(security.sudo.enable);

  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
    };
    useGlobalPkgs = true;
    users = {
      antarctica = _: {
        imports = [
          inputs.impermanence.nixosModules.home-manager.impermanence
          ../home-manager/configurations/antarctica.nix
        ];
      };
    };
  };
}
