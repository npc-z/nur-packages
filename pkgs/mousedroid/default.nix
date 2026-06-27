{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, wxwidgets_3_2
, asio
, makeDesktopItem
, copyDesktopItems
, makeBinaryWrapper
, hicolor-icon-theme
, android-tools
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "mousedroid";
  version = "1.5";

  src = fetchFromGitHub {
    owner = "darusc";
    repo = "Mousedroid";
    rev = "v${finalAttrs.version}";
    hash = "sha256-7qwADm+7m7TBJWlG7pqFtynb/RTcVm9O2z7Ri+ITm8g=";
  };

  sourceRoot = "source/server";

  postPatch = ''
    # Fix ASIO 1.38+ compatibility: from_string removed, use make_address
    substituteInPlace src/net/server.cpp \
      --replace-fail 'asio::ip::address::from_string' 'asio::ip::make_address'

    # Fix CMakeLists.txt: exclude Windows source files on non-Windows platforms
    substituteInPlace CMakeLists.txt \
      --replace-fail 'file(GLOB_RECURSE ALL_SRC src/*.cpp)' \
        'file(GLOB_RECURSE ALL_SRC src/*.cpp)
file(GLOB_RECURSE WIN32_SRC src/input/win32/*.cpp)
list(REMOVE_ITEM ALL_SRC ''${WIN32_SRC})'

    # Fix adb path: on Linux, use adb from PATH instead of ./adb
    substituteInPlace src/settingsmanager.cpp \
      --replace-fail './adb' '${android-tools}/bin/adb'
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    copyDesktopItems
    makeBinaryWrapper
  ];

  buildInputs = [
    wxwidgets_3_2
    hicolor-icon-theme
  ];

  cmakeFlags = [
    (lib.cmakeFeature "ASIO_PATH" "${asio}")
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "mousedroid";
      exec = "mousedroid";
      icon = "mousedroid";
      desktopName = "Mousedroid";
      comment = "Use your Android phone as a mouse & keyboard";
      categories = [ "Utility" ];
      terminal = false;
      startupNotify = false;
    })
  ];

  # Upstream CMakeLists.txt has no install target; install manually.
  # cmake does out-of-tree builds, so we stash the source dir first.
  preConfigure = ''
    mousedroidSrc=$PWD
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/Mousedroid $out/bin/mousedroid
    install -Dm644 "$mousedroidSrc/icon.png" $out/share/icons/hicolor/256x256/apps/mousedroid.png
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/mousedroid \
      --prefix PATH : ${lib.makeBinPath [ android-tools ]}
  '';

  meta = with lib; {
    description = "Transform your Android phone into a cross-platform mouse & keyboard";
    longDescription = ''
      Mousedroid is a versatile, cross-platform application that turns your
      Android phone into a remote input peripheral. Control your PC or laptop
      with a precision touchpad, a full QWERTY keyboard, or a dedicated
      numpad over Wi-Fi, Bluetooth, or USB.

      This package provides the desktop server component. The Android client
      APK is available separately from the GitHub releases page.

      Note: On Linux, the server requires access to /dev/uinput for mouse/keyboard
      input. You may need to add your user to the appropriate group or set up
      udev rules (see the project README).
    '';
    homepage = "https://github.com/darusc/Mousedroid";
    license = licenses.mit;
    mainProgram = "mousedroid";
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
})
