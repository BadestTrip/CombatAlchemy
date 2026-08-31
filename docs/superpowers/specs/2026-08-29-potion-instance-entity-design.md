# Potion Instance And Physical Entity Design

## Summary

Replace the current prepared-recipe-plus-projectile flow with one produced
potion domain object and one physical scene representation. A successful mix
creates a unique `PotionInstance`. While the potion is held, thrown, placed, or
dropped, a `PotionEntity` represents that same instance in the scene tree.

This establishes the ownership boundary needed for later potion storage without
implementing inventory UI, stacking, persistence, or multiple held slots now.

## Goals

- Distinguish a static recipe from one potion actually produced from it.
- Create one physical bottle after a valid mix.
- Use that same `PotionEntity` node when the bottle moves from held to flying or
  placed state.
- Preserve one-use effect resolution through `PotionEffectResolver`.
- Add ground placement as a third delivery method.
- Make later storage operate on `PotionInstance`, not off-tree scene nodes.
- Preserve current mixing, drinking, throwing, collision, pause, movement, and
  capability-based effect behavior.

## Non-Goals

- No inventory screen, bottle grid, stacking, or item sorting.
- No permanent save/load or serialization format.
- No potion quality, temperature, aging, contamination, volume, or multiple
  doses.
- No pickup interaction for placed or dropped bottles.
- No drink, throw, or place animation timing.
- No enemy AI, victory, defeat, or exploration changes.

## Domain Model

| Type | Responsibility |
| --- | --- |
| `PotionRecipeData` | Immutable shared formula: reagent counts, display color, and effect resources. |
| `PotionInstance` | One unique produced potion: recipe reference, copied creation layers, and consumed state. |
| `HeldPotionSlot` | Own at most one held instance and its current physical entity reference. |
| `PotionEntity` | Scene-backed bottle visual and physical lifecycle: held, flying, placed, consumed. |
| `PotionEffectResolver` | Apply a recipe's effects to capabilities exposed by an impact context. |

`PotionRecipeData` remains reusable resource data. Runtime code must never mutate
the recipe or its shared effect resources.

`PotionInstance` extends `RefCounted`, not `Resource`. Every successful mix
creates a fresh instance. A future inventory stores these objects or serialized
snapshots of them; it never stores inactive `Node` objects.

## Ownership And Lifecycle

```text
PotionMixer
  -> creates PotionInstance
  -> PotionCombatController creates PotionEntity
  -> HeldPotionSlot owns both references

HeldPotionSlot
  -> drink: PotionEntity applies instance to Player, then consumes itself
  -> throw: releases entity into world in FLYING state
  -> place: releases entity into world in PLACED state
  -> clear: discards instance and consumes entity without applying effects

FLYING
  -> first non-caster collision applies instance and consumes entity

PLACED
  -> arms after delay
  -> first eligible trigger applies instance and consumes entity
```

Only one owner may expose a usable potion at a time. `PotionInstance.apply()` is
the final once-only guard. It marks the instance consumed before invoking the
resolver, so duplicate physics signals cannot apply effects twice. A valid
impact consumes the potion even when no effect reaches a supported capability.

## Public Interfaces

### PotionDelivery

Central StringName constants:

```gdscript
const DRINK: StringName = &"drink"
const THROW: StringName = &"throw"
const PLACE: StringName = &"place"
```

`PotionImpactContext.delivery_method` becomes `StringName`. Unknown non-empty
delivery IDs remain legal for future actions; an empty ID falls back to
`PotionDelivery.THROW`.

### PotionInstance

```gdscript
static func create(recipe: PotionRecipeData, layers: Array[StringName]) -> PotionInstance
func is_valid() -> bool
func is_consumed() -> bool
func get_recipe() -> PotionRecipeData
func get_created_layers() -> Array[StringName]
func get_color() -> Color
func apply(context: PotionImpactContext) -> int
func discard() -> bool
```

`create()` returns `null` for an invalid recipe or layers that do not match the
recipe. Layer order is copied and preserved. `apply()` returns the number of
supported effects, returns `0` for invalid contexts or repeated use, and consumes
the instance for every valid context. `discard()` marks an unused instance
consumed and returns whether state changed.

### HeldPotionSlot

```gdscript
signal potion_changed(potion: PotionInstance)

func hold(potion: PotionInstance, entity: PotionEntity) -> bool
func has_potion() -> bool
func get_potion() -> PotionInstance
func get_entity() -> PotionEntity
func clear() -> void
```

`hold()` fails when the slot is occupied, either argument is invalid, the entity
does not contain the same instance, or the instance is consumed. `clear()` only
releases references; the caller must first transition or discard the entity.

### PotionEntity

```gdscript
enum State { HELD, FLYING, PLACED, CONSUMED }

signal state_changed(state: State)
signal resolved(context: PotionImpactContext, applied_effect_count: int)

func initialize(potion: PotionInstance, source: Node) -> bool
func attach_to(holder: Node2D) -> bool
func drink(target: Node) -> bool
func throw_into(world_parent: Node2D, origin: Vector2, direction: Vector2) -> bool
func place_into(world_parent: Node2D, world_position: Vector2) -> bool
func discard() -> bool
func get_state() -> State
func get_potion() -> PotionInstance
```

