[English](README.md) · [简体中文](README.zh-CN.md)

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

| Package                                            | Description                                                         |
| -------------------------------------------------- | ------------------------------------------------------------------- |
| [microneo](https://github.com/sollawen/microNeo)   | Terminal Markdown editor that renders and edits in the same window  |
| [mousedroid](https://github.com/darusc/Mousedroid) | Transform your Android phone into a cross-platform mouse & keyboard |
| [dbx-desktop](https://github.com/t8y2/dbx)         | Lightweight database management tool for 70+ databases (Tauri 2)    |

## Automatic updates

[`update-packages.yml`](.github/workflows/update-packages.yml) runs every
Monday: for each package it checks upstream for a new release, verifies the
package builds, and opens (or refreshes) a pull request on the
`auto/update-<package>` branch. Today it maintains `dbx-desktop`, `microneo`
and `mousedroid`; a new package joins simply by following the convention
below.

### Convention

1. **`pkgs/<name>/hashes.json`** holds every version-dependent value. It must
   contain `"version"`; the other keys are the fixed-output hashes used by the
   expression (`srcHash`, `pnpmDepsHash`, `cargoDepsHash`, `npmDepsHash`,
   `vendorHash`, …).
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
   adjusted if upstream tags are not plain `vX.Y.Z` — `mousedroid`, whose tags
   are two-component, uses `^v([0-9]+\.[0-9]+)$`.

The updater (`nix-update`) then rewrites `hashes.json` alone, so a bot pull
request only ever changes data — never packaging code.

### Why builds are pinned, and hash drift

[`build.yml`](.github/workflows/build.yml) evaluates the package set against
three nixpkgs channels (compatibility signal) but **builds against the nixpkgs
revision pinned in `flake.lock`** — the same revision the updater derives
hashes with.

That matters because some fixed-output hashes are a function of the nixpkgs
toolchain, not just of the upstream sources: `fetchPnpmDeps` output changes
when the pnpm version changes (`pkgs.pnpm` moved from 11.x to 12.x on
unstable), so a hash can never match a *moving* channel. For the same reason,
packages must pass their toolchain explicitly (e.g. `pnpm = pnpm_11`) instead
of relying on a default that nixpkgs may retarget.

When the toolchain does move — say a `flake.lock` bump — every package's
dependency hashes are re-derived automatically: the weekly workflow bumps
`flake.lock` first, then tries a normal update, and if the version is already
current it runs `update.sh` again with `UPDATE_DEPS_ONLY=1`, which refreshes
only the hashes.

Because of that, **`flake.lock` is owned by the bot**, not dependabot: the lock
bump and the hashes it invalidates travel in the same pull request, so a
lock-only change can never land with stale hashes behind it. Pass
`flake: false` on a manual run to update a package without bumping nixpkgs.

### The `UPDATE_TOKEN` secret

GitHub holds the CI run of a pull request opened by `github-actions[bot]` until
a user with write access approves it, so generated code cannot silently run
workflows that can reach secrets
([changelog](https://github.blog/changelog/2026-06-11-bot-created-pull-requests-can-run-workflows-if-approved/)).
The workflow therefore opens its pull request with a fine-grained PAT stored as
the `UPDATE_TOKEN` secret, which makes the pull request user-authored so its
`build.yml` checks start by themselves. Without the secret it falls back to
`GITHUB_TOKEN` and the pull request still opens — its checks just wait for an
approval click.

Token scopes (fine-grained, this repository only): `Contents: Read and write`,
`Pull requests: Read and write`. Create and store it with
[`scripts/setup-update-token.sh`](scripts/setup-update-token.sh), which walks
through the token page and writes the secret.

### Updating by hand

```sh
# newest stable release
nix shell --inputs-from . nixpkgs#nix-update -c ./pkgs/dbx-desktop/update.sh

# or pin an exact version
UPDATE_VERSION=0.6.16 nix shell --inputs-from . nixpkgs#nix-update -c ./pkgs/dbx-desktop/update.sh

# or re-derive the dependency hashes for the locked nixpkgs only
UPDATE_DEPS_ONLY=1 nix shell --inputs-from . nixpkgs#nix-update -c ./pkgs/dbx-desktop/update.sh
```

Then verify with `nix build .#dbx-desktop`.


