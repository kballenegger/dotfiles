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
- Photoreal podcast likeness videos: use `creative-image-workflow`’s `references/photoreal-podcast-likeness-grok-speech.md` for the cloned-Kenneth-voice vs Grok-native-speech comparison workflow.
- Voicebox on lijiang for local cloned/multilingual TTS and benchmarks: `references/voicebox-lijiang.md`.
- Voicebox cloned-TTS comparisons from cleaned reference samples, including service-slot switching from Miso and profile/sample upload: `references/voicebox-public-figure-sample-clone-workflow.md`.
- Section-by-section cloned dialogue regeneration with transcript/duration QA, voice-clone retry handling, and incremental delivery: `references/section-by-section-cloned-dialogue-qa.md`.
- Cloned dialogue replacement QA: for regenerating scene dialogue with character voice clones, generate dialogue-only sections, transcript-QA each section, try alternate clone ids on short-line failures, and deliver each passed section immediately; see `references/cloned-dialogue-replacement-qa.md`.
- MisoTTS on lijiang for exploratory local voice cloning/TTS, long-text chunking, and benchmark caveats: `references/miso-tts-lijiang.md`.
- KugelAudio local/lijiang benchmarking against Miso/Qwen, including hosted/HF/local routes, ROCm dependency pins, model-load memory pitfalls, and harness cautions: `references/kugelaudio-lijiang-local-benchmark.md`.
- KugelAudio vs lijiang TTS benchmark workflow, including HF Space quota caveats, Qwen/Rosie baseline routing, and local lijiang install-smoke pitfalls: `references/kugel-audio-lijiang-benchmark.md`.
- Qwen + Miso cloned-voice WhatsApp sample batches, including Sir David voice ids, long Miso wait behavior, and WA voice-note delivery: `references/qwen-miso-cloned-voice-wa-batches.md`.
- Selecting and evaluating English–Chinese TTS providers for quality, cloning, expressiveness, real-time use, and normalized cost: `references/bilingual-tts-provider-evaluation.md`.
- Registering new lijiang TTS voices across Qwen Base, Miso, and the Dashboard Audio Models card: `references/lijiang-tts-voice-registration.md`.
- Whisper transcription/model notes: `references/whisper.md`.
- Klaw Keyboard STT backend selection and long-form pitfalls: `references/klaw-keyboard-stt-backend-selection.md`.
- Klaw Keyboard STT glossary/cleanup glossary and Whisper prompt-seeding pattern: `references/klaw-keyboard-stt-glossary-and-prompt-seeding.md`.
- Speaker dataset extraction: `references/speaker-dataset-extraction.md`.
- Female-only voice dataset cleaning: `references/female-voice-dataset-cleaning.md`.

## Class Workflow

1. Identify output type: user-facing audio, transcript, speaker clips, or training dataset.
2. Preserve original media and work in a temp/output directory with manifest metadata.
3. For transcription, choose the available engine/model and verify language/output format.
4. For datasets, apply diarization, overlap/noise rejection, duration bounds, loudness normalization, and spot-checks.
5. For user-facing delivery, generate the final media path and verify it is playable before sending.
6. For TTS, do not treat valid PCM, a nonzero waveform, or a generic "voiced fraction" as proof that a listener will hear usable speech. Apply the audibility acceptance test below.
7. Report artifact paths, duration/counts, quality gates, model/workflow, and known limitations.

## TTS audibility acceptance test

Use this whenever delivering newly generated TTS, especially after a user reports that audio sounds empty, faint, or broken:

1. **Decode and compatibility:** run a decode check (for example `ffmpeg -v error -i <file> -f null -`) and inspect sample rate, channel count, and PCM/container. Prefer mono/stereo PCM WAV for Slack/macOS delivery unless the requested format differs.
2. **Measure loudness, not only peaks:** inspect integrated LUFS plus true/sample peak. A large crest factor can leave speech effectively inaudible on phone speakers despite a healthy peak and non-silent waveform. For normal spoken samples, master around -16 LUFS with a conservative true-peak ceiling (about -1 to -1.5 dBTP), then re-measure the final file.
3. **Check intelligibility independently:** transcribe the final rendered file with a separate STT path and compare it to the intended source text. A plausible-looking WAV is not enough.
4. **Deliver only regenerated, verified files:** if processing/mastering changes, replace stale sample paths and re-run decode, loudness, and transcription checks on the exact artifacts being sent.
5. **If the model needs scarce shared GPU/RAM:** run sequentially, preserve production-service headroom, and leave no resident model process after a one-shot generation.

