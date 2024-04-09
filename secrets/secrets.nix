let
  tulip = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEGQB1RVrTnUl5JDIs19lzIJVGi60yuXB7zYCcwN/XxZ tulili@studio";
  systems = [ tulip ];
in
{
  "woodpecker.age".publicKeys = [ tulip ];
}
