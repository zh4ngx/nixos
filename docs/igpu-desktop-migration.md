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

The following is as reported by main-co's research, not independently verified
here. The HDMI Forum prohibited open-source HDMI 2.1 in February 2024. AMD
submitted FRL patches upstream in May 2026, reportedly on Valve's push, with a
target merge in **Linux 7.2**.

### Watch item: Linux 7.2

**Trigger:** nixpkgs ships Linux 7.2. This host is on
`pkgs.linuxPackages_latest` (`modules/nixos/default.nix:270`) and is running
7.1.8, so 7.2 arrives on its own without a config change.

**When it lands, flag it to Andy along with these caveats:**

- FRL is **disabled by default**. It needs `amdgpu.dc_feature_mask=0x400` in
  `boot.kernelParams`.
- Only FRL was submitted. **VRR and DSC were not.** VRR matters on an OLED if
  he games, so 7.2 may not be the full win.
- Full compliance testing was still in progress as of the reporting.

**The clean path, once 7.2 is in:** add the kernel parameter, plug HDMI
directly into the 6900 XT, drop the adapter. No iGPU move at any point.

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
