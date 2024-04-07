{ ... }: {
  home.persistence."/persist/home/antarctica" = {
    allowOther = true;
    directories = [
      "Downloads"
      "Music"
      "Pictures"
      "Documents"
      "Videos"
      "Games"
      "opt"
      ".gnupg"
      ".ssh"
      ".nixops"
      ".wasmer"
      ".vscode"
      ".vscodium"
      ".var"
      ".cache/tldr"
      ".cache/NuGetPackages"
      ".cache/nvim"
      ".cache/cargo"
      ".cache/pre-commit"
      ".cache/direnv"
      ".config/nix"
      ".config/gh"
      ".config/lazygit"
      ".config/direnv"
      ".config/libvirt"
      ".config/rclone"
      ".local/share/flakehub"
      ".local/share/cinny"
      ".local/state/wireplumber"
      ".local/state/nvim"
      ".local/share/atuin"
      ".local/share/go"
      ".local/share/flatpak"
      ".local/share/keyrings"
      ".local/share/zoxide"
      ".local/share/dotnet"
      ".local/share/direnv"
      ".local/share/nvim"
      {
        directory = ".local/share/images";
        method = "symlink";
      }
      {
        directory = ".local/share/containers";
        method = "symlink";
      }
    ];
  };
}
