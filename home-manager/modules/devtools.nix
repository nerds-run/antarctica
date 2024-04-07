{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.programs.devtools;
in
{
  options = {
    programs.devtools.enable = lib.mkEnableOption {
      description = "Enable my managed development configuration";
      example = true;
      default = false;
    };
  };
  config = lib.mkIf cfg.enable {
    home.sessionVariables = {
      GOPATH = "${config.home.homeDirectory}/.local/share/go";
    };

    programs.git = {
      enable = false;
      signing.signByDefault = true;
      extraConfig = {
        gpg.format = "ssh";
        init.defaultBranch = "main";
        core.excludesfile = "${pkgs.writers.writeText "gitignore" ''
        .jj
        .jj/*
        /.jj
        /.git
        .git/*
        .direnv
        /.direnv
        .direnv/*
        ''}";
      };
    };

    xdg.configFile."libvirt/qemu.conf".text = ''
      nvram = [ "/run/libvirt/nix-ovmf/AAVMF_CODE.fd:/run/libvirt/nix-ovmf/AAVMF_VARS.fd", "/run/libvirt/nix-ovmf/OVMF_CODE.fd:/run/libvirt/nix-ovmf/OVMF_VARS.fd" ]
    '';

    programs.direnv = {
      enable = true;
      enableNushellIntegration = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };

    programs.helix = {
      enable = true;
      defaultEditor = true;
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
      settings = {
        theme = "boo_berry";
        editor = {
          line-number = "relative";
          mouse = false;
          middle-click-paste = false;
          auto-save = true;
          auto-pairs = false;
          lsp = {
            display-messages = true;
            display-inlay-hints = true;
          };
          whitespace.render = {
            tab = "all";
            nbsp = "none";
            nnbsp = "none";
            newline = "none";
          };
          file-picker = {
            hidden = false;
          };
        };
      };
    };

    programs.yazi.enable = true;

    programs.zellij = {
      enable = true;
    };

    home.packages = with pkgs; [
      waypipe
      unzip
      git
      ollama
      buildah
      gh
      glab
      fd
      ripgrep
      sbctl
      podman-compose
      tldr
      jq
      yq
      scc
      just
      iotop
      nix-prefetch-git
      pre-commit
      fh
      trashy
      android-tools
      wormhole-rs
      lldb
      gdb
      bubblewrap
      just
      cage
      distrobox
      cosign
      jsonnet
      kubernetes-helm
      kind
      go-task
      kubectl
      talosctl
      jujutsu
      melange
      dive
      earthly
      poetry
      gdu
      asciinema
      maturin
      bun
      act
      wasmer
    ];
  };
}
