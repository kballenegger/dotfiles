---
name: audio-voice-workflow
description: Use when generating, transcribing, segmenting, or cleaning speech/audio datasets for Kenneth, including TTS delivery, Whisper transcription, speaker extraction, and voice-cloning dataset preparation.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [audio, tts, stt, whisper, voice-datasets, diarization]
    related_skills: [audio]
---

# Audio & Voice Workflow

## Required model disclosure

When delivering generated media or creative artifacts to Kenneth, always state which model was used in the response. Include the provider/tool and exact model or workflow when known (for example: `OpenAI gpt-image-2-high`, `Sogni flux2_dev_fp8`, `ComfyUI workflow + checkpoint`, `Claude Sonnet 4`, `Manim rendered locally`). If the output was rendered locally without a generative model, say that explicitly.

## Overview

This umbrella covers the class of audio and voice tasks: generating speech/voice notes, transcribing audio, extracting clean per-speaker clips, and building high-purity voice-cloning datasets. Narrow model/tool runbooks are preserved as references.

## When to Use

- Kenneth asks for generated speech/audio/voice notes.
- Audio or video must be transcribed or translated.
- A podcast/interview needs per-speaker clip extraction.
- A voice-cloning dataset needs quality filtering, diarization, overlap rejection, normalization, or clip export.

## Operation Index

- Kenneth-specific canonical TTS/audio generation: `references/canonical-audio-tts.md`.
- Voicebox on lijiang for local cloned/multilingual TTS and benchmarks: `references/voicebox-lijiang.md`.
- Whisper transcription/model notes: `references/whisper.md`.
- Speaker dataset extraction: `references/speaker-dataset-extraction.md`.
- Female-only voice dataset cleaning: `references/female-voice-dataset-cleaning.md`.

## Class Workflow

1. Identify output type: user-facing audio, transcript, speaker clips, or training dataset.
2. Preserve original media and work in a temp/output directory with manifest metadata.
3. For transcription, choose the available engine/model and verify language/output format.
4. For datasets, apply diarization, overlap/noise rejection, duration bounds, loudness normalization, and spot-checks.
5. For user-facing delivery, generate the final media path and verify it is playable before sending.
6. Report artifact paths, duration/counts, quality gates, and known limitations.

## Safety / Quality Rules

- Do not overwrite source media.
- Do not mix speakers in a cloning dataset unless the task explicitly wants multi-speaker data.
- Reject overlapped/noisy/low-confidence segments rather than padding counts with low-quality clips.
- For generated voice/audio, confirm whether the request is a native voice bubble, file attachment, or local artifact.

## Verification Checklist

- [ ] Source media was preserved.
- [ ] Output files exist and are non-empty/playable.
- [ ] Transcripts/datasets include enough metadata to audit segments.
- [ ] Dataset quality gates and exclusions were reported.
