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
      ".mozilla"
      ".thunderbird"
      ".vscode"
      ".vscodium"
      ".var"
      ".cache/tldr"
      ".cache/NuGetPackages"
      ".cache/nvim"
      ".cache/cargo"
      ".cache/chromium"
      ".cache/pre-commit"
      ".cache/direnv"
      ".config/obs-studio"
      ".config/news-flash"
      ".config/monophony"
      ".config/FreeTube"
      ".config/lagrange"
      ".config/GIMP"
      ".config/carapace"
      ".config/nix"
      ".config/libresprite"
      ".config/heroic"
      ".config/gh"
      ".config/WebCord"
      ".config/lazygit"
      ".config/direnv"
      ".config/libvirt"
      ".config/kdeconnect"
      ".config/chromium"
      ".config/packer"
      ".config/vesktop"
      ".config/rclone"
      ".config/epiphany"
      ".config/Bitwarden"
      ".local/share/flakehub"
      ".local/share/epiphany"
      ".local/share/in.cinny.app"
      ".local/share/cinny"
      ".local/state/wireplumber"
      ".local/state/nvim"
      ".local/share/atuin"
      ".local/share/go"
      ".local/share/flatpak"
      ".local/share/keyrings"
      ".local/share/zoxide"
      ".local/share/dotnet"
      ".local/share/gnome-podcasts"
      ".local/share/news-flash"
      ".local/share/news_flash"
      ".local/share/direnv"
      ".local/share/nvim"
      ".local/share/krita"
      ".local/share/Steam"
      {
        directory = ".local/share/waydroid";
        method = "symlink";
      }
      {
        directory = ".local/share/gnome-boxes";
        method = "symlink";
      }
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
