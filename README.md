# npc-z' Nix User Repository

**My personal [NUR repository](https://github.com/npc-z/nur-packages)**

![Build and populate cache](https://github.com/npc-z/nur-packages/workflows/Build%20and%20populate%20cache/badge.svg)
[![Cachix Cache](https://img.shields.io/badge/cachix-npc--z-blue.svg)](https://npc-z.cachix.org)

## How to use

> **NOTE**: To follow the following usage, you need to have [Nix](https://nixos.org/nix/) installed with `flakes` & `new-commands` enabled first.

Run packages directly from this repository (with cache):

```sh
nix run github:npc-z/nur-packages#some-package
```

Use this repository in `flake.nix`:

```nix
# flake.nix
{
  # the nixConfig here only affects the flake itself, not the system configuration!
  # for more information, see:
  #     https://nixos-and-flakes.thiscute.world/nixos-with-flakes/add-custom-cache-servers
  nixConfig = {
    # substituters will be appended to the default substituters when fetching packages
    extra-substituters = [ "https://npc-z.cachix.org" ];
    extra-trusted-public-keys = [ "npc-z.cachix.org-1:k0E/cLF09sxkG6MNGt9r3ZJCsEMM9/k4UL9O4zXvQ/k=" ];
  };

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

## Packages

<!-- Add your packages list here -->

| Package         | Description              |
| --------------- | ------------------------ |
| example-package | <!-- add description --> |
| microneo        | <!-- add description --> |
| mousedroid      | <!-- add description --> |
