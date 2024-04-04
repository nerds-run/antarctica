{ config
, ...
}: {
  imports = [
    ../modules/clitools.nix
    ../modules/devtools.nix
    ../modules/impermanence.nix
  ];

  programs = {
    home-manager.enable = true;
    devtools.enable = true;
    clitools.enable = true;
  };

  home = {
    username = "antarctica";
    homeDirectory = "/home/antarctica";
    stateVersion = "24.05";

    sessionVariables = rec {
      GNUPGHOME = "${XDG_DATA_HOME}/gnupg";
      NUGET_PACKAGES = "${XDG_CACHE_HOME}/NuGetPackages";
      TLDR_CACHE_DIR = "${XDG_CACHE_HOME}/tldr";
      CARGO_HOME = "${XDG_CACHE_HOME}/cargo";
      DOTNET_CLI_HOME = "${XDG_DATA_HOME}/dotnet";
      HISTFILE = "${XDG_STATE_HOME}/bash/history";
      XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
      XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
      XDG_STATE_HOME = "${config.home.homeDirectory}/.local/state";
      XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    };
  };
}
