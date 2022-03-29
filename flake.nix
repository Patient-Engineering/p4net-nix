{
  description = "p4net";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosModule = (import ./module.nix);
  };
}
