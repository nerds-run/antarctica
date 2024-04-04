{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.programs.clitools;
in
{
  options = {
    programs.clitools.enable = lib.mkEnableOption {
      description = "Enable a CLI-based user experince";
      example = true;
      default = false;
    };
  };
  config = lib.mkIf cfg.enable {
    programs.fzf.enable = true;

    programs.atuin = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      enableBashIntegration = true;
    };

    programs.carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    programs.tmux = {
      enable = true;
      disableConfirmationPrompt = true;
      historyLimit = 10000;
      mouse = true;
      secureSocket = true;
      clock24 = true;
      newSession = true;
      terminal = "xterm-256color";
      keyMode = "vi";
      extraConfig = ''
        	set -sg escape-time 10
              	set -g @thumbs-osc52 1
              	set-window-option -g mode-keys vi
              	bind-key -T copy-mode-vi v send-keys -X begin-selection
              	bind-key -T copy-mode-vi C-v send-keys -X rectangle toggle
              	bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
              	
              	set -g @plugin catppuccin/tmux-mocha
              	set -g @plugin christoomey/vim-tmux-navigator
      '';
      plugins = with pkgs.tmuxPlugins; [
        tmux-fzf
        tmux-thumbs
        catppuccin
        sensible
        vim-tmux-navigator
      ];
    };

    programs.nushell.enable = true;
    programs.nushell.extraConfig = ''
      do --env {
          let ssh_agent_file = (
              $nu.temp-path | path join $"ssh-agent-($env.USER).nuon"
          )
    
          if ($ssh_agent_file | path exists) {
              let ssh_agent_env = open ($ssh_agent_file)
              if ($"/proc/($ssh_agent_env.SSH_AGENT_PID)" | path exists) {
                  load-env $ssh_agent_env
                  return
              } else {
                  rm $ssh_agent_file
              }
          }
    
          let ssh_agent_env = ^ssh-agent -c
              | lines
              | first 2
              | parse "setenv {name} {value};"
              | transpose --header-row
              | into record
          load-env $ssh_agent_env
          $ssh_agent_env | save --force $ssh_agent_file
      }

      $env.config.use_grid_icons = true
      $env.config.footer_mode = always #always, never, number_of_rows, auto
      $env.config.float_precision = 2
      $env.config.use_ansi_coloring = true
      $env.config.show_banner = false
    '';

    programs.nushell.extraEnv = pkgs.lib.concatMapStringsSep "\n" (string: string) (
      pkgs.lib.attrsets.mapAttrsToList
        (var: value:
          if (var != "XCURSOR_PATH" && var != "TMUX_TMPDIR")
          then "$env.${toString var} = ${toString value}"
          else "")
        config.home.sessionVariables
    );
    programs.zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
