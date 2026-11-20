# Two-Release Brewing Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or
> superpowers:executing-plans for implementation. This is the concise approved
> plan record, not a new request to execute runtime changes in this docs task.

**Goal:** Replace hold/release/settle with two explicit pressure checks and
deterministic, persisted potion quality.

**Architecture:** BrewingReaction owns simulation; PotionMixer owns recipes,
reservations, quality, and pending preparation. PotionCombatController integrates
input, suspension, modular presentation, and the existing durable held-bottle
handoff. Effects remain delivery-independent and shared resources immutable.

**Tech Stack:** Godot 4.x, GDScript, scene components, editable `.tres` resources.

**Spec:** User-approved 2026-11-17 contract, recorded below and in
[brewing README](../../../combat/potions/brewing/README.md).

**Status:** Approved; runtime implementation/integration underway. This
documentation-only update is dated 2026-11-18. Automated verification belongs
to main integration; manual tests are pending. No new pass claims or totals.

## Global Constraints

- Keep ingredient reservations and attach/hold/save/acknowledge semantics.
- Preserve unrelated working changes, recipe identity, delivery, and consumption.
- All new tunings live in `.tres`; no runtime changes or commits in this docs task.
- Preserve historical plans and future laboratory/vessel/placement vision.

## Approved Work Packages

### 1. Reaction and Resources

Files: `combat/potions/brewing/BrewingReaction.gd`, `BrewingProfileData.gd`,
existing `SmallFlaskBrewingProfile.tres` with new semantics; new
`BrewingPresentationProfileData.gd` and `BrewingPresentationProfile_Default.tres`
in the same folder for visuals/input.

First Space press starts heat. Next two distinct presses release pressure, one
per heat; key-up/repeat never checks. Height `0..1` rises at `0.75/sec * power`,
power `0..1`, initial `0.5`. Ideal `0.65..0.75` inclusive scores `+1`; normal
`0.50..0.90` inclusive excluding ideal scores `0`; otherwise `-1`. Overflow at
`1` automatically checks for `-1`. Each drop/reset lasts `0.22s`; first restarts
heat automatically, second completes even at score `-2`.

API: `start`, `release_pressure`, `set_heat_power`, `set_suspended`, `advance`,
`cancel`, state/height/power/cycle/score/blend/results getters. Signals:
`state_changed(state)`, `reaction_changed(height,power,blend)`,
`check_completed(index,score)`, `completed(score)`. Remove agitation APIs.

### 2. Quality, Effects, and Persistence

Files: new `combat/potions/PotionQualityProfileData.gd` and
`combat/potions/resources/PotionQualityProfile_Default.tres`; update
`PotionInstance.gd`, `effects/PotionImpactContext.gd`, health/slow effect classes,
and `globals/profile/PlayerProfile.gd` / `PlayerProfileStore.gd`.

Sum two checks to `-2..2`; map to `0.6,0.8,1.0,1.2,1.4`. Health magnitude uses
`roundi(base * multiplier)`. Slow magnitude scales; duration/cap stay unchanged.
Instance owns score and multiplier. Store V2 persists both; V1 reads as normal
(`0`, `1.0`). Preserve transactional spending and held ownership.

### 3. Mixer, Input, and Controller

Files: `combat/potions/PotionMixer.gd`, `combat/PotionInput.gd`,
`combat/PotionCombatController.gd`, and Input Map wiring in `project.godot`.

Retain `start_brewing()` and explicit manual `release_brewing()` (not key-up).
Emit `brewing_changed(state,height,power,blend)` and guard pending preparation
against duplicate completion. Input emits `mix_pressed`, `heat_adjust_requested`,
`focus_changed`. Z/X step 5%, hold delay `0.3s`, repeat `0.1s`. Tab suspends/hides
and resumes on reopen; pause/focus loss suspend and clear holds. C cancels and
releases reservations. Main controller owns integration, not simulation rules.

### 4. Presentation

Files: `combat/ui/PotionMixerUI` and `FlaskView` scripts/scenes, modular
`HeatControl` and `AlchemicalBurner` scenes plus workshop; flame asset
`sprites/vfx/alchemical_fire/alchemical_fire_v001.png`.

Mixer `360x290`, FlaskView `144x190`, existing Tube 01 glass/mask. One ideal
bracket maps through the same liquid height. Gradual layer blending reaches
full recipe color only after second reset. Show two scores and a short result.
Place `0..100` slider under flame. Built-in image generation plus cleanup delivers
four `16x16` flame frames in a `64x16` sheet, following asset production rules.

## Review Focus and Pending Verification

- [ ] `BrewingReactionTests`: pin inclusive boundaries, outside-window scores,
  zero/max power, overflow, both `0.22s` resets, and exactly-once completion.
- [ ] `BrewingCombatTests`: distinct presses, no key-up/repeat check, Z/X timing,
  Tab suspension, pause/focus held-control clearing, and C cancellation.
- [ ] `PotionDomainTests` / `PotionQualityTests`: every summed score and potency,
  pending guard, reservation preservation, and failed acknowledgement cleanup.
- [ ] `PotionUseTests` / `PlayerProfileTests`: rounded health, scaled slow with
  unchanged duration/cap, V1 normal migration, V2 quality round-trip, and save
  failure without ingredient loss, duplication, or a usable orphaned bottle.
- [ ] `PotionVisualTests` and manual workshop/combat checks: slider parity,
  bracket alignment, progressive blend, final-color timing, flame frames,
  scores/result, and 360x290 layout at 1920x1080 and 1280x720.

Main integration should run the affected headless test scenes using the
architecture document's Godot runner (for example,
`Invoke-GodotWait '--headless --fixed-fps 60 --path . res://tests/BrewingReactionTests.tscn'`),
then import/scene smokes and the manual checks. Record actual results only after
those runs; the older architecture totals are historical, not this plan's proof.
