let
  antarctica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMFXZQVV6Que5yV1ToypCfUmcF+eXLRvMKRKwcLZIO2P root@antarctica";
in
{
  "woodpecker.age".publicKeys = [ antarctica ]; # WOODPECKER_AGENT_SECRET, WOODPECKER_GITEA_CLIENT, WOODPECKER_GITEA_SECRET
  # nix run nixpkgs#openssl -- rand -base64 32
  "action-runner.age".publicKeys = [ antarctica ]; # TOKEN
}
