{lib, buildGoModule, fetchFromGitHub}:
buildGoModule rec {
  pname = "microneo";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "sollawen";
    repo = "microNeo";
    rev = "v${version}";
    hash = "sha256-Ae8p1JoToQsZR1xAQV6u2YR8Fp3ZQdmAFIxTM/FoXOg=";
  };

  vendorHash = "sha256-bkPd6zB9e4q6N20wbKS8n8zGGITOoScajdPYv7Race0=";
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
    license = licenses.mit;
    mainProgram = "microneo";
    maintainers = with maintainers; [ ];
    platforms = platforms.all;
  };
}
