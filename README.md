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

| Package     | Description                                                         |
| ----------- | ------------------------------------------------------------------- |
| microneo    | Terminal Markdown editor that renders and edits in the same window  |
| mousedroid  | Transform your Android phone into a cross-platform mouse & keyboard |
| dbx-desktop | Lightweight database management tool for 70+ databases (Tauri 2)    |

## Automatic updates

[`update-packages.yml`](.github/workflows/update-packages.yml) runs every
Monday: for each package it checks upstream for a new release, verifies the
package builds, and opens (or refreshes) a pull request on the
`auto/update-<package>` branch. Today it maintains `dbx-desktop`; a new
package joins simply by following the convention below.

### Convention

1. **`pkgs/<name>/hashes.json`** holds every version-dependent value. It must
   contain `"version"`; the other keys are the fixed-output hashes used by the
   expression (`srcHash`, `pnpmDepsHash`, `cargoDepsHash`, `npmDepsHash`, …).
2. **`pkgs/<name>/default.nix` stays version-agnostic** — it reads the values,
   it never hardcodes them:

   ```nix
   let
     versionData = lib.importJSON ./hashes.json;
   in
   stdenv.mkDerivation (finalAttrs: {
     version = versionData.version;
     # src.hash = versionData.srcHash; etc.
   })
   ```

3. **`pkgs/<name>/update.sh`** is a copy of an existing one (the package name
   is derived from the script's own path) and only needs its `version_regex`
   adjusted if upstream tags are not plain `vX.Y.Z`.

The updater (`nix-update`) then rewrites `hashes.json` alone, so a bot pull
request only ever changes data — never packaging code.

### Updating by hand

```sh
# newest stable release
nix shell --inputs-from . nixpkgs#nix-update -c ./pkgs/dbx-desktop/update.sh

# or pin an exact version
UPDATE_VERSION=0.6.16 nix shell --inputs-from . nixpkgs#nix-update -c ./pkgs/dbx-desktop/update.sh
```

Then verify with `nix build .#dbx-desktop`.


