# REDLINE v0.5 audio credits

## Music
“Super Wreck Roadway” (loop version), Umplix.
Source: https://opengameart.org/content/super-wreck-roadway
License: CC0 1.0 — https://creativecommons.org/publicdomain/zero/1.0/
Modification: WAV converted to Ogg Vorbis; in-game gain/crossfade/impact ducking.
Original download: assets/audio/source/super_wreck_roadway_loop.wav.

## Motorcycle field recordings
“Engines - Startup, Idle & Rev”, dklon.
Source: https://opengameart.org/content/engines-startup-idle-rev
License: Creative Commons Attribution-ShareAlike 3.0 Unported.
License URL: https://creativecommons.org/licenses/by-sa/3.0/
Legal code: https://creativecommons.org/licenses/by-sa/3.0/legalcode
The edited engine.wav and engine_idle.wav are distributed under the same CC-BY-SA 3.0 license. No endorsement by the author is implied.
Modifications: source 090912-004.mp3, mono 44.1 kHz conversion, high/low-pass filtering, 24–27 s idle and 12.5–14.6 s rev excerpts, 130 ms overlap-add loops, gain normalization. Runtime pitch/load blending.
Original archive retained at assets/audio/source/dklon-engines.zip; reproducible editing in scripts/build_audio.py.

## Original Foley
hit_0–2, wood_0–2, metal_0–2, swing, shift, crash, tire, wind, siren and menu are deterministic layered synthesis created for this project (scripts/build_audio.py). They do not contain excerpts from the engine recordings or music.

## Engine sound banks and finish cue (2026-09)
`assets/audio/engines/{ratchet,revenant,phantom}_{idle,low,high,coast,pop,start}.wav` are phase-continuous layered exhaust banks. The idle/low/high/coast/start banks combine project-generated firing pulses and resonances with edited high-frequency mechanical texture from dklon's recordings `090912-004.mp3` (24 s onward), `090912-017.mp3` (3 s onward) and `090913-009.mp3` (3 s onward). These adapted banks are distributed under CC-BY-SA 3.0, with the same attribution and source URL above. Editing includes filtering, circular loop blending, resampling, synthesized firing timing and gain normalization; rebuild with `uv run scripts/build_engine_audio.py`.

The pop cues and `victory.wav` are original project synthesis (no third-party recording excerpts). Engine styles are fictional sport-twin, cruiser-twin and inline-four interpretations, not recordings or endorsements of any named motorcycle brand.
