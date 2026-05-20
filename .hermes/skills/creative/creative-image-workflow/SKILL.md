---
name: creative-image-workflow
description: Use when generating, editing, or delivering user-facing creative images, including brand-grounded visuals, Stable Diffusion/Diffusers workflows, avatars, posters, marketing shots, and delivery-ready media.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [image-generation, creative, branded-images, stable-diffusion, delivery]
    related_skills: [creative-image-generation-delivery]
---

# Creative Image Workflow

## Required model disclosure

When delivering generated media or creative artifacts to Kenneth, always state which model was used in the response. Include the provider/tool and exact model or workflow when known (for example: `OpenAI gpt-image-2-high`, `Sogni flux2_dev_fp8`, `ComfyUI workflow + checkpoint`, `Claude Sonnet 4`, `Manim rendered locally`). If the output was rendered locally without a generative model, say that explicitly.

## Overview

This umbrella covers user-facing creative image generation and delivery. It consolidates general delivery rules, branded/reference-image generation, and Stable Diffusion/Diffusers model workflows into one discoverable class-level skill.

## When to Use

- Kenneth asks for profile pictures, avatars, posters, mock tickets, social images, or marketing visuals.
- A brand/reference image must ground style, product, logo, or persona depiction.
- Stable Diffusion/Diffusers model selection, img2img/inpainting, or local generation is relevant.
- A generated image must be delivered as a platform media attachment or local file.

## Operation Index

- General delivery and platform-ready creative-image rules: `references/creative-image-generation-delivery.md`.
- Brand-grounded/reference-image generation: `references/branded-image-generation.md`.
- Stable Diffusion/Diffusers workflow: `references/stable-diffusion-image-generation.md`.
- Identity-preserving outfit/fashion variation batches: `references/identity-preserving-outfit-variation-batches.md`.
- Identity-preserving batch headshot generation: `references/identity-preserving-batch-headshots.md`.
- Character-consistent storyboard stills for vertical/video keyframes: `references/character-storyboard-stills.md`.
- Seedance storyboard + clip replacement workflow: `references/seedance-storyboard-replacement-workflow.md`.
- Seedance real-person transition fallback: `references/seedance-real-person-transition-fallback.md`.
- Seedance storyboard videos from real-person-derived stills: `references/seedance-storyboard-video-from-real-person-stills.md`.
- Grok/xAI Imagine image and video generation smoke-test workflow: `references/grok-imagine-generation.md`.
- Grok Imagine storyboard/keyframe video replacement workflow: `references/grok-storyboard-video-workflow.md`.
- xAI/Grok image + video generation smoke tests: `references/grok-media-generation-smoke-tests.md`.
- Grok/xAI Imagine image and video generation smoke-test workflow: `references/grok-imagine-generation.md`.
- Grok Imagine per-shot remake workflow for longer storyboard/final-video remakes: `references/grok-imagine-per-shot-remake.md`.
- xAI/Grok image + video generation smoke tests: `references/grok-media-generation-smoke-tests.md`.
- Grok Imagine outfit/fashion transition videos from prior stills/contact sheets: `references/grok-imagine-outfit-transition-video.md`.
- Grok image-to-video from local generated stills, including data-URL handler invocation and QA: `references/grok-image-to-video-from-local-stills.md`.
- Grok Imagine remake fallback when the original uploaded source image is missing but a prior generated video exists: `references/grok-missing-source-reference-fallback.md`.

## Class Workflow

1. Clarify the deliverable format, aspect ratio, style constraints, brand/reference materials, and destination platform.
2. Select the generation path: native `image_generate`, provider-specific CLI/API, brand/reference workflow, or Stable Diffusion/Diffusers.
3. Preserve reference assets and generated outputs in clear cache/tmp paths. For repo/project work, put assets under that project's gitignored `tmp/<mini-project>/` folder rather than a loose global temp path.
4. For large identity/style batches, generate a small representative test set first (usually 3 images), deliver those, then run the full batch only after Kenneth approves or asks for all.
5. Iterate prompts with visible quality criteria, not vague “make it better” loops.
6. Verify the output file/URL exists and is deliverable before responding.
7. Deliver with `MEDIA:<path>` or markdown image as appropriate for the platform.

## Pitfalls

- Do not silently switch providers when the user asked for a specific model/provider; report the actual provider used.
- For provider smoke tests (especially newly enabled Grok/xAI), re-read current config/tool behavior and verify the generated URL/file loads before reporting success; see `references/grok-media-generation-smoke-tests.md`.
- For Grok storyboard/keyframe videos, prefer per-frame image-to-video clips using data-URL keyframes, then stitch and QA with a contact sheet; do not promise native dialogue/audio from Grok unless a separate audio workflow is planned. See `references/grok-storyboard-video-workflow.md`.
- For Grok remakes of earlier image-to-video work, if the original Slack-uploaded image cache path is gone, do not stop: locate the prior generated MP4, extract its first frame, QA that frame, and use it as the Grok reference. See `references/grok-missing-source-reference-fallback.md`.
- Brand/reference tasks need explicit reference handling, not just brand names in text prompts.
- For identity-preserving edits, include the person's source image as a reference image in addition to the style/environment reference; prompt explicitly to preserve face/body/age/ethnicity/distinctive features.
- For storyboard still sequences, reuse the approved/generated character images as canonical references on every frame, use timing-coded filenames, make generation resumable, and deliver a contact sheet plus full-resolution files; see `references/character-storyboard-stills.md`.
- Generated files should not be committed unless the task is explicitly to add assets to a repo.
- When editing a reference image for downstream video generation, verify the edited image's actual dimensions/aspect ratio before passing it to the video model; provider labels like `portrait` may not mean true 9:16.
- For real-person outfit transition videos, Seedance may reject `i2v` or real-person references; use `references/seedance-real-person-transition-fallback.md` and get/confirm fallback to non-Seedance Sogni video rather than declaring video generation impossible.
- When animating an already generated image with Grok/xAI, use the latest edited still as the image-to-video source, not the original photo. For local files, a data URL passed as `image_url` works, but do not send huge data URLs through `python -c` or subprocess argv; call `_handle_video_generate` in-process from a script and then download/probe/QA the MP4. See `references/grok-image-to-video-from-local-stills.md`.
- For Grok remakes of an existing multi-shot final video, do not default to a single condensed text-to-video prompt when prior storyboard/keyframes exist. Use the original intended frame set (photoreal vs stylized matters), generate per-shot Grok image-to-video clips with references, then stitch and QA; see `references/grok-imagine-per-shot-remake.md`.
- Large generated batches need resumable manifests, per-item errors/skips, and output verification; do not report completion from provider calls alone.
- Platform delivery can fail if the path is remote/private or local file missing; verify first.

## Verification Checklist

- [ ] Provider/path and aspect ratio were chosen intentionally.
- [ ] Reference assets were used or the absence was explicit.
- [ ] Output exists and is viewable/deliverable.
- [ ] Delivery format matches the user’s platform/request.
