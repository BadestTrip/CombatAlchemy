# Small-Flask Brewing

This folder owns the one-stage combat brewing simulation. It has no recipe,
effect, entity, input, or UI responsibilities.

## Runtime Ownership

- `BrewingProfileData.gd` defines editable vessel timing and thresholds.
- `SmallFlaskBrewingProfile.tres` is the active three-unit flask tuning.
- `BrewingReaction.gd` integrates reaction progress, energy, settling,
  cooldown, completion, and predicted settled progress.
- `PotionMixer.gd` owns ingredients and recipe matching, then creates one
  `PotionInstance` when `BrewingReaction` completes.

The default profile ramps energy from zero to one in `0.25` seconds, advances
progress at `0.55 * energy` per second, dissipates full energy in `0.45`
seconds, succeeds from `0.70` through `0.90`, and recovers an overreaction to
`0.40` after a `0.60` second cooldown.

## Placeholder Geometry Contract

The active interface remains `360 x 210` pixels. `FlaskView.tscn` occupies the
left `144 x 190` slot; each reagent swatch is `60 x 60` pixels.

Inside the flask scene:

- authored liquid/reaction space runs from local `y = 82` to `y = 180`;
- `SuccessWindow` brackets the active profile range at local `x = 130..138`;
- `CurrentProgressMarker` points inward from local `x = 16`;
- `PredictedSettleMarker` sits at local `x = 125`;
- `Layer1`, `Layer2`, and `Layer3` retain their authored rest positions;
- `Grains` and `Foam` are scene-authored containers animated by `FlaskView.gd`.

Replacement art may change shapes and colors, but should preserve these node
names or update `FlaskView.gd` in the same reviewable change. Keep the progress
mapping vertical, make current and predicted endpoints distinguishable without
color alone, and keep all reaction feedback inside the flask footprint.

## Tuning Rules

Edit the profile resource instead of hard-coding timings in input, controller,
or UI scripts. Keep `recovery_progress` below the success range. If tuning
changes the clean-brew duration, rerun `BrewingReactionTests.tscn`,
`PotionDomainTests.tscn`, `BrewingCombatTests.tscn`, and `PotionUseTests.tscn`.

Larger vessels and multi-stage laboratory recipes require separate data and
tests. They should not be implemented by increasing this mixer's layer limit.