For Fish Audio S2 on Legion-specific deployment, cloning, RAM-containment, and verification details, see `references/fish-s2-legion.md`.

## Inbound voice-note transcript recovery

When Slack/WhatsApp reports that local STT failed but the user sent a voice note, do not ask Kenneth to resend before trying the supported fallback:

1. Locate the newest plausible audio cache file under `~/.hermes/audio_cache/` (usually `aud_*.ogg`) and check its size/mtime.
2. Transcribe it through the workspace pathway, not the broken Homebrew/OpenAI Whisper CLI:
   ```bash
   /opt/homebrew/bin/python3 - <<'PY'
   import os, sys
   sys.path.insert(0, os.path.expanduser('~/klaw-workspace'))
   from lib.voice_note_handler import transcribe_audio
   print(transcribe_audio(os.path.expanduser('~/.hermes/audio_cache/aud_XXXX.ogg')))
   PY
   ```
3. Continue the requested task from the recovered transcript. Mention the recovered transcript only if useful for audit or if confidence is uncertain.

## Klaw Keyboard dictation STT

When implementing or debugging Klaw Keyboard dictation:

1. Assemble uploaded keyboard dictation chunks into a real audio container (for current v1 `pcm16`, write a WAV with stdlib `wave`, preserving sample rate/channels from session metadata).
2. Use the shared STT wrapper path so the configured primary provider and fallback chain are honored. For Kenneth's keyboard dictation, prefer the dedicated lijiang `klaw-stt` service (`klaw-stt-then-mlx`) over Voicebox. See `references/klaw-keyboard-stt-backend-selection.md`.
3. Preserve local mlx-whisper fallback through `lib.voice_note_handler.transcribe_audio(path)` / the shared wrapper; it remains the safety net when remote STT fails.
4. Only mark a dictation session finalized after transcription succeeds; cache the successful result for idempotent duplicate finalize calls.
5. If optional cleanup/punctuation via `lib.llm` fails, return the raw transcript rather than failing the entire request.
6. Unsupported codecs should fail with a clear codec error, not with a generic `stt_not_implemented`.

### Klaw Keyboard STT truncation pitfall

A remote Whisper service can still drop audio if its wrapper only feeds a single 30-second feature window to the model. Do not trust model names alone. For long clips, verify the full WAV duration, compare transcript tail against local mlx-whisper, and inspect HuggingFace `WhisperProcessor` output shape when debugging. Voicebox v0.5.0 had exactly this failure mode (`input_features` ending at 3000 frames), so it should not be the primary dictation backend unless upstream long-form ASR is verified.

### Voicebox / long-audio completeness pitfall

When Voicebox `/transcribe` returns a plausible but incomplete transcript for audio longer than ~30 seconds, do not stop at a silence/VAD hypothesis. Inspect whether the backend is feeding HuggingFace Whisper a single 30s feature window: `WhisperProcessor(..., truncation=True, padding="max_length")` plus `WhisperForConditionalGeneration.generate(inputs["input_features"])` silently drops audio beyond 30s. MLX `mlx_whisper.transcribe(path, ...)` may still work because it uses a long-form transcription path. See `references/voicebox-whisper-long-audio-truncation.md` for reproduction probes and fix direction.

For robust keyboard dictation with Voicebox, prefer chunked/long-form transcription plus a completeness guard: if Voicebox returns suspiciously short text for the audio duration, fall back to local MLX or transcribe overlapping chunks and stitch.

### Klaw Keyboard Voicebox completeness pitfall

When the keyboard gateway uses a remote-first STT chain such as `voicebox-then-mlx`, do **not** assume “non-empty transcript” means “complete transcript.” Voicebox can return a plausible partial transcript for a longer full-file WAV; the fallback path may never run because the response is non-empty.

Debugging checklist for “STT missed the ending”:

1. Verify chunk coverage and assembled WAV duration from session metadata first.
2. Re-run the exact full WAV through the production remote STT provider.
3. Re-run the same WAV through local mlx / `lib.voice_note_handler.transcribe_audio()`.
4. If remote full-file STT is shorter, transcribe tail segments separately to prove the audio is present and isolate provider truncation.
5. Compare raw provider outputs before blaming LLM cleanup.

