# Reasoning effort: why Opus is xhigh and Sol is max

Decided 2026-08-19. Revisit only with new tier-split measurements, not with
a new aggregate index score.

## The settings and where they live

| model | effort | configured in |
|---|---|---|
| Claude Opus 5 | `xhigh` | `modules/nixos/default.nix:105` (`effortLevel`, rendered to `~/.claude/settings.json`) |
| GPT-5.6 Sol | `max` | `modules/home-manager/codex.nix:20`, the `cx` launcher at `modules/home-manager/default.nix:483`, the CLADE connect default at `:374`, and the dispatch rule in `agents/AGENTS.md:363` |

One global setting per model, deliberately, not per-project. Anthropic's docs
give a concrete reason beyond tidiness: changing effort between requests
invalidates cached prefixes, so vary effort *across* workloads, not within a
conversation that relies on cache hits. Cached input is 90% off, so
fragmenting a long session across effort levels is a real cost.

## Two things that are easy to get wrong

**Effort is not verbosity.** From Anthropic's effort docs: "Effort controls
thinking volume, not visible response length: on Claude Opus 5, changing
effort does not reliably shorten responses, so prompt for length instead."
Stepping effort down to get shorter answers does not work. Prompt for length.

**A flat aggregate index hides the decision.** AA scores Opus max 63.05 and
xhigh 62.52, which both display as 63. The useful signal is per-benchmark,
and it points different directions for the two models.

## The evidence

Per-benchmark tier splits, measured by Artificial Analysis, extracted by
main-pc: `~/main/docs/research/tier-deltas-opus5-sol-2026-08-19.md`
(commit cda9127). Composites cross-checked against an independent fetch.

**Opus: max buys nothing measurable.** Every max→xhigh delta is ≤1.4 points
in either direction and sits inside single-run noise. GPQA moves the *wrong*
way for max (93.2 vs 93.7). xhigh costs 24% fewer output tokens and drops
TTFT from 59.97s to 40.50s.

**Sol: max earns its cost on science.** max→xhigh loses CritPt 32.3 → 28.6
(−3.7) and HLE 49.5 → 47.3 (−2.2). Sol's CritPt 32.3 at max is the highest
score in the whole table, beating Opus at every tier (29.1 / 27.7 / 28.3), so
for physics-style research reasoning Sol-at-max is the best instrument on
this host. The price is a 208.7s TTFT.

Opus dominates HLE at every tier (54.9 / 54.4 / 52.8 vs Sol 49.5 / 47.3 /
46.0). The split uses each model where it is strongest.

## Why not step Opus down to high

Tempting, and cheap on paper: high costs ~1 point of composite, almost all of
it HLE (54.4 → 52.8). CritPt and τ³-Banking actually *improve* at high, and it
saves a further 32% of output tokens with TTFT halved again to 20.6s.

The reason not to is that the loss is in behavior the benchmarks do not
measure. Anthropic's docs say lower effort makes Claude "make fewer tool
calls" and scope work to what was asked. AA's tier-split set is single-shot
Q&A; the only long-horizon coding proxy in it, Terminal-Bench v2.1, is also
one of only two benchmarks that move down. Anthropic describes xhigh as for
"long-running agentic and coding tasks (over 30 minutes) with token budgets
in the millions," which is the session shape this host runs.

`high` remains a legitimate quota lever if it gets tight. The tell that it has
gone too far is an agent accepting a premise instead of checking it.

## Known gaps

AA publishes **no tier splits** for SWE-Bench Verified, LiveCodeBench, Aider,
APEX-Agents, or ITBench on either model, and neither vendor card carries them.
Three agentic benchmarks are Sol-max-only (AA-AnalystAgent 47.5,
AutomationBench 51.2, EnterpriseOps-Gym 42.9), so no xhigh comparison exists
there. Every AA cell is a single run with no confidence intervals.

## Do not trust this file

`~/main/docs/research/reasoning-effort-tradeoffs-opus5-sol-2026-08-19.md`
(main-ag, commit 0fa9855) has zero citations across 120 lines, heads a section
"Vendor Published Guidance (Primary Sources)" while citing nothing, and
asserts two figures that could not be traced to any source: "+3% to +7% max
over xhigh on ARC-AGI/Codeforces" (ARC Prize published Opus 5 at max only and
ran ARC-AGI-3 at high, so no such split exists) and "3x-5x more tokens
globally" from turn expansion. Its recommendation contradicts the vendor
guidance it claims to cite. The turn-expansion *mechanism* is real and
Anthropic corroborates it, but it argues against `low`/`medium`, not against
`xhigh`. Correction requested from main-ag 2026-08-19; unresolved as of
writing.
