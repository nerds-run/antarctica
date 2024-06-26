{ inputs
, pkgs
, config
, ...
}: 
let
  keys.tulip = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEGQB1RVrTnUl5JDIs19lzIJVGi60yuXB7zYCcwN/XxZ tulili@studio";
  keys.abanna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB0Xc+SiOJZ9r3WR+UqeZgOaRYl3ZOTCpcbVfvIHJu3t abanna@pop-os";
in {
  imports = [
    ./hardware-configuration.nix
    ../modules
  ];

  system = {
    stateVersion = "24.05";
    nixos.impermanence.enable = true;
  };
  services.qemuGuest.enable = true;

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

  antarctica = {
    services.woodpecker.enable = true;
    secrets.agenix.enable = true;
    services.forgejo.enable = true;
    services.forgejo.actions.enable = true;
    services.sshx.enable = true;
  };

  system.autoUpgrade = {
    enable = true;
    flake = inputs.self.outPath;
    flags = [
      "--update-input"
      "nixpkgs"
      "--no-write-lock-file"
      "-L"
    ];
    dates = "12:00";
    randomizedDelaySec = "45min";
  };

  programs.rust-motd = {
    enable = true;
    enableMotdInSSHD = true;
    settings = {
      banner = {
        color = "light_magenta";
        command = "hostnamectl hostname | ${pkgs.figlet}/bin/figlet | ${pkgs.lib.getExe pkgs.lolcat}";
      };
      uptime = {
        prefix = "Up";
      };
      filesystems = {
        root = "/";
        persist = "/persist";
      };
      memory = {
        swap_pos = "none";
      };
      service_status = {
        Cockpit = "cockpit";
        VSCode = "openvscode-server";
        Forgejo = "forgejo";
        "Gitea Actions" = "gitea-runner-antarctica";
        "Woodpecker CI" = "woodpecker-server";
        "Docker Registry" = "docker-registry";
        "SSHX server" = "sshx-server";
        "Hydra Server" = "hydra-server";
      };
    };
  };

  services.dockerRegistry = {
    enable = true;
    enableDelete = true;
    enableGarbageCollect = true;
    openFirewall = true;
  };

  # hydra-create-user alice --full-name 'Alice Q. User' --email-address 'alice@example.org' --password-prompt --role admin
  services.hydra = rec {
    enable = true;
    useSubstitutes = true; # please do not remove this, this will make it so hydra needs to rebuild literally everything
    hydraURL = "http://0.0.0.0:${toString port}";
    port = 3080;
    buildMachinesFiles = [ ];
    notificationSender = "hydra@antarctica";
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    allowSFTP = false;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = true;
    };
    extraConfig = ''
      AllowTcpForwarding yes
      X11Forwarding no
      AllowAgentForwarding no
      AllowStreamLocalForwarding no
      AuthenticationMethods publickey
    '';
    hostKeys = [
      {
        bits = 4096;
        path = "${config.antarctica.secrets.agenix.sshdHostKeyDir}/ssh_host_rsa_key";
        type = "rsa";
      }
      {
        path = "${config.antarctica.secrets.agenix.sshdHostKeyDir}/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
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
  users = rec {
    defaultUserShell = pkgs.nushell;
    mutableUsers = false;
    users = rec {
      root.openssh.authorizedKeys.keys = [
        keys.tulip
        keys.abanna
      ];

      antarctica = {
        isNormalUser = true;
        initialPassword = "antarctica";
        extraGroups = [ "wheel" "libvirtd" "qemu" ];
        shell = pkgs.nushell;
        openssh.authorizedKeys.keys = root.openssh.authorizedKeys.keys;
      };

      abanna = {
        isNormalUser = true;
        initialPassword = users.antarctica.initialPassword;
        extraGroups = users.antarctica.extraGroups;
        shell = users.antarctica.shell;
        openssh.authorizedKeys.keys = [
          keys.abanna
        ];
      };
      
      tulili = {
        isNormalUser = true;
        initialPassword = users.antarctica.initialPassword;
        extraGroups = users.antarctica.extraGroups;
        shell = defaultUserShell;
        openssh.authorizedKeys.keys = [
          keys.tulip
        ];
      };
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

  nixpkgs.config.allowUnfree = true;
  virtualisation.managed.enable = true;

  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';

  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
    };
    useGlobalPkgs = true;
    users = {
      antarctica = _: {
        imports = [
          inputs.persist-retro.nixosModules.home-manager.persist-retro
          inputs.impermanence.nixosModules.home-manager.impermanence
          ../../home-manager/configurations/antarctica.nix
        ];
      };
    };
  };
}
