{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  glibc,
}:

stdenv.mkDerivation rec {
  pname = "agy-cli";
  version = "1.0.2";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.0.2-6109799369277440/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha512-Ex9fODBAgpNvgeyP2pqjkRIxCQ9ao7J+rVfD3l2VwO+VsoGmwC2By4K+uEmEVQBP27YvDwknPVyEu7XnoPMwhg==";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ glibc ];

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity "$out/bin/agy"
    runHook postInstall
  '';

  meta = {
    description = "Google Antigravity terminal CLI";
    homepage = "https://antigravity.google";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "agy";
    platforms = [ "x86_64-linux" ];
  };
}
