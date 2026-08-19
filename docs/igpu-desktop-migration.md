# Desktop GPU routing, HDMI 2.1, and the shelved iGPU migration

Status: **the iGPU desktop migration is shelved.** Do not re-propose it. The
one piece worth keeping is the llama-cpp `Vulkan0` pin, which is committed and
awaiting a rebuild.

## Why it is shelved

The migration was proposed to free the desktop's ~3 GiB VRAM reserve on the
RX 6900 XT. Two things killed that rationale:

- The real goal was never VRAM. It was HDMI 2.1 to the LG CX, and the iGPU
  does not help with that (see below).
- The VRAM itself does not matter for the work it was meant to serve. The
  System-1 research models are 10M-100M parameters, roughly 200 MB at fp16.
  The 2.5 GiB only ever mattered for a general local assistant, which loses to
  the GLM-5.3 subscription anyway.

Also worth recording so it is not rediscovered: the Granite Ridge iGPU is
2 CUs of RDNA2. It is not a compute tier. STT belongs on the 16 Zen 5 cores.

## HDMI 2.1: the actual problem, and what unblocks it

The LG CX has HDMI 2.1 inputs and no DisplayPort, which is why Andy runs a
DP-to-HDMI adapter today. The hope was that the motherboard's HDMI port might
deliver HDMI 2.1 where the card's did not.

It does not, and moving the cable to the board buys nothing here. The blocker
is `amdgpu`, which drives **both** the 6900 XT and the iGPU. Every other link
in the chain is already fine:

| Link | Status |
|---|---|
| LG CX panel | HDMI 2.1, 4K120. Fine. |
| MAG X870 TOMAHAWK WIFI rear HDMI | HDMI 2.1 with FRL, rated 8K60 / 4K120. Fine. |
| RX 6900 XT | RDNA2, HDMI 2.1 hardware. Fine. |
| `amdgpu` driver | **The blocker.** |

The status below is from main-co's web research, not verifiable from this
host. The HDMI Forum prohibited open-source HDMI 2.1 in February 2024. AMD
submitted FRL patches upstream in May 2026, reportedly on Valve's push, and
**Linux 7.2 has been released with FRL merged**; the 7.3 merge window opened
2026-08-17. Everything in the next section, by contrast, is measured here.

### RESOLVED 2026-08-19: Linux 7.2 landed

Kernel 7.2 reached `nixos-unstable` and Andy pulled it with `nix flake update`
on 2026-08-19 (pin moved to `0ae2bc1`, 2026-08-18). The configured kernel is
now 7.2. **The remaining work is the kernel parameter and the cable, below.**

The watch is closed, but the lesson in how it was misread is worth keeping.
Earlier the same day this file asserted that `linuxPackages_7_2` "does not
exist" on nixos-unstable. That was measured correctly and was still wrong in
substance, for two reasons:

- **`master` had 7.2 before `nixos-unstable` did.** `nixos-unstable` is master
  held back until Hydra builds it and the NixOS tests pass, which is also what
  populates the binary cache. Checking only `nixos-unstable` answers "can I
  get this now without compiling," not "does nixpkgs have it."
- **The branch moved within hours.** A measurement against a fast-moving
  branch is a timestamp, not a fact. Re-run before relying on it.

So: check both refs, and record which one you checked.

```
nix eval --refresh --raw github:NixOS/nixpkgs/nixos-unstable#linuxPackages_latest.kernel.version
nix eval --refresh --raw github:NixOS/nixpkgs/master#linuxPackages_7_2.kernel.version
```

We stay on `nixos-unstable`. `master` is ungated: a bad merge reaches the
machine directly, cache coverage is spottier so you compile more, and
staging-next merges land mass rebuilds unabsorbed. If a single package is ever
needed ahead of the channel again, add a second nixpkgs input pinned to master
and take only that attribute from it, rather than moving the whole system.

### Why FRL is off by default, and why that matters

AMD disabled FRL by default **specifically because HDMI VRR is not finished**.
Their stated position is that FRL without VRR is a *regression* for people
with FRL-capable displays, so they will not ship it on by default until VRR
lands. Once VRR is complete AMD intends to flip FRL on by default and the
kernel parameter becomes unnecessary.

Read that as guidance, not trivia: AMD is saying that turning FRL on today is
a downgrade in one respect for exactly this setup (an FRL-capable OLED used
for gaming). DSC *is* functional in 7.2; VRR is the missing piece.

Reported via Phoronix/wccftech coverage of the patch submission, 2026-08-19.

### To enable it anyway

Add to `boot.kernelParams` in `hosts/MS-7E51/default.nix` (block at line 714):

```nix
# HDMI 2.1 FRL is off by default in amdgpu until HDMI VRR is complete.
# Remove this once AMD enables FRL by default; it is a temporary workaround.
"amdgpu.dc_feature_mask=0x400"
```

