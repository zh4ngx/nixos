# Open items

Live as of 2026-08-19. Delete entries as they close.

## Reboot pending

Generation 740 is active with **Linux 7.2 configured**, but `/run/booted-system`
is still the previous build and `uname -r` reports 7.1.8. Kernel changes do not
take effect on `switch`. **Reboot to actually run 7.2.** Until then, avoid
hotplugging hardware that needs a module not already loaded; the running
kernel's module tree and `/run/current-system` no longer agree.

## Trap: the next flake update breaks eval

`nix flake update` past nixos-unstable `ec2d622` breaks evaluation with
`error: attribute extraArgs missing`.

Upstream typo in `nixos/modules/services/home-automation/wyoming/faster-whisper.nix`:
`extraArgs` is declared on the server submodule at line 293 and read correctly
as `options.extraArgs` at line 391, but line 332 reads `cfg.extraArgs`, where
`cfg` is `config.services.wyoming.faster-whisper` and has no such attribute.
Eval crashes whenever **any** server is declared.

We declare one: `services.wyoming.faster-whisper.servers.stt` in
`modules/nixos/default.nix:413`.

Our current pin `0ae2bc1` predates the breakage and evaluates clean, which is
why the audit passes today. Found by nixos-ag.

When it bites, the options are: stay on the current pin, comment out
`servers.stt` (nixos-ag confirmed a dry-run builds clean that way, kernel
included), or carry a local overlay fixing line 332 until upstream lands a fix.
Worth checking whether upstream has fixed it before doing either.

## OpenCode: harness retired, module deliberately kept

Retired as a harness on 2026-08-19, commit `ed7604e`. Gone: the `oc` fish
launcher, `opencode-attach-current`, the `opencode-serve` unit on :4096, the
magic-context plugin (historian/dreamer/sidekick), the `.config/opencode`
AGENTS.md and skills symlinks, and the `zai-coding` / `ollama-cloud` provider
blocks that only magic-context consumed. Nothing outside opencode's own module
referenced :4096, so no dispatch path lost a target.

`modules/home-manager/opencode.nix` **still exists on purpose.** Two call sites
in `~/clade/prototypes/clade-wasm-kernel` spawn the binary directly:

- `crates/clade-keepomit/src/lib.rs:344` — `ProcessCommand::new("opencode")`
  with `run -m opencode-go/deepseek-v4-flash --pure --format json`
- `crates/clade-bridge-policy/src/lib.rs:187` — same pattern, `bridge:opencode`

So the module ships exactly three things and nothing else: the wrapped package
on lensd's PATH, an `opencode.json` carrying the `opencode-go` provider so the
model id resolves, and the sops-rendered `auth.json`. There is a comment at the
lensd PATH entry saying so. **Do not delete this module without repointing
those two call sites first.**

The deletion is gated on a question that is Andy's, not ours: whether clade-lens
stays at all, or whether its traces get mined into a corpus and the live path
retired. Sent to `clade-co` 2026-08-19 (redirected from `clade-cx`, which is
offline); queued, no live connector. If the answer is "Lens stays", the repoint
is a POST to `https://opencode.ai/zen/go/v1/chat/completions` with a bearer
token and model `deepseek-v4-flash`, after which this module can go and the
secret can render as a plain key file.

Pi consumes the OpenCode Go subscription independently and is unaffected.

## Muse Spark / RL env library — handed to main-co

Handed off 2026-08-19, no `~/nixos` work pending. Recorded here only so the
findings are not re-derived.

Meta's Muse Spark 1.2 is on the Go plan as `muse-spark-1.2-contributor` at
$0.10/M in, $0.20/M out, $0.002/M cache read — 12x/21x under Meta's standard
tier, 30x/75x under kimi-k3 on the same plan, roughly 300M output tokens against
the $60/mo cap. The near-free cache read is the important number: agent rollouts
re-send the same prefix every turn. Inputs are text, image, video, pdf, audio;
1M context. Contributor tier means Meta trains on prompts and completions.
**Andy has read the logged-in contract and cleared the terms.** If Meta's
Community License §1.b ("not use... any output... to improve any other large
language model") resurfaces, note that it governs open-weight Llama releases,
not this hosted API, and Andy's direct read supersedes it.

Two findings worth keeping: Pi session files are already trajectories (JSONL
with full turn structure, tool calls and results included, no instrumentation
needed), and Pi already has an `opencode-go` provider wired, so adding Muse
Spark is one `models.json` entry — though the provider sets
`supportsReasoningEffort = false` and Muse Spark is a reasoning model, so it
likely needs a `modelOverrides` entry the way `zai/glm-5.3` got one.

Decision reached: environment definitions beat trajectories. An env contains no
model output, so no vendor terms touch it; envs compose into curricula while
trajectories only stack into datasets; and the env library needs neither Spark
nor the Go subscription to start. Curriculum design is main-co's and Andy's.

## HDMI 2.1: waiting on VRR, deliberately

See `igpu-desktop-migration.md`. Nothing to do now. The trigger is HDMI VRR
merging into amdgpu, at which point FRL becomes default-on, the
`amdgpu.dc_feature_mask=0x400` parameter becomes unnecessary, and moving the
cable from the DP-to-HDMI adapter to the 6900 XT's HDMI port becomes clearly
better rather than a lateral trade.

## Fleet

- **clade-lens digest inaccuracy.** A `nixos-rebuild build` run was summarized
  as `nixos-rebuild switch` succeeding. The raw handle was accurate; the
  distiller inflated the command into a more consequential one. Do not trust a
  digest alone for anything destructive-sounding. Reported to `clade-co`
  2026-08-19 (clade-cx offline); queued, no live connector.
- **clade-inbox `read` is destructive with no history subcommand.** Reported to
  clade-cx 2026-08-18; unresolved. A read whose output is lost takes the batch
  with it.
- **Closed 2026-08-19:** main-ag revised its reasoning-effort research doc
  (commit a87aaa8) with primary citations, retracted the unsourced ARC
  max-vs-xhigh split, relabelled the turn-expansion figures as an analytical
  model rather than data, and reversed its recommendation to xhigh for Opus 5.