Durable implementation pattern: add a completeness guard for longer clips before accepting remote STT as successful — e.g. words-per-second / duration heuristics, suspicious-ending detection, local mlx fallback for long clips, or chunked remote retry/merge. Session-specific details: `references/keyboard-voicebox-partial-transcript-2026-06-03.md`.

## Source media selection pitfall: replied-to audio beats filename guessing

When Kenneth asks to trim/fix audio and the request is a reply to a specific message containing media, treat the replied-to media as the source of truth. Do not guess from nearby filenames, recent output folders, or similarly named variants (for example Qwen vs Miso or “king” variants). If the message/reply attachment path is not available in the current context, first inspect the platform message/attachment metadata when possible; if that is not retrievable, ask for the exact file/thread rather than editing a plausible nearby audio file. After selecting the source, name the output with the source basename plus the edit range and verify duration/playability with ffprobe/ffmpeg before delivery.

## Saving inbound voice clips

When Kenneth says “save this clip” on an inbound voice note, preserve the actual audio and a small transcript/metadata sidecar; do not only summarize it in chat.

1. Select the source media from the current/replied-to message when available. If the platform only provides the transcript, locate the newest plausible cached audio under `~/.hermes/audio_cache/aud_*.ogg`, verify mtime/size, and confirm duration with `ffprobe`.
2. Copy the original audio unchanged into the canonical Mind iCloud attachment area, e.g. `~/Library/Mobile Documents/com~apple~CloudDocs/Mind/99-attachments/voice-clips/<date>-<slug>.ogg`.
3. Create a matching `.md` sidecar with YAML frontmatter (`type: voice_clip`, `date`, `source`, `artifact`, `duration_seconds`, relevant tags) plus the transcript and a short note.
4. Mirror the same files into the workspace vault backup path (`~/klaw-workspace/vault/99-attachments/voice-clips/`) and commit/push the vault backup per Kenneth’s git rule.
5. If the clip contains an operational correction (travel location, reminder timing, contact detail, etc.), also reconcile the relevant domain source of truth or explicitly report that the clip was saved but the operational record still needs updating. Do not treat “save this clip” as the only required action when the clip is evidence of a durable correction.

## Safety / Quality Rules

- Do not overwrite source media.
- Do not mix speakers in a cloning dataset unless the task explicitly wants multi-speaker data.
- Reject overlapped/noisy/low-confidence segments rather than padding counts with low-quality clips.
- For generated voice/audio, confirm whether the request is a native voice bubble, file attachment, or local artifact.

## Voice-cloning clip selection from large folders

When Kenneth asks for the “best N clips” from a folder of long recordings and the target is voice cloning:

1. Prefer source-preserving batch output: `clips/`, `manifest.json`, `transcripts.json`, `README.txt`, and an audition reel such as `listen_all_N.mp3`.
2. Use mechanical scoring first to create a broad candidate pool: duration bound, loudness, SNR/noise floor, silence ratio, clipping/peak, and simple spectral/ZCR penalties for music/noise-heavy regions.
3. Then run a transcript/ASR gate on candidates. Reject clips with one-word transcripts, repeated-token hallucinations, music-only output, incomplete fragments, or near-duplicate transcript text. Mechanical scoring alone can select bad voice-cloning clips.
4. Keep clips inside the requested duration range after final trimming/normalization; verify with `ffprobe`.
5. Normalize final WAVs consistently (typically mono PCM WAV at 24kHz or the target model’s required rate, with loudness normalization and peak safety limiting).
6. Verify every final WAV and the audition reel decodes with `ffmpeg -v error -i <file> -f null -` before reporting completion.

Pitfalls:
- Long documentary/nature sources often contain music, animal sounds, and duplicated uploads; ASR filtering is useful for catching non-speech and duplicate narration.
- `ffmpeg -t .5` may be rejected on some builds; use `-t 0.5` for synthetic gap/audio durations.
- If a stricter pass improves clip quality but fails late while building an audit artifact, do not discard the selected WAVs. Fix the artifact/metadata step and rerun final decode/duration verification.

## Source separation for voice-cloning cleanup

When voice-cloning clips still contain background music/SFX, prefer source separation before generic denoise. Kenneth approved an isolated Demucs install after security review.

