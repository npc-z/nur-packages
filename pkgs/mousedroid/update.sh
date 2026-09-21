#!/usr/bin/env bash
# Update one package of this repository to the latest upstream release.
#
# Usage:
#   ./pkgs/<name>/update.sh                       # newest stable release
#   UPDATE_VERSION=1.2.3 ./pkgs/<name>/update.sh  # pin an exact version
#   UPDATE_DEPS_ONLY=1 ./pkgs/<name>/update.sh    # re-derive hashes only
#
# Requires `nix-update` (and the `nix-prefetch-git` it shells out to) on
# PATH, e.g.:
#   nix shell --inputs-from . nixpkgs#nix-update -c ./pkgs/<name>/update.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

package="$(basename "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
package_dir="pkgs/$package"
if [[ ! -f "$package_dir/hashes.json" ]]; then
  echo "error: $package_dir/hashes.json is missing (see README: automatic updates)" >&2
  exit 1
fi
# Flakes only see files tracked by Git; an untracked hashes.json otherwise
# fails later with a confusing "not tracked by Git" evaluation error.
if ! git ls-files --error-unmatch "$package_dir/hashes.json" >/dev/null 2>&1; then
  echo "error: $package_dir/hashes.json is not tracked by Git." >&2
  echo "       Run: git add $package_dir/hashes.json" >&2
  exit 1
fi

# ── per-package settings ─────────────────────────────────────────────── #
# Only tags matching this regex are considered; mousedroid tags are
# two-component (v1.5), not three.
version_regex='^v([0-9]+\.[0-9]+)$'

args=(
  --flake
  # The releases API is paginated, so it stays correct even when upstream
  # publishes a burst of unrelated releases between two runs. The releases.atom
  # feed nix-update uses by default only lists the most recent releases and can
  # miss the wanted one entirely.
  --use-github-releases
  --version-regex "$version_regex"
  # Send version and hash rewrites to the data file instead of the expression.
  --override-filename "$package_dir/hashes.json"
)

if [[ -n "${UPDATE_DEPS_ONLY:-}" ]]; then
  # Re-derive only the dependency hashes, for the currently pinned nixpkgs.
  args+=(--version=skip --no-src)
elif [[ -n "${UPDATE_VERSION:-}" ]]; then
  args+=(--version="$UPDATE_VERSION")
fi

nix-update "${args[@]}" "$package"
