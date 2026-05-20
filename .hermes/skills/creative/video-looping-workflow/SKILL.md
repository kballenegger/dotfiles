---
name: video-looping-workflow
description: Use when generating, editing, or post-processing subtle looping videos for website backgrounds, hero sections, ambient motion graphics, or seamless clips from still images.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [video, looping, website-backgrounds, sogni, seedance]
    related_skills: [sogni-creative-agent-skill, slack-workflow]
---

# Video Looping Workflow

## Required model disclosure

When delivering generated media or creative artifacts to Kenneth, always state which model was used in the response. Include the provider/tool and exact model or workflow when known (for example: `OpenAI gpt-image-2-high`, `Sogni flux2_dev_fp8`, `ComfyUI workflow + checkpoint`, `Claude Sonnet 4`, `Manim rendered locally`). If the output was rendered locally without a generative model, say that explicitly.

## Overview

Create seamless or near-seamless looping video assets, especially website hero/background videos generated from still images. This skill complements `sogni-creative-agent-skill` rather than replacing it: use Sogni/Seedance for generation, then deterministic post-processing when the model output does not actually loop.

## Still Image → Website Background Loop

1. Fetch the source image from the actual message attachment. For Slack threads, if local inbound media is empty, use `slack-workflow` and download `messages[].files[].url_private_download` with Bearer auth.
2. Use Sogni/Seedance with the still as a reference. If Seedance rejects direct image-to-video, use `--workflow t2v --ref <image>` and mention `@Image1` in the prompt.
3. Protect layout-critical areas explicitly:
   - fixed camera and locked composition,
   - logo unchanged and motionless,
   - text-overlay side still,
   - decorative side only has subtle ambient motion.
4. If a direct longer loop fails or does not return to the start frame, generate a shorter good pass and make a forward+reverse boomerang loop.
5. Remove audio unless requested; website background videos should usually be silent.
6. Verify duration, dimensions, FPS, and playback loop smoothness before delivering.

## Seedance prompt pattern

```text
Use @Image1 as the exact still frame. Fixed camera, no zoom, no pan. Keep the logo completely unchanged and motionless. Keep the left side almost perfectly still for text overlay. Only the right side has very subtle atmospheric ambient light: soft glow breathing, faint haze drift, tiny low-intensity flicker. No object motion, no flashes, no morphing. Calm website background motion.
```

## Grok / xAI Imagine alternative

When Kenneth asks for the same still-image background loop “with Grok”, use Grok Imagine Video through the Hermes `video_generate` surface (or `_handle_video_generate` fallback). Grok image-to-video needs a reachable public `image_url`, so upload the source still to a temporary public host, verify it loads, call xAI with `image_url`, then download the returned MP4 and strip audio for website use. See `references/grok-still-background-loop.md`.

## Command patterns

```bash
sogni-agent -q --json --video -m seedance2-fast --workflow t2v \
  --ref /path/to/source.png --duration 5 --target-resolution 720 \
  --seed-strategy random --token-type auto -o /tmp/base5s.mp4 \
  '<prompt mentioning @Image1>'
```

Forward+reverse loop, 5s base → 10s loop:

```bash
bash /path/to/video-looping-workflow/scripts/make_boomerang_loop.sh /tmp/base5s.mp4 /tmp/true_10s_loop.mp4 120
```

See `references/seedance-still-background-loop.md` for session-derived Seedance quirks and prompt wording.

## Pitfalls

- “Looping” in a generation prompt does not guarantee the output actually loops.
- Seedance may reject `--workflow i2v`; use `t2v` + `--ref` + `@Image1` for still references.
- Vendor-side failures on longer durations can often be worked around by generating a shorter pass and looping deterministically.
- Forward+reverse is reliable but creates a boomerang cadence; use it when seamlessness matters more than one-way natural motion.
