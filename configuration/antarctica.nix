{ inputs
, pkgs
, config
, ...
}: {
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

  system.autoUpgrade = {
    enable = true;
    flake = "github:nerds-run/antarctica#antarctica";
    flags = [
      "--update-input"
      "nixpkgs"
      "--no-write-lock-file"
      "-L" # print build logs
    ];
    dates = "12:00";
    randomizedDelaySec = "45min";
  };

  programs.rust-motd = {
    enable = true;
    enableMotdInSSHD = true;
    settings = {
      banner = {
        color = "blue";
        command = "hostnamectl hostname | ${pkgs.figlet}/bin/figlet | ${pkgs.lib.getExe pkgs.lolcat}";
      };
      uptime = {
        prefix = "Up";
      };
      filesystems = {
        root = "/";
        persist = "/persist";
      };
      service_status = {
        Cockpit = "cockpit";
        VSCode = "openvscode-server";
      };
    };
  };

  services.forgejo = {
    enable = true;
    dump.enable = true;
    dump.type = "tar.zst";
    lfs.enable = true;
    settings = {
      DEFAULT.APP_NAME = "Antarctica Forgejo Service";
      server.HTTP_PORT = 3030;    
    };
  };

  services.packagekit.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  services.cockpit = {
    enable = true;
    openFirewall = true;
  };

  services.openvscode-server = {
    enable = true;
    host = "0.0.0.0";
    withoutConnectionToken = true;
    extraPackages = with pkgs; [
      neovim
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
    nftables.enable = false;
    firewall.enable = pkgs.lib.mkForce false;
  };

  zramSwap.enable = true;
  zramSwap.memoryPercent = 75;

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

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
