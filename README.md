# npc-z' Nix User Repository

WIP

## How to use

> **NOTE**: To follow the following usage, you need to have [Nix](https://nixos.org/nix/) installed with `flakes` & `new-comands` enabled first.

Run packages directly from this repository(no cache):

```sh
nix run github:npc-z/nur-packages#some-pakcage
```

Use this repository in `flake.nix`:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur-npc-z = {
      url = "github:npc-z/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nur-npc-z, ... }@inputs: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = with pkgs; [
            # Add packages from this repo
            nur-npc-z.packages.${system}.some-package
          ];
        })
      ];
    };
  };
}
```
