{lib, buildGoModule, fetchFromGitHub}:
let
  # Version and every fixed-output hash live in ./hashes.json so that the
  # updater only ever rewrites data — never this expression. See README
  # "Automatic updates".
  versionData = lib.importJSON ./hashes.json;
in
buildGoModule rec {
  pname = "microneo";
  version = versionData.version;

  src = fetchFromGitHub {
    owner = "sollawen";
    repo = "microNeo";
    rev = "v${version}";
    hash = versionData.srcHash;
  };

  vendorHash = versionData.vendorHash;
  proxyVendor = true;

  doCheck = false;

  subPackages = [ "cmd/micro" ];

  ldflags = let
    t = "github.com/micro-editor/micro/v2/internal/util";
  in [
    "-s"
    "-w"
    "-X ${t}.Version=${version}"
    "-X ${t}.CommitHash=${src.rev}"
  ];

  preBuild = ''
    GOOS= GOARCH= go generate ./runtime
  '';

  postInstall = ''
    mv $out/bin/micro $out/bin/microneo
  '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "Terminal Markdown editor that renders and edits in the same window";
    longDescription = ''
      microNeo is a terminal-based Markdown editor that renders and edits in
      the same window — no split panes. It's based on the Micro editor with
      added Markdown rendering capabilities: headings, tables, code blocks,
      and links are rendered inline. Also supports syntax highlighting for
      100+ languages, mouse support, multiple cursors, and Lua plugins.
    '';
    homepage = "https://github.com/sollawen/microNeo";
    changelog = "https://github.com/sollawen/microNeo/releases/tag/v${version}";
    license = licenses.mit;
    mainProgram = "microneo";
    maintainers = with maintainers; [ ];
    platforms = platforms.all;
  };
}
