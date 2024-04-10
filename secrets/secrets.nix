let
  antarctica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHu8sQ1hYD/NQFDVBd66B/R4EBhVmu8VOEuyeW7KaXqW root@antarctica";
  systems = [ antarctica ];
in
{
  "woodpecker.age".publicKeys = [ antarctica ]; # WOODPECKER_AGENT_SECRET, WOODPECKER_GITEA_CLIENT, WOODPECKER_GITEA_SECRET
  # openssl rand -base64 32
  "action-runner.age".publicKeys = [ antarctica ]; # TOKEN
}
