# Moving the desktop to the iGPU

Status: **staged, not applied.** Andy decides whether and when to do this.

Goal: free the desktop's VRAM reserve on the RX 6900 XT so more is available
to llama-cpp-vulkan.

## The finding that changes the shape of this task

This is primarily a **cable move**, not a config change.

Only one display connector is live on this machine:

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

The monitor is plugged into the 6900 XT. No NixOS configuration can make the
iGPU drive a display that is not physically attached to it. Applying a
"switch the desktop to the iGPU" config without moving the cable produces a
black screen, guaranteed rather than hypothetically.

The good news is the inverse: once the cable is on the motherboard's video
output, the iGPU becomes the only card with a connected display and the
desktop follows on its own. GDM and the compositor pick the card that has
output. No display configuration change is required, which is why none is
staged here.

The iGPU is already enabled and its display pipeline is up (it enumerates four
connectors), so no BIOS change is expected. If the board is set to force the
dGPU as primary, that is the one BIOS setting to revisit.

## What is staged

One change, in `hosts/MS-7E51/default.nix`: llama-cpp is pinned to the dGPU
with `device = "Vulkan0"`.

This is worth applying **regardless** of whether the desktop moves. Current
enumeration:

```
Vulkan0: AMD Radeon RX 6900 XT (RADV NAVI21)              16368 MiB
Vulkan1: AMD Ryzen 9 9950X (RADV RAPHAEL_MENDOCINO)       15986 MiB
```

The iGPU reports ~16 GiB free because it draws on system RAM through GTT, not
the 512 MiB BIOS carve-out. An unpinned llama-cpp that ever picks Vulkan1 does
not fail; it runs the model on the integrated GPU out of system memory and
gets dramatically slower. That is the failure mode worth engineering against,
and it is cheap to prevent.

## The numbers

Measured now, with the desktop on the dGPU:

| | |
|---|---|
| dGPU total VRAM | 16368 MiB |
| dGPU in use by the desktop | 3372 MiB |
| dGPU free | ~11429 MiB (as llama.cpp sees it) |
| iGPU dedicated VRAM | 512 MiB (UMA carve-out) |

After the move, expect roughly **15.5 GiB usable** instead of ~13.0 GiB. The
desktop reserve does not vanish, it relocates to system RAM, which this box
has in quantity (32 GiB + 15 GiB zram + 32 GiB swap).

Treat 15.5 GiB as an estimate. It is not measured, because measuring it
requires performing the move. The 3372 MiB figure it is derived from **is**
measured.

## Rollback, written for a black screen

If the display does not come up after the move, the fix is the cable, not the
config. Nothing in the staged change touches display routing.

1. Power off. Move the DisplayPort cable back to the 6900 XT (the card's
   ports, lower in the case, not the motherboard's I/O panel). Power on.
   This restores the previous state completely.

2. If you moved the cable to the motherboard and get nothing at all, and want
   to check whether the machine actually booted: it should still be reachable
   over Tailscale. SSH in and read the connector state with

   ```
   for s in /sys/class/drm/card*-*/status; do echo "$(dirname $s) $(cat $s)"; done
   ```

   A `connected` line under `card0-` means the iGPU sees the monitor and the
   problem is downstream (compositor, GDM). No `connected` line means the
   cable or the BIOS output setting.

3. If you need a previous generation, pick it at the systemd-boot menu. Hold
   or tap the spacebar during early boot to stop the countdown, then choose an
   older entry. This is only relevant if you applied config changes beyond the
   cable move; the cable move itself is not something a generation rollback
   can undo.

4. Recovering blind, if the boot menu is not visible either: the machine boots
   to a usable state regardless of display. SSH over Tailscale and run
   `sudo nixos-rebuild switch --rollback`.

## Verify after the move

```
# The desktop should now be on card0 and the dGPU reserve should be near zero
cat /sys/class/drm/card1/device/mem_info_vram_used

# Vulkan0 must still be the 6900 XT
llama-server --list-devices
```

If `--list-devices` ever shows the iGPU as Vulkan0, the pinned
`device = "Vulkan0"` becomes actively wrong and must be updated to match.
That is the one way this staged change could bite.

## Costs worth weighing

The desktop moves onto the iGPU, so compositing and video decode come off the
6900 XT. For a 2D desktop this is unremarkable on a 9950X. Two things to
know before deciding:

- Video decode moves to the iGPU's media engine. Raphael's is capable but it
  is not the 6900 XT's. Heavy 4K playback or hardware transcoding is the
  place it would show.
- The iGPU uses system RAM, so desktop traffic now shares memory bandwidth
  with everything else, including CPU-side inference work.

Neither is likely to be noticeable for ordinary desktop use. If Andy runs
anything GPU-accelerated on the desktop itself, rather than as a compute job,
that is the case where trading smooth desktop for 2.5 GiB is a real question.

## Not done

No rebuild, no switch, per the dispatch. The llama-cpp pin is committed but
not activated.