Initialization succeeds once with a valid unused instance. Public transitions
are accepted only from `HELD`. Failed transitions leave ownership and state
unchanged. Consumed entities disable all monitoring and queue themselves for
deletion after emitting their final signals. Monitoring changes made from
`area_entered` or `body_entered` callbacks use `set_deferred()` so physics
state is never mutated while Godot has the collision query locked.

## Scene Structure

`combat/potions/PotionEntity.tscn` is authored as:

```text
PotionEntity (Node2D)
|- BottleVisual (Polygon2D)
|- Outline (Line2D)
|- FlightArea (Area2D)
|  `- CollisionShape2D (CircleShape2D, radius 13)
|- SweepCast (ShapeCast2D, same radius, masks world layer 1 and hitbox layer 2)
`- PlacementTrigger (Area2D)
   `- CollisionShape2D (CircleShape2D, radius 42)
```

Held state disables both collision areas and the sweep. Flying state enables
`FlightArea` and swept collision using the current projectile behavior. Placed
state disables flight and enables only `PlacementTrigger`, which scans actor
hitbox layer 2.

The held entity is parented to the Player's `hand_right` socket at local origin.
Throw and place reparent that same node into `Arena/PotionEntities` with global
transform preserved or explicitly assigned.

## Placement Rules

- Input action: `place_potion`, bound to physical `Q`.
- Placement point: Player world position plus current aim direction multiplied
  by exported `place_distance`, default `64.0` pixels.
- Arming delay: `0.35` seconds.
- Trigger mask: actor impact hitboxes on layer 2; the floor and static walls do
  not trigger a placed potion.
- The source is ineligible while initially overlapping the trigger. After the
  source exits, it becomes eligible on re-entry.
- When arming completes, already-overlapping non-source hitboxes are evaluated
  immediately so placement beside a stationary actor still works.
- The first eligible trigger consumes the potion even when the actor supports
  none of its effects.
- Default placed lifetime: `20.0` seconds. Expiration discards the potion.

## Mixer And Input Changes

`PotionMixer` owns only reagent layers and recipe matching. It no longer stores
a prepared recipe. A successful mix creates `PotionInstance`, clears the layers,
and emits:

```gdscript
signal potion_prepared(potion: PotionInstance)
```

Remove `has_prepared_potion()`, `get_prepared_recipe()`, and
`take_prepared_recipe()`. `PotionCombatController` gates mixing and Tab using
`HeldPotionSlot.has_potion()`.

`PotionInput` replaces separate drink/throw signals with:

```gdscript
signal potion_use_requested(delivery_method: StringName)
```

Right Mouse emits `DRINK`, Left Mouse emits `THROW`, and `Q` emits `PLACE`.

## Combat Integration

`PotionCombatController` receives each produced instance, instantiates one
`PotionEntity`, initializes it with the Player as source, attaches it to the
right-hand socket, and stores both references in `HeldPotionSlot`. Failure at any
step discards the instance and leaves the mixer open for another attempt.

Drink, throw, and place ask the held entity to transition first. The controller
clears the slot and closes the mixer only after a successful transition. Tab is
ignored while the slot is occupied. `C` discards a held potion, clears the slot,
and returns to an open empty mixer.

`Arena/Projectiles` is renamed to `Arena/PotionEntities`. The old
`PotionProjectile.gd` and `PotionProjectile.tscn` are deleted only after all
flying collision tests pass against `PotionEntity`.

## Future Storage Boundary

A later `PotionInventory` will store `PotionInstance` references. Storing a held
potion will remove its `PotionEntity` and transfer the instance from
`HeldPotionSlot` to inventory. Retrieving will create a new `PotionEntity` bound
to the same unconsumed instance. This task does not implement that transfer or
any inventory UI.

## Verification

- Every successful mix creates a fresh instance with copied layer order.
- An instance applies once and cannot be reused after impact or discard.
- The slot cannot hold two potions or mismatched entity/instance pairs.
- The same entity node moves from held to flying or held to placed.
- Drink heals or damages the Player according to recipe effects.
- Flying collision preserves thin-wall, actor-area, caster-ignore, and miss
  expiration behavior.
- Placement arms after `0.35` seconds, ignores the initial source overlap, and
  applies to the first eligible trigger.
- Unsupported collision subjects consume the potion without errors.
- Tab, clear, UI visibility, movement, camera, pause, settings, and current
  recipes continue to work.
- No active reference remains to `PotionProjectile` or mixer-owned prepared
  recipes.

## Assumptions

- Godot version remains 4.7.2.
- Only one held potion slot is implemented now.
- Every potion has one use.
- Placement uses `Q` and the current mouse aim direction.
- No action animation delays potion transitions.
- Existing uncommitted user changes remain preserved.
