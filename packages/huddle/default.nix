{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  bun,
  makeWrapper,
}:

buildNpmPackage rec {
  pname = "huddle";
  version = "0.1.0-unstable-2026-05-01";

  src = fetchFromGitHub {
    owner = "takeachangs";
    repo = "huddle";
    rev = "1e033a75398421a729eed0e55db638c277979b4e";
    hash = "sha256-NY1fBd0pg/4g6vBFuNBPSgbu97orGwX2Rw7nBuh9loE=";
  };

  npmDepsHash = "sha256-JTJH/F6sN5QKvqujr0DZY4L+Dv+lNMYZ7clCOIVW3wo=";

  nativeBuildInputs = [ makeWrapper ];
  npmInstallFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/huddle" "$out/bin"
    cp -R . "$out/lib/huddle"

    makeWrapper ${lib.getExe bun} "$out/bin/huddle" \
      --prefix PATH : ${lib.makeBinPath [ bun ]} \
      --add-flags "$out/lib/huddle/src/cli/index.ts"
    makeWrapper ${lib.getExe bun} "$out/bin/huddle-mcp" \
      --prefix PATH : ${lib.makeBinPath [ bun ]} \
      --add-flags "$out/lib/huddle/src/bridge/index.ts"
    makeWrapper ${lib.getExe bun} "$out/bin/huddled" \
      --prefix PATH : ${lib.makeBinPath [ bun ]} \
      --add-flags "$out/lib/huddle/src/coordinator/index.ts"

    runHook postInstall
  '';

  meta = {
    description = "Claude Code channel bridge for agent-to-agent messaging";
    homepage = "https://github.com/takeachangs/huddle";
    license = lib.licenses.mit;
    mainProgram = "huddle";
    platforms = lib.platforms.linux;
  };
}