Installed local workflow on Kenneth's macOS Klaw host:

```bash
VENV="$HOME/.local/share/klaw/venvs/demucs"
/opt/homebrew/bin/python3 -m venv "$VENV"
"$VENV/bin/python" -m pip install --upgrade pip
"$VENV/bin/python" -m pip install 'demucs==4.0.1' 'torchcodec==0.14.0'
```

Security notes from review:
- Prefer `demucs==4.0.1` over `audio-separator` for first-line use: Demucs has a smaller dependency surface and is the standard Meta/Facebook Research CLI; `audio-separator` pulls a larger ONNX/tooling stack including `onnx-weekly` dev builds.
- Demucs source package setup script is simple metadata/requirements, MIT licensed, with model weights downloaded from `https://dl.fbaipublicfiles.com/demucs/`.
- Keep the install isolated in `~/.local/share/klaw/venvs/demucs`; do not install globally.
- On Python 3.14/torchaudio, `torchcodec` is required or Demucs may finish inference but fail while saving WAVs with `ImportError: TorchCodec is required for save_with_torchcodec`.

Run vocal isolation:

```bash
VENV="$HOME/.local/share/klaw/venvs/demucs"
IN="/path/to/clip.wav"
OUT="/path/to/output_dir"
"$VENV/bin/demucs" --two-stems=vocals -n htdemucs -d cpu --shifts 1 -o "$OUT" "$IN"
```

For A/B cloned-TTS comparisons from multiple cleaned reference samples, see `references/voicebox-public-figure-sample-clone-workflow.md`. Use the exact same target script for each variant; if the target is Kenneth's morning briefing, generate a fresh dry-run and use that run's `audio_script.txt`.

Expected output:

```text
$OUT/htdemucs/<clip_name>/vocals.wav
$OUT/htdemucs/<clip_name>/no_vocals.wav
```

Post-process the `vocals.wav` stem for voice cloning: convert to mono 24kHz PCM WAV, normalize to the target loudness (usually -16 LUFS), peak-limit safely, and verify transcript/intelligibility. Optionally create a second variant with very light `noisereduce` residual cleanup (`prop_decrease≈0.35`) but compare by ear; over-cleaning creates watery artifacts that can hurt cloning.

Always deliver an A/B audit reel: original → Demucs vocals → optional cleaned vocals → removed background.

## Verification Checklist

- [ ] Source media was preserved.
- [ ] Output files decode cleanly and pass the TTS audibility acceptance test (practical loudness/peak plus independent intelligibility verification), not merely non-empty/playable.
- [ ] For Minion-generated user-facing audio, the verified completion callback uploads every requested artifact to the originating thread; a text report or local path is not delivery.
- [ ] Transcripts/datasets include enough metadata to audit segments.
- [ ] Dataset quality gates and exclusions were reported.
- [ ] If Kenneth asked to test a specific TTS/voice model, the delivered audio was actually generated by that model; any fallback is explicitly labeled as a fallback, not presented as satisfying the request.

## Cloned-voice comparison samples

When Kenneth asks for a longer cloned-voice sample, or says to “do the same” in another voice:

1. Use the same target sentence for every compared voice so the A/B is meaningful.
2. Aim for the requested approximate duration, but verify and report the actual duration with `ffprobe` rather than guessing.
3. For text containing apostrophes, quotes, or long JSON payloads, prefer a short Python `urllib.request`/`json.dumps` script over shell heredocs/process substitution; brittle shell quoting can corrupt the request or fail before generation.
4. Decode-check every generated file with `ffmpeg -v error -i <file> -f null -` before delivery.
5. Deliver each media file with a clear voice label and include the model/workflow used.
6. If generation was interrupted or partially failed, rerun the full requested set and verify all outputs before replying; do not present a stale or half-generated comparison.

## Pitfalls

### Specific-model TTS requests must use that model

When Kenneth asks to “try Miso,” “test Voicebox,” “use Rosie through X,” or otherwise names a specific audio model/workflow, do not substitute an easier/default TTS path unless he explicitly approves the fallback. If the named model has length limits or is slow, adapt the workflow (chunk/stitch, run sequentially, background it, and verify files) instead of silently switching to Base TTS/OpenAI/Voicebox.

For MisoTTS on lijiang specifically, see `references/miso-tts-lijiang.md` for the wrapper, chunking pattern, and performance caveats.
