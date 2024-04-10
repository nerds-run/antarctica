let
  antarctica = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPC6y19Dusx3+EfDXKGJeiAdg7i2ZDIDC62QQDFyWes4 root@antarctica";
  systems = [ antarctica ];
in
{
  "woodpecker.age".publicKeys = [ antarctica ]; # WOODPECKER_AGENT_SECRET, WOODPECKER_GITEA_CLIENT, WOODPECKER_GITEA_SECRET
  "action-runner.age".publicKeys = [ antarctica ]; # TOKEN
}
