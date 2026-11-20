# Brewing SFX Prototypes

Deterministic, synthesized mono WAV placeholders for rapid iteration. They use
the existing `SFX` bus and can be replaced without changing gameplay APIs.

- `fire_loop.wav`: low alchemical flame bed.
- `boil_loop.wav`: liquid pressure cue.
- `release_bad.wav`, `release_normal.wav`, `release_perfect.wav`: immediate
  result hierarchy.
- `perfect_brew.wav`: two-check `+2` completion accent.

Build with `build_sfx.py`. Runtime files are written to
`audio/sfx/brewing/` at 22.05 kHz, mono, signed 16-bit PCM.
