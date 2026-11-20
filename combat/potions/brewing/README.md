# Small-Flask Brewing

The approved two-release contract replaces hold/release/settle brewing. Runtime
integration, quality persistence, independent fire, and local feedback are in
place; manual feel and audio-balance testing remain ongoing. See the
[approved plan](../../../docs/superpowers/plans/2026-11-17-two-release-brewing.md).

## Runtime Ownership

- `BrewingReaction.gd` owns deterministic height, two checks, drops, blending,
  suspension, and completion independently of recipes, effects, input, and UI.
- `BrewingProfileData.gd` defines the new semantics of the existing
  `SmallFlaskBrewingProfile.tres`: rise rate, score windows, and reset duration.
- `BrewingPresentationProfileData.gd` and
  `BrewingPresentationProfile_Default.tres` own visual and input tuning.
- `../PotionMixer.gd` owns layers, reservations, recipe matching, quality lookup,
  and the pending-preparation guard and acknowledgement handshake.
- `../PotionQualityProfileData.gd` and
  `../resources/PotionQualityProfile_Default.tres` map scores to potency.
- `PotionCombatController` wires input, suspension, UI, held ownership, and save
  acknowledgement. Presentation never owns reaction rules.

## Reaction and Quality

With a valid three-unit recipe, the first distinct Space press starts heating.
The next two distinct presses release pressure, one during each heating cycle;
key-up does not release pressure and key repeat does not trigger a check.
Height is `0..1`, rising at `0.75 * power` per second. Power is `0..1`, initially
`0.5`; zero power stops the rise. Each manual release scores its current height:

| Height | Score |
| --- | --- |
| `0.65..0.75`, inclusive | `+1` |
| `0.50..0.90`, inclusive, excluding the ideal window | `0` |
| Any other height | `-1` |
| Overflow at `1.0` | Automatic `-1`, without a press |

Each check starts a `0.22`-second drop/reset. The first reset automatically
starts the second heat; after the second reset a potion is prepared even at
total score `-2`. There is no early-settle retry or overreaction cooldown.
The two scores sum to `-2..2`, mapping respectively to potency multipliers
`0.6`, `0.8`, `1.0`, `1.2`, `1.4`. Health magnitude uses
`roundi(base_amount * multiplier)`; slow magnitude scales while its duration
and existing cap remain unchanged. Shared effect resources are not mutated.

Each `PotionInstance` retains score and multiplier. Profile store V2 persists
both with the held bottle; V1 loads as normal quality (`0`, `1.0`). Ingredient
reservations and the attach/hold/save/acknowledge transaction remain intact;
the pending guard prevents duplicate preparation before acknowledgement.

## Controls and Suspension

- Z/X decrease/increase power by `5%`, with a `0.3`-second hold delay and
  `0.1`-second repeat interval. The slider beneath the flame spans `0..100`.
- Tab hides and suspends an unfinished reaction; reopening resumes it.
- Pause and focus loss suspend progression and clear held controls; resumption
  must not synthesize a pressure release or retain a heat-adjustment hold.
- C cancels immediately, clears unfinished layers, releases reservations, and
  prevents delayed completion. Ingredient edits remain locked during brewing.

## Public Contract

`BrewingReaction` exposes `start()`, `release_pressure()`, `set_heat_power()`,
`set_suspended()`, `advance()`, `cancel()`, `get_state()`, `get_progress()`
(height), `get_heat_power()`, `get_cycle_index()`, `get_quality_score()`,
`get_blend_progress()`, `get_results()`, and `is_editable()`.
States are `IDLE`, `HEATING`, `RESETTING`, and `COMPLETED`; suspension preserves
the current state. Signals are `state_changed(state)`,
`reaction_changed(height, power, blend)`, `check_completed(index, score)`, and
`completed(score)`.

The mixer retains `start_brewing()` and `release_brewing()`; the latter is an
explicit manual pressure release, not a key-up callback. It emits
`brewing_changed(state, height, power, blend)` and forwards check results.
Input emits `mix_pressed`, `heat_adjust_requested`, and `focus_changed`.
Old agitation APIs, predicted settling, and recovery signals are removed.

## Presentation and Feedback Contract

The mixer is `360 x 290`; `FlaskView` retains its `144 x 190` slot and existing
Tube 01 glass/mask. Two marks sit directly on the glass at the inclusive ideal
bounds. They connect in gold only while the current height will actually score
`+1`; both the simulation and presentation call the profile's shared scoring rule.
Layers blend gradually; full recipe color appears only after the second reset.
Display two check scores and a short result, without a predicted-settle marker.
Each release also produces flask-local feedback and a replaceable SFX cue: a
gold glass-outline flash for `+1`, restrained neutral confirmation for `0`, and red
turbulence for `-1`. A total score of `+2` adds a persistent accent to the
UI flask and physical bottle, emits low-count gold sparks, and plays a completion
cue; it does not add power beyond the existing `1.4` multiplier. The physical
effect follows the same `PotionEntity` while held, flying, or placed and restores
from the persisted quality score.

Modular `HeatControl` and `AlchemicalBurner` scenes plus a workshop isolate
presentation. The built-in generated and cleaned flame asset is
`sprites/vfx/alchemical_fire/alchemical_fire_v001.png`: four `16 x 16` frames
in a `64 x 16` sheet. All new simulation, quality, visual, and input tunings
belong in their `.tres` resources, not controller or UI constants.

The burner has an independent on/off control. Starting a valid brew auto-lights
an extinguished burner and restores its pre-brew state afterward unless the
player manually changes it during brewing. Extinguishing it freezes height
without cancelling the reaction; relighting resumes from the same height. Power
above `90%` enlarges the flame and enables a localized gold glow without changing
the linear simulation formula. It also enables small random-direction gold sparks;
exactly `90%` does not. `vfx/gold_sparks/BurnerGoldSparkProfile.tres` tunes the
burner at `5` emissions/second with at most `4` visible particles, while
`PerfectPotionGoldSparkProfile.tres` tunes perfect bottles at `4` emissions/second
with at most `3`. Both use the reusable scene-backed `GoldSparkEmitter.tscn`.
Prototype WAV files live under
`audio/sfx/brewing/`, use the `SFX` bus, and can be replaced without changing
gameplay code.

## Verification

Main integration verifies reaction boundaries, overflow, both resets,
distinct presses, zero power, suspension, cancellation, duplicate-preparation
protection, potency effects, V1/V2 saves, and reservation/save failure handling.
Relevant suites include `BrewingReactionTests`, `BrewingCombatTests`,
`PotionDomainTests`, `PotionQualityTests`, `PotionUseTests`, `PotionVisualTests`,
and `PlayerProfileTests`. Burner lifecycle, paused height, high-heat presentation,
SFX scene wiring, and perfect-quality bottle presentation are covered by the
brewing and visual suites.
Manual checks must cover keyboard/slider parity, interruption/resume, bracket
alignment, progressive blending, flame frames, scores, and layout at supported
window sizes. Larger vessels and staged laboratory recipes remain future work.
