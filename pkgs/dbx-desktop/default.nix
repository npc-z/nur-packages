{ lib
, stdenv
, fetchFromGitHub
, fetchPnpmDeps
, pnpmConfigHook
, nodejs_22
, pnpm_11
, rustPlatform
, pkg-config
, perl
, jq
, cargo-tauri
, desktop-file-utils
, copyDesktopItems
, imagemagick
, wrapGAppsHook3
, makeDesktopItem
, openssl
, webkitgtk_4_1
, gtk3
, libappindicator-gtk3
, libayatana-appindicator
, librsvg
, glib
, glib-networking
, dbus
, at-spi2-atk
, atkmm
, cairo
, gdk-pixbuf
, harfbuzz
, pango
, xdotool
, libx11
, libxext
, libxfixes
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "dbx-desktop";
  version = "0.5.77";

  src = fetchFromGitHub {
    owner = "t8y2";
    repo = "dbx";
    rev = "v${finalAttrs.version}";
    hash = "sha256-zKuxAhL+dFEunGHEw/0C6+EF36QgbbVTCV5Uwt40/Ug=";
  };

  # ── Step 1: vendor pnpm (npm) dependencies ──────────────────────── #
  # pnpm.fetchDeps downloads everything listed in pnpm-lock.yaml into  #
  # a content-addressed store path so the build sandbox has no network. #
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    # `fetcherVersion = 4` is supported for `pnpm_11`
    fetcherVersion = 4;
    # Update with the hash reported by a failed fixed-output build:
    #   nix build .#dbx-desktop 2>&1 | grep 'got:'
    hash = "sha256-iFr+nYvhdFO6Y3fOs3tlhQL/10rgY3f2T1CbjnNZ3Nc=";
  };

  # ── Step 2: vendor Cargo dependencies ───────────────────────────── #
  # Cargo.lock is vendored in-tree (from the pinned tag) so that no
  # import-from-derivation is needed at evaluation time.
  cargoDeps = rustPlatform.importCargoLock {
    lockFile = ./Cargo.lock;
    # Pin Git checkouts by package name + version (importCargoLock format).
    # The hash only depends on the commit SHA, so packages sharing a rev
    # share a hash.
    outputHashes = {
      "mysql-common-derive-0.32.2" = "sha256-fw1rDLNh0BByLHjS8Cgc7KQxdj3N51HVMHXvRyETsas=";
      "mysql_common-0.38.0" = "sha256-fw1rDLNh0BByLHjS8Cgc7KQxdj3N51HVMHXvRyETsas=";
      "mysql_async-0.37.0" = "sha256-WNp8cdlnoyE4nzwGDhibqLYQbRz9YrsITis59TId5K0=";
      "postgres-protocol-0.6.12" = "sha256-HRbYVSD7iIwG3m1tOGoIZy0xAZwALWIpTtakVSYPIYI=";
      "postgres-types-0.2.14" = "sha256-HRbYVSD7iIwG3m1tOGoIZy0xAZwALWIpTtakVSYPIYI=";
      "tokio-postgres-0.7.18" = "sha256-HRbYVSD7iIwG3m1tOGoIZy0xAZwALWIpTtakVSYPIYI=";
    };
  };

  # ── Native build tools (available during build, not linked) ──────── #
  nativeBuildInputs = [
    rustPlatform.rust.cargo
    rustPlatform.rust.rustc
    rustPlatform.cargoSetupHook
    nodejs_22
    pnpm_11
    pnpmConfigHook
    pkg-config
    perl
    jq
    cargo-tauri # tauri CLI — needed to properly embed frontend assets
    desktop-file-utils # for `desktop-file-validate`
    copyDesktopItems # installs desktopItem into share/applications
    imagemagick # generates correctly sized hicolor icons
    wrapGAppsHook3 # wraps binary with GTK3/WebKit env
  ];

  # ── Desktop entry (freedesktop .desktop file) ────────────────────── #
  # Built with `makeDesktopItem` so it is validated against the spec
  # at build time. Icon name "dbx" resolves via the hicolor theme
  # (the installPhase copies PNGs into share/icons/hicolor/<size>/apps).
  desktopItem = makeDesktopItem {
    name = "dbx";
    type = "Application";
    # Renamed from upstream's "dbx" so it does not collide with the official
    # `@dbx-app/cli` package, which also installs a `dbx` executable.
    exec = "dbx-desktop %u";
    icon = "dbx";
    desktopName = "DBX";
    genericName = "Database Management Tool";
    comment = "Open-source database management tool for 70+ databases";
    categories = [ "Development" "Database" ];
    keywords = [
      "database"
      "sql"
      "client"
      "mysql"
      "postgresql"
      "mongodb"
      "redis"
    ];
    startupWMClass = "DBX";
    terminal = false;
    mimeTypes = [ "application/sql" "x-scheme-handler/dbx" ];
  };

  # ── Linked libraries (present at both build and runtime) ─────────── #
  buildInputs = [
    openssl
    openssl.dev
    webkitgtk_4_1
    gtk3
    libappindicator-gtk3
    libayatana-appindicator # provides libayatana-appindicator3.so.1 (dlopen'd at runtime)
    librsvg
    glib
    glib-networking
    dbus
    at-spi2-atk
    atkmm
    cairo
    gdk-pixbuf
    harfbuzz
    pango
    xdotool
    libx11
    libxext
    libxfixes
  ];

  # ── Environment variables ────────────────────────────────────────── #
  PKG_CONFIG_PATH = lib.makeSearchPath "lib/pkgconfig" [
    openssl.dev
    webkitgtk_4_1.dev
    gtk3.dev
    glib.dev
    cairo.dev
    gdk-pixbuf.dev
    harfbuzz.dev
    pango.dev
    at-spi2-atk.dev
  ];
  OPENSSL_DIR = "${openssl.dev}";
  OPENSSL_LIB_DIR = "${openssl.out}/lib";
  OPENSSL_INCLUDE_DIR = "${openssl.dev}/include";

  # Tauri reads the version from this env var during build
  TAURI_SKIP_DEVSERVER_CHECK = "true";

  # ── Runtime library path injection ───────────────────────────────── #
  # libappindicator-sys uses dlopen() at runtime to load the appindicator
  # shared library. dlopen() does NOT honour the binary's RPATH — it only
  # searches LD_LIBRARY_PATH and system paths. In a Nix derivation the
  # library lives in the store, not in /usr/lib, so we must inject the
  # path explicitly into the wrapGAppsHook3 C-wrapper.
  #
  # IMPORTANT: wrapGAppsHook3 uses its own `gappsWrapperArgs` bash array
  # (NOT `makeWrapperArgs`) — inject via preFixup before the hook runs.
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ webkitgtk_4_1 gtk3 libappindicator-gtk3 libayatana-appindicator librsvg glib glib-networking dbus at-spi2-atk atkmm cairo gdk-pixbuf harfbuzz pango xdotool libx11 libxext libxfixes ]}"
    )
  '';

  # ── Build phases ─────────────────────────────────────────────────── #
  preConfigure = ''
    export HOME=$TMPDIR
    # The "packageManager" field in package.json causes pnpm to enforce a
    # specific version via corepack, which requires network access in sandbox.
    # Use jq (not sed) to drop the key so we don't leave a trailing comma
    # in the file. A naive `sed '/"packageManager"/d'` removes only the
    # value line and leaves `,\n}` behind, which pnpm then refuses to parse.
    if [ -f package.json ]; then
      jq 'del(.packageManager)' package.json > package.json.tmp \
        && mv package.json.tmp package.json
    fi
  '';

  buildPhase = ''
    runHook preBuild

    # ① Use `tauri build --no-bundle` which:
    #   - Runs `beforeBuildCommand` (pnpm build) to compile the Vue/TS frontend
    #   - Sets TAURI_ENV_* variables so the Rust build embeds the dist/ assets
    #   - Properly initialises the Tauri IPC layer inside the binary
    #   - Skips platform-specific installer/bundle creation (AppImage, deb, …)
    #
    # DO NOT replace this with a bare `cargo build -p dbx`.
    # A raw cargo build skips Tauri's asset-embedding pipeline, so the
    # WebView has no bundled frontend to load → __TAURI_INTERNALS__ is
    # never injected → isTauriRuntime() returns false → the UI falls back
    # to HTTP mode and immediately gets "Connection refused".
    cargo tauri build --no-bundle

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    # tauri build --no-bundle puts the binary at target/release/dbx.
    # Install it as `dbx-desktop` (instead of upstream's `dbx`) so it does
    # not collide with the official `@dbx-app/cli` package, which also
    # installs a `dbx` executable.
    cp target/release/dbx $out/bin/dbx-desktop

    # Install icon files into the hicolor theme tree so that all
    # desktop environments (GNOME Shell, KDE Plasma, XFCE, etc.) can
    # find the right size: task-switcher (32px), panel (48px),
    # launcher (64px), app-menu (128px), HiDPI launcher (256px).
    if [ -d src-tauri/icons ]; then
      for size in 32 128; do
        if [ -f "src-tauri/icons/''${size}x''${size}.png" ]; then
          mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
          cp "src-tauri/icons/''${size}x''${size}.png" \
            "$out/share/icons/hicolor/''${size}x''${size}/apps/dbx.png"
        fi
      done

      # @2x retina variant (128x128@2x) → install as 256x256
      if [ -f "src-tauri/icons/128x128@2x.png" ]; then
        mkdir -p "$out/share/icons/hicolor/256x256/apps"
        cp "src-tauri/icons/128x128@2x.png" \
          "$out/share/icons/hicolor/256x256/apps/dbx.png"
      fi

      # Generate missing common sizes so hicolor directory metadata
      # always matches the actual PNG dimensions.
      for size in 16 48 64; do
        mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
        if [ "$size" -le 32 ] && [ -f "src-tauri/icons/32x32.png" ]; then
          src="src-tauri/icons/32x32.png"
        elif [ -f "src-tauri/icons/128x128.png" ]; then
          src="src-tauri/icons/128x128.png"
        else
          continue
        fi
        magick "$src" -resize "''${size}x''${size}" \
          "$out/share/icons/hicolor/''${size}x''${size}/apps/dbx.png"
      done

      # Install the full-size icon.png as the scalable fallback so that
      # Tauri's default_window_icon() and the taskbar always have an image.
      if [ -f "src-tauri/icons/icon.png" ]; then
        mkdir -p "$out/share/icons/hicolor/512x512/apps"
        cp "src-tauri/icons/icon.png" \
          "$out/share/icons/hicolor/512x512/apps/dbx.png"
      fi
    fi

    # Register the freedesktop .desktop file so app launchers (GNOME
    # Shell, KDE Plasma, etc.) can discover the application.
    mkdir -p $out/share/applications
    cp ${finalAttrs.desktopItem}/share/applications/dbx.desktop \
      $out/share/applications/dbx.desktop
    ${desktop-file-utils}/bin/desktop-file-validate \
      $out/share/applications/dbx.desktop

    runHook postInstall
  '';

  # ── Metadata ─────────────────────────────────────────────────────── #
  meta = with lib; {
    description = "DBX desktop — open-source database management tool (Tauri 2)";
    longDescription = ''
      DBX is a lightweight (~15 MB) database management tool supporting 70+
      databases. Built with Tauri 2, Vue 3, and Rust. No Java, no Chromium.
    '';
    license = licenses.asl20;
    homepage = "https://github.com/t8y2/dbx";
    maintainers = with maintainers; [ ];
    platforms = platforms.linux; # macOS/Windows need platform-specific adjustments
    mainProgram = "dbx-desktop";
  } // {
    # Non-lib meta: absolute path to the installed .desktop file so
    # `nix profile install`/home-manager can register it with the
    # user's desktop environment.
    desktopFile = "${placeholder "out"}/share/applications/dbx.desktop";
  };
})