Then plug HDMI **directly into the RX 6900 XT**, not the motherboard. The dGPU
is RDNA2 with HDMI 2.1 hardware; the iGPU is irrelevant to this and always was.

### Native HDMI 2.1 vs the DP-to-HDMI adapter

Not strictly better today, and that is the actionable conclusion.

- **FRL is required** for the high-bandwidth modes. HDMI 2.0's TMDS signalling
  tops out near 18 Gbps (4K60 8-bit); FRL is what unlocks up to 48 Gbps and
  therefore 4K120.
- **Native advantages:** no conversion layer, CEC, cleaner HDR and mode-change
  handshakes, and VRR once it exists. Active DP-to-HDMI adapters are a known
  source of black screens on mode change and HDR handshake quirks.
- **But neither path gives VRR right now**, and AMD itself calls FRL-without-
  VRR a regression. Switching to native today trades adapter quirks for driver
  immaturity.

**So there is no urgency.** Wait for VRR. When it lands, the kernel parameter
disappears on its own *and* native becomes clearly better than the adapter, in
one step, instead of two disruptive changes for a partial win.

### Does the kernel parameter hurt while still on the adapter?

It should be inert. `dc_feature_mask` bit 0x400 enables FRL on the GPU's native
HDMI encoder. On a DP-to-HDMI adapter the GPU drives a DisplayPort output and
the adapter does the conversion, so the HDMI encoder path is not in use. Low
risk rather than guaranteed no-op: not verified on this hardware, and there is
no reason to set it before moving the cable anyway.

## Open items

- [ ] `amdgpu.dc_feature_mask=0x400` not added. Deliberate: wait for VRR.
- [ ] Cable still on DP-to-HDMI adapter. Move to the 6900 XT's HDMI when VRR
      lands, not before.
- [ ] **Watch: HDMI VRR in amdgpu.** When it merges, FRL should become
      default-on, this parameter becomes removable, and the adapter can go.
      That is the single trigger for finishing this whole thread.

## The one change that was kept

`hosts/MS-7E51/default.nix` pins llama-cpp to the dGPU with
`device = "Vulkan0"`. Committed, not switched.

This is worth applying on its own merits. Enumeration is:

```
Vulkan0: AMD Radeon RX 6900 XT (RADV NAVI21)              16368 MiB
Vulkan1: AMD Ryzen 9 9950X (RADV RAPHAEL_MENDOCINO)       15986 MiB
```

The iGPU reports ~16 GiB free because it draws on system RAM through GTT, not
its 512 MiB BIOS carve-out. An unpinned llama-cpp that ever selects Vulkan1
does not fail. It runs the model on 2 CUs of integrated graphics out of system
memory and gets dramatically slower, which is the hard failure to notice.

The one way the pin bites: if enumeration order ever flips, `Vulkan0` becomes
actively wrong. Check `llama-server --list-devices` after any GPU or display
change and confirm Vulkan0 is still the 6900 XT.

## The connector finding

Kept because it is what made the migration cheap to abandon, and because it
stays true for any future display work.

Only one connector is live:

```
card0-DP-4      disconnected     <- iGPU
card0-DP-5      disconnected     <- iGPU
card0-DP-6      disconnected     <- iGPU
card0-HDMI-A-2  disconnected     <- iGPU
card1-DP-1      disconnected     <- RX 6900 XT
card1-DP-2      connected        <- RX 6900 XT, this is the monitor
card1-DP-3      disconnected     <- RX 6900 XT
card1-HDMI-A-1  disconnected     <- RX 6900 XT
```

The monitor is on the 6900 XT. Moving the desktop to the iGPU was never a
config change; it was a cable move, and applying a config that assumed
otherwise would have produced a black screen with certainty. Establishing this
before anyone tried it is why abandoning the plan cost nothing.

Measured at the time: dGPU total 16368 MiB, 3372 MiB held by the desktop.

## Rollback, written for a black screen

Retained because it costs nothing and applies to any future display change.

1. Power off. Move the DisplayPort cable back to the 6900 XT (the card's
   ports, lower in the case, not the motherboard I/O panel). Power on. This
   restores the previous state completely. The fix is the cable, not the
   config; nothing in this repo routes the display.

2. To check whether the machine booted at all, it is reachable over Tailscale.
   SSH in and read connector state:

   ```
   for s in /sys/class/drm/card*-*/status; do echo "$(dirname $s) $(cat $s)"; done
   ```

   A `connected` line under `card0-` means the iGPU sees the monitor and the
   problem is downstream (compositor, GDM). No `connected` line anywhere means
   the cable or the BIOS output setting.

3. For a previous generation, stop the systemd-boot countdown with the
   spacebar during early boot and pick an older entry.

4. Blind, if the boot menu is not visible either: SSH over Tailscale and run
   `sudo nixos-rebuild switch --rollback`.
