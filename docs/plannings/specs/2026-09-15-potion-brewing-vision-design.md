# Potion Brewing, Vessel Progression, and Strategic Placement

> Status: Small-flask Stage 1 implemented; larger vessels and strategic systems remain future direction
> Approved and recorded: 2026-09-15
> Creative source: [Style and Vision](../../STYLE_AND_VISION.md)
> Runtime source: [Project Architecture](../../PROJECT_ARCHITECTURE.md)
> Ownership foundation: [Potion Instance and Physical Entity Design](./2026-08-29-potion-instance-entity-design.md)

## Purpose and Boundaries

Make brewing a short, physical act of observation and commitment in combat,
with a deeper version of the same interaction at the refuge. A recipe determines
what the finished potion does. Drinking, throwing, placing, and future storage
determine how that same preparation is used, not which effect it contains.

This records the approved vision and distinguishes the delivered first stage
from future scope. Active combat now implements one deterministic three-unit
small-flask reaction: hold Space, release, settle, resume early progress, and
recover overreaction without losing ingredients. Placed bottles still use a
temporary proximity trigger. Larger vessels, transformation, deliberate
activation, refuge brewing, and potion storage are not implemented.

## Shared Interaction: Agitate, Anticipate, Release, Settle

1. Add the recipe's reagents to a suitable vessel.
2. Hold Space to agitate the mixture and add reaction energy.
3. Read the liquid motion, dissolving grains, color streaks, and sound as the
   reaction develops. A broad marked window on the flask indicates when releasing
   is likely to produce a usable result.
4. Release Space to stop adding energy immediately. Existing liquid motion and
   reaction energy briefly continue before dissipating.
5. Judge the settled result. A successful final stage produces the expected
   potion exactly once; an unfinished stage remains a mixture.

The input must feel immediate. Residual motion is visible liquid behavior, not
an artificial delay between releasing the key and stopping the input. Learnable
momentum makes anticipation matter without requiring a tiny perfect-timing hit.

Two conceptual values explain the behavior:

- **Reaction progress:** how far the current brewing stage has developed.
- **Remaining reaction energy:** how much further it may develop after release.

They need not appear as numeric meters. The flask and sound should communicate
both, with an explicit readable release cue during the first prototype. Do not
require the player to guess invisible momentum. Identical ingredients, vessel,
and inputs should behave consistently enough to learn.

### Illustrative Release Outcomes

These numbers explain the mechanic only. They are not balance values, UI labels,
or a required simulation formula. Suppose a usable settled result lies at 70-90:

| Release progress | Illustrative settled progress | Result |
| --- | --- | --- |
| 40 | 50 | Still developing; resume agitation. |
| 62 | 75 | Successful preparation. |
| 76 | 87 | The same successful preparation, not a different potency roll. |
| 88 | Above 95 | Overreaction; visible foam or separation and a recovery/retry cost. |

The satisfying moment should be the visible transition from turbulent mixture
to a coherent finished liquid, supported by a concise glass/liquid resolve.
Successful timing is a design hypothesis to playtest, not a guarantee of
engagement or a reason to add increasingly narrow timing windows.

## Brewing States Are Not Bottle States

| Proposed brewing state | Meaning and feedback |
| --- | --- |
| Unmixed | Ingredients are present as distinguishable layers or grains. |
| Developing | Agitation is transforming them; an early settled mixture can resume. |
| Ready to stabilize | The flask indicates that release and settling should complete the stage. |
| Overreacting | Excess energy causes readable foam/separation; stop, recover, and retry. |
| Finished | The final stage has settled successfully and produces a usable potion. |

These are player-facing design terms. `BrewingReaction.State` implements the
technical states `IDLE`, `AGITATING`, `SETTLING`, `COOLDOWN`, and `COMPLETED`.
The existing `HELD`, `FLYING`, `PLACED`, and `CONSUMED` states describe the
physical lifecycle of a finished bottle and remain a separate responsibility.

For the first brewing prototype:

- Early release preserves ingredients and progress that can be resumed.
- Invalid combinations remain visibly unfinished or rejected; timing cannot
  substitute for the recipe's ingredients. A valid formula unknown to the player
  may still succeed and be discovered through experimentation.
- Overreaction is a recoverable time cost, not automatic loss of rare ingredients,
  a surprise explosion, or random damage.
- Intermediate laboratory stages do not create usable potions.
- A completed recipe has one dependable result. Small timing differences within
  the usable window do not create mandatory quality tiers or per-bottle stat rolls.
- A finished potion does not keep brewing or degrading merely because it is held,
  placed, or eventually stored.

The first recovery rule is implemented as a `0.6` second cooldown followed by
`40%` retained progress and a required fresh press. Tab-hide, pause, Escape, and
focus loss release agitation without ingredient loss. Free movement remains
available in combat; this mechanic introduces no slow motion, gameplay pause,
or action-animation delay on an already finished potion.

## Two Brewing Contexts

| Context | Intended interaction | Source of difficulty |
| --- | --- | --- |
| Small field flask | Add a few ingredients, perform one short reaction, release, settle, and use. | Finding a safe moment while still reading and moving through combat. |
| Larger laboratory vessel | Perform several meaningful reagent and reaction stages using the same hold/release language. | Understanding stage behavior, sequence, momentum, and stabilization. |

A field reaction of roughly 1-3 seconds is a starting experiment, not a locked
duration. Laboratory brewing should take longer because it contains worthwhile
operations, not because the same progress bar fills more slowly. Do not commit
to a total safe-house duration before repeated brewing has been playtested.
Routine known preparations may eventually need batching or streamlining; these
are later design questions, not extra MVP systems.

