{
  config,
  pkgs,
  lib,
  ...
}:
{
  # OpenCode is no longer an agent harness here. The `oc` seat, the attach
  # wrapper, the opencode-serve injection substrate, and the magic-context
  # plugin were all removed on 2026-08-19; Pi consumes the OpenCode Go
  # subscription directly through its own openai-completions provider.
  #
  # What survives is opencode-as-a-backend for one consumer: clade-lens's
  # `teacher` distiller is an OpencodeDistiller that shells out to this binary
  # for `opencode-go/deepseek-v4-flash`. That is why the package, the
  # opencode-go provider block, and the auth file all stay. Do not delete this
  # module without first repointing that distiller.
  programs.opencode = {
    enable = true;

    # opencode ships as a Bun standalone (statically-linked, no ELF interp)
    # that dlopen()s libstdc++.so.6 at runtime for its file-watcher native
    # binding. nix-ld can't help (no dynamic linker to intercept), so we
    # inject LD_LIBRARY_PATH via a wrapper. Narrow scope: only opencode's
    # own process tree sees the prefix.
    package = pkgs.symlinkJoin {
      name = "opencode-with-libstdcxx";
      paths = [ pkgs.opencode ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      meta = (pkgs.opencode.meta or { }) // {
        mainProgram = "opencode";
      };
      postBuild = ''
        wrapProgram $out/bin/opencode \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}
      '';
    };

    # Retained because opencode's own runtime still loads plugins through bun
    # even with none declared. Cheap insurance for the distiller path.
    extraPackages = [ pkgs.bun ];

    settings = {
      permission = "allow";
      autoupdate = false;

      # Only the model clade-lens's teacher distiller asks for. No default
      # `model` is set: nothing drives an interactive session anymore, so a
      # default would only be a footgun if someone ran the binary by hand.
      small_model = "opencode-go/deepseek-v4-flash";

      provider.opencode-go = {
        npm = "@ai-sdk/openai-compatible";
        name = "OpenCode Go";
        options.baseURL = "https://opencode.ai/zen/go/v1";
      };
    };
  };

  # Auth credentials from sops template. Pi reads this same path for its own
  # opencode-go provider (modules/home-manager/default.nix), so it outlives the
  # harness.
  xdg.dataFile."opencode/auth.json".source =
    config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/opencode-auth.json";
}