## Vessel Capacity and Knowledge Progression

Capacity counts **ingredient units**, including repeats of the same reagent.
Red, red, blue uses three units, not two. Working capacity also needs enough
headroom for the recipe's reaction; vessel size should have a physical reason.

Small, medium, and large capacities of 3, 5, and 8 units are illustrative tiers,
not approved resource values. The player may discover a powerful recipe before
owning suitable apparatus. The missing vessel becomes a concrete preparation
goal rather than hiding the discovery behind a character level.

- Small field vessels remain useful for speed, low ingredient cost, and reliable
  basic recipes. A larger vessel is not a universal replacement.
- Larger equipment enables additional ingredients and meaningful brewing stages.
  Complexity should introduce decisions, not just bigger numeric effects.
- Recipe knowledge, available ingredients, and suitable apparatus are distinct
  requirements. Knowledge remains the leading form of progression.
- A **brewing vessel** is not necessarily the **portable finished bottle**. A
  large reaction may eventually yield a concentrated portable dose or a batch.
  Yield, dose count, and transfer rules remain future decisions; the current
  system still produces one single-use bottle per successful recipe.
- The current one-held-slot limit is an MVP ownership boundary, not a permanent
  ban on preparing and storing several potions.

## Example: Strong Transformation Potion

The example formula transforms a compatible receiving entity into a strong
mutant. It requires a larger brewing vessel and several stages; no exact RGB
formula, duration, stat multiplier, or permanent transformation is approved.

1. **Extract the active compound.** Add initial reagents, agitate gently, and
   release as the grains dissolve. The result remains an intermediate mixture.
2. **Bind the transformation agent.** Add further ingredients. This reaction has
   greater momentum, so release earlier relative to its settled endpoint.
3. **Stabilize the formula.** Add the stabilizer and complete a short controlled
   reaction. Only this final successful settle creates the transformation potion.

Its delivery does not change the formula:

| Use | Intended result |
| --- | --- |
| Drink | Apply transformation to the drinker if they support it. |
| Throw | Apply transformation to the struck subject; any splash footprint must be explicitly defined and implemented. |
| Place, then activate | Release the same transformation effect to eligible subjects at the prepared location. |
| Store later | Preserve the unused preparation for one of those uses, without silently changing its recipe. |

Transforming an enemy may strengthen that enemy. Friend/Foe labels must not
silently reverse the potion's meaning. Empty ground cannot become a mutant
without a separately designed environmental capability. Transformation should
not implicitly change allegiance, reset health, or invent AI behavior.

An area effect is future scope, not an existing resolver feature. If introduced,
one bottle must still be consumed once while its single activation resolves
against explicitly selected recipients. Repeatedly consuming the same instance
for each recipient would violate the current ownership contract.

## Strategic Placement and Return

The desired first strategic use is **deliberate activation on return**. A placed
preparation remains dormant until explicitly activated. Proximity traps, remote
triggers, and chains may be later options; they are not automatic requirements.

Example: prepare a transformation potion at the refuge, place it near a narrow
passage, explore beyond it, then retreat to that location. Activate it when a
compatible subject is in its defined effect area. The advantage comes from
preparation, location, access, timing, and who receives the effect.

This requires more than extending the current 20-second expiry:

- Preserve unused placements long enough for the intended return, with no default
  brewing decay or surprise proximity activation in this mode.
- Remember identity, position, activation state, and consumption across relevant
  scene unloads/revisits. Session memory is enough initially; permanent save/load
  is separate future scope.
- Keep exactly one owner of the usable preparation when storing, restoring, or
  representing it in a scene. Reloading must not duplicate an unused bottle or
  resurrect a consumed one.
- Define activation input, range, eligible recipients, and collision-safe placement
  before implementation. They are not provided by the existing proximity trigger.

The present armed, short-lived contact bottle remains current behavior until a
separately tested placement change is implemented.

## Liquid, Gel, and Solid Forms

Liquid potions already support drinking, throwing, and planned strategic
placement. The vision does not require release timing to produce jelly, solid
pellets, or delivery-locked potion forms. Those forms may be explored only when
they provide a distinct interaction worth their extra rules and art cost.

Likewise, optional alternative recipe endpoints must be designed as meaningful
discoveries, not accidental punishment for missing a perfect release. The first
test should use one known result per recipe.

## Suggested Validation Sequence

These are bounded validation stages. Stage 1 now has automated coverage but
still needs repeated manual playtesting:

1. Playtest the implemented small-flask reaction in active combat: hold,
   release, visible momentum, successful settle, early continuation, and
   recoverable overreaction.
2. Compare repeated use with instant mixing and a continuous-balancing variant.
   Observe whether anticipation remains enjoyable after the recipe is familiar.
3. Test movement and combat readability with the same flask interaction. Check
   keyboard reach, cue visibility, short interruptions, and repeated preparation.
4. Add one larger-vessel multi-stage recipe only after the short interaction
   works; prove apparatus progression without building an inventory or refuge UI.
5. Separately prove dormant placement, deliberate activation, and revisit
   persistence, then connect those capabilities to a transformation example.

Success means players can predict why a reaction worked or failed, keep track of
the world while brewing, deliberately use a finished potion in different ways,
and find equipment/recipe discoveries useful. Reject hidden momentum, arbitrary
outcomes, forced ingredient loss, repetitive long holds, and complexity that
requires a combat log to understand.
