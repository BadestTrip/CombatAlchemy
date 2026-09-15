# CombatAlchemy Style and Vision

> Status: Living creative reference
> Working title: CombatAlchemy
> Vision version: 0.5
> Last updated: 2026-09-15
> Technical companion: [Project Architecture](./PROJECT_ARCHITECTURE.md)
> Visual companion: [Art Reference Index](./ART_REFERENCE_INDEX.md)
> Approved presentation plan: [Pixel-Art Conversion Plan](./plannings/plans/2026-09-12-pixel-art-conversion.md)
> Approved brewing direction: [Brewing, Vessels, and Strategic Placement](./plannings/specs/2026-09-15-potion-brewing-vision-design.md)

## Purpose

This document is the creative source of truth for CombatAlchemy. Use it when:

- deciding whether a feature belongs on the roadmap;
- briefing developers, artists, writers, composers, or collaborators;
- reviewing whether an asset belongs in the same game;
- generating concept art, gameplay assets, UI studies, or visual effects;
- resolving ambiguity about tone, visual language, or player experience.

`PROJECT_ARCHITECTURE.md` remains the source of truth for what the project
currently implements and how its code is organized. This document defines what
the project should feel like and what it should grow toward. When the two differ,
describe the difference as current prototype versus intended vision. Do not
silently present an unbuilt feature as current behavior.

### Current Decision

The concept stays the same; the production medium changes to **full 2D pixel
art**. Compact full-body sprite sheets replace the planned cutout-art pipeline.
The permanent project canvas is **1920 x 1080**, with nearest texture sampling,
an almost-monochrome world, and selective reagent and potion color. Gameplay
composition, character-cell size, flask size, and world pixel scale remain
intentionally undecided under the hybrid-detail approach.

This is an approved direction under staged implementation. The active main menu
now uses a native `1920 x 1080` animated pixel-art laboratory with scene-authored
text and inline settings. Combat still uses the compact skeletal PlayerModel and
geometric assets. The four researcher facings and `640 x 360` main-menu sample in the
[pixel-art approval pack](./pixel_art_samples/README.md) were explicitly approved
on 2026-09-12. The menu sample is now composition reference only, not a runtime
resolution or final asset. Gameplay composition is intentionally undecided and
has no retained approval sample. Historical art approvals remain separate from
approval of the new pixel treatment.

## North Star

> A melancholic pixel-art dark-fantasy game about a forbidden occult researcher
> who enters dangerous expeditions, experiments with reagents under pressure,
> and returns carrying knowledge that may be more valuable than survival.

### Player Fantasy

The player is not a conventional wizard and does not cast a list of spells.
They are a field researcher who handles unstable substances, notices patterns,
forms hypotheses, and tests those hypotheses while danger continues around
them. Their advantage is not superior strength. It is the ability to understand
what others fear, then turn that understanding into a physical reaction.

The desired fantasy is:

- **I observe:** the environment, enemies, and ingredients reveal usable clues.
- **I hypothesize:** colors, properties, and prior discoveries suggest a mixture.
- **I commit:** mixing happens in real time and creates risk.
- **I apply:** the same potion can be drunk, thrown, or placed; future world
  interactions depend on its properties and the receiving object's capabilities.
- **I learn:** success and failure both produce knowledge that can guide the next
  expedition.
- **I return changed:** the refuge is familiar, but discoveries and consequences
  alter its meaning.

### Experience Promise

CombatAlchemy should make the player feel careful, curious, pressured, and
slightly transgressive. A good session creates at least one moment of deduction:
the player notices something, tries a mixture, sees a clear reaction, and now
understands the world better than they did before.

The game should not make the player feel like they are merely selecting attacks
from a reskinned ability bar. The flask is a small laboratory carried into a
dangerous place.

## Design Hierarchy

When priorities conflict, use this order:

1. **Discovery through mixing**
2. **Real-time combat application**
3. **Consequences of forbidden knowledge**

Discovery is the identity of the game. Combat gives discovery urgency and a
place to prove its value. Consequences give discoveries emotional weight. A
feature that adds combat breadth but weakens experimentation should not outrank
a smaller feature that makes observation and mixing more meaningful.

## Project Goals and Scope

CombatAlchemy uses the scope layers below. Planning must identify which layer a
feature belongs to and must not describe approved direction as current behavior.

### Product Goals

1. **Make potion discovery the central skill.** Observation, mixing, testing,
   and interpretation should create more progress than choosing predefined
   attacks.
2. **Apply reactions consistently.** Potion effects should interact through
   focused capabilities so the same preparation can affect actors, props, or
   environmental conditions when they support that reaction.
3. **Create readable real-time combat.** Movement, enemy intent, mixing risk,
   targeting, impact, and recovery must remain legible without a combat log.
4. **Build layered reactive enemy AI.** The first enemies should notice,
   pursue, telegraph, attack, recover, and react to potion effects. Later enemy
   families may gain different perception, hazard awareness, group behavior,
   and material-specific reactions.
5. **Make reagents part of field decisions.** Reagents should eventually be
   observed, collected, carried in limited quantities, and spent under pressure
   rather than acting as unlimited ability charges.
6. **Complete the expedition and refuge loop.** One authored expedition should
   support observation, collection, danger, withdrawal or success, return, and
   preparation for another attempt.
7. **Use knowledge as progression.** Recorded reactions, reliable recipes,
   unresolved hypotheses, and consequences should unlock decisions before
   conventional statistic growth. A recipe may be understood before the player
   owns a vessel large enough to brew it; suitable apparatus expands possibilities.
8. **Deliver one cohesive, affordable presentation.** Compact pixel sprites,
   reusable terrain, few animation frames, restrained audio, and a consistent
   interface should support one readable vertical slice before content expands.
   Production must be achievable without detailed per-character skeletal skins.

### Scope Layers

| Layer | Included goals |
| --- | --- |
| **Current foundation** | Player movement and collision, compact directional model workshop, three-layer small-flask brewing with hold/release/settle timing and recoverable overreaction, capability-based potion effects, one produced potion instance represented by the same physical entity while held, thrown, placed, or drunk, health-bearing test actors, pause, settings, music, scene transitions, and main-menu routing. |
| **Approved presentation conversion** | Keep the native 1920 x 1080 project canvas; use the implemented animated Field Notes main menu as the first delivered screen; decide gameplay composition and asset dimensions before replacing PlayerModel or combat visuals; retain gameplay, sockets, controls, and physical-potion ownership. No new gameplay systems. |
| **Approved brewing expansion, not implemented** | Meaningful multi-stage laboratory recipes in larger vessels; apparatus progression; the same finished potion usable through deliberate later activation and future storage. The small one-stage combat flask is implemented and should be playtested before this expansion. |
| **Next playable proof** | One real enemy with readable reactive combat AI; reagent pickup and limited runtime carrying; potion reactions on selected world objects; health pressure; victory, defeat, and encounter reset; stronger flask, action, impact, and target feedback. |
| **Long-term game** | Refuge, larger brewing apparatus, and discovery record; authored expeditions; prepared-potion storage and strategic placements remembered across revisits; transformation and other capability-based effects; expanded enemy perception, hazard awareness, group behavior, and alchemical reactions; environmental experimentation; knowledge progression; concrete consequences; and a cohesive vertical slice. |

The next playable proof does not require persistent simulation, broad systemic
world AI, several enemy factions, a large inventory, or multiple expeditions.
Those additions must wait until one enemy, one encounter loop, and one world
reaction are readable and worth repeating.

Presentation conversion and brewing remain separate workstreams. The integrated
small-flask reaction can be tuned before final gameplay composition is decided.
Reactive AI, reagent collection, environmental
interactions, and the expedition loop remain goals, not hidden additions to the
art conversion. Future potion storage is still intended: the current one-held-slot
boundary is an MVP limit, not a permanent ban on carrying several prepared potions.

## Design Pillars

### Knowledge Is Progression

The most important thing the player brings home is understanding. New recipes,
ingredient properties, enemy reactions, environmental observations, and reliable
theories should matter more than linear stat increases.

Progression should favor new decisions over larger numbers. Better progression
widens what the player can attempt, interpret, combine, or risk.

Larger brewing vessels should unlock otherwise impractical recipes, not make
small flasks obsolete. Discovering a formula before acquiring its apparatus
gives the researcher a concrete goal while preserving the value of knowledge.

### Alchemy Happens Under Pressure

Mixing remains part of the real-time world. The player must choose when it is
safe to open the flask, add layers, finish a potion, drink it, throw it, or place
it. The interface must be quick enough to use in danger but physical enough to feel like
mixing rather than hotbar selection.

Pressure should come from the world and encounter, not from intentionally
awkward controls.

The approved brewing interaction is **agitate, anticipate, release, settle**.
Small combat recipes use a short reaction; complex laboratory recipes use
several meaningful stages. The same control language should build mastery
without turning safe-house preparation into a longer repetitive hold.

### Reactions Are Legible

Every important alchemical action needs a readable cause and effect. Ingredient
color, liquid layering, mixing motion, projectile color, impact shape, target
response, and sound should agree.

Mystery belongs in discovering what a reaction means. Confusion should not come
from weak feedback or inconsistent visual rules.

### Restraint Gives Mystery Weight

The game should leave room for silence, empty space, weather, and incomplete
knowledge. Not every surface needs ornament. Not every discovery needs a loud
celebration. Not every threat needs a lore explanation when it first appears.

Bright color, dense particles, large text, and forceful camera effects are most
effective when they are rare.

### Forbidden Knowledge Leaves Traces

Research should eventually affect more than a recipe list. The refuge, the
researcher, other people, and expedition sites can reflect what has been studied
or used. Consequences should be concrete and specific rather than represented by
a generic morality meter.

This is a future-facing pillar, not a requirement of the current prototype.

## Intended Experience Loop

The long-term loop is an expedition cycle:

1. **Refuge and research:** review recorded discoveries, unresolved observations,
   and available leads; use available apparatus to prepare more complex potions.
2. **Choose an expedition:** enter one dangerous location with a clear practical
   or research purpose.
3. **Observe:** read material clues, creature behavior, color, residue, weather,
   and environmental reactions.
4. **Collect and test:** obtain reagents and form mixtures from known rules or new
   hypotheses.
5. **Apply under pressure:** drink, throw, place, or use a preparation on an
   object or environmental condition that supports its reaction. A deliberately
   placed preparation can become part of a planned retreat and later activation.
6. **Survive or withdraw:** decide what risk is justified by possible knowledge.
7. **Return and record:** convert observations into reliable discoveries,
   unresolved notes, or consequences.

The cycle should support short-term tactical decisions and long-term intellectual
progress without requiring permanent save or meta-progression systems in the
early MVP.

## Current Prototype and Future Vision

The distinction in this table is mandatory in planning and communication.

| Area | Current prototype | Intended direction |
| --- | --- | --- |
| Entry flow | Main Menu opens a potion combat sandbox | Main Menu leads to a refuge and expedition cycle |
| Player | Movable 15-bone geometric-placeholder `PlayerModel`, following camera, four positive-scale facings, and hand sockets used by the held potion | Compact full-body pixel frames with the same motion/facing/socket API; broad hat, obscured face, and practical equipment; exact dimensions follow gameplay-composition approval |
| Encounters | Stationary Friend and Foe test targets with no AI | The first enemy uses readable notice, pursuit, telegraph, attack, recovery, and potion-reaction states; later families add perception, hazard, and group differences |
| Mixing | Three RGB layers and two count-based recipes; hold Space to agitate, release to settle, resume an early reaction, or recover an overreaction | Tune the implemented short field reaction, then add staged laboratory brewing only after it remains readable under combat pressure |
| Vessels | One mixer limited to three ingredient units | Small, larger, and eventually advanced brewing apparatus gates capacity and recipe complexity; sizes and yields are not fixed |
| Application | Create one physical potion, then drink it, throw it, place it on the ground, or discard it | Preserve one recipe's meaning across all uses, including transformation and future storage |
| Placement | A proximity bottle arms after 0.35 seconds and expires after 20 seconds; scene changes do not preserve it | Dormant placement, deliberate activation on return, and session-level persistence across relevant revisits; optional trigger types later |
| Reagents | Unlimited red, green, and blue input swatches | Observable and collectible reagent families with limited field availability |
| World reactions | Collision code and test fixtures consume potions on walls without a health capability; the active sandbox is not a complete expedition environment | Selected props and environmental conditions expose focused capabilities for useful alchemical reactions |
| Animation | Skeletal idle/walk in four authored facings; no mirroring or action clips; the held potion follows its animated hand socket | Two idle and four walk frames per facing, discrete playback, phase-preserving turns, and per-frame hand markers; potion use remains immediate |
| Rendering | Permanent 1920 x 1080 project canvas; animated native-resolution pixel-art main menu; mixed geometric combat presentation and close following camera | Keep the project canvas and nearest sampling; determine gameplay camera, world pixel scale, and asset dimensions only after approving gameplay composition |
| Progression | None | Knowledge and recorded discoveries lead; a learned recipe can precede access to its required vessel; statistics remain secondary |
| Expedition | Not implemented | Authored locations support observation, collection, risk, and return |
| Consequences | Not implemented | Research and use leave specific marks on people, places, or the researcher |

Current implementation details may change. The player fantasy and design
hierarchy should remain stable unless this document is deliberately revised.

## Explicit Non-Goals

CombatAlchemy is not:

- a return to runes, chants, or a grammar-based spellcasting system;
- a conventional wizard game with elemental spells on a hotbar;
- a round-based combat game;
- a deck-builder or card-combat game;
- a co-op party-minigame or incremental workbench pivot;
- a conventional skill-tree power climb;
- bright, whimsical, cozy potion-shop fantasy;
- explicit body horror or gore-first dark fantasy;
- a constant stream of combat logs, recipe names, tutorials, or floating text;
- a glossy mobile-fantasy interface covered in panels and currencies;
- a direct recreation of one real historical culture;
- a system where ambiguity is created by unreadable feedback;
- a mandatory perfect-timing grind that gives a known recipe arbitrary potency;
- a liquid/gel/solid taxonomy that needlessly restricts drinking, throwing, or placement;
- a reason to build broad support systems before the discovery loop needs them.

These exclusions are boundaries, not a checklist of old systems to reference in
future content.

## World Vision

### Setting

The world is an invented syncretic dark-fantasy setting. Its architecture and
objects can combine mountain laboratories, old observatories, remote shrines,
medicinal terraces, fortified roads, decaying archives, and practical medieval
craft. The result should feel internally coherent, not like a collage of visibly
separate real-world cultures.

Historical ink and charcoal references inform value grouping and atmosphere,
not the new pixel-production medium or permission to copy sacred symbols,
historical clothing, or culturally specific calligraphy without research.
Alchemy is expressed through vessels, stains, measurements, natural processes,
and abstract geometry rather than borrowed religious iconography.

### Emotional Register

The dominant mood is **melancholic mystery**:

- loneliness without total hopelessness;
- danger without constant spectacle;
- wonder that feels earned through attention;
- old places whose original purpose is only partly understood;
- quiet shelter in the refuge against cold or exposed expedition spaces;
- unease from implication, residue, and transformation rather than explicit gore.

Humor may exist through human behavior or dry observation, but modern jokes and
self-aware genre parody break the tone.

### Recurring Places

Use these as environment families, not mandatory proper nouns:

- mountain laboratories built into cliffs or abandoned fortifications;
- ruined observatories where instruments point toward impossible phenomena;
- medicinal gardens grown wild around broken irrigation systems;
- wind-cut roads with shrines, waystations, and evidence of failed journeys;
- flooded or fire-damaged archives containing partial records;
- mines, kilns, glassworks, and dye houses where material processes shaped life;
- a compact refuge where paper, glass, heat, and collected specimens accumulate.

### Materials

The material language should remain tactile:

- textured paper and stitched folios;
- smoked, uneven, or repaired glass;
- oxidized copper and stained brass;
- blackened iron and hand-forged tools;
- charred wood and worn stone;
- layered cloth, leather ties, wax, cork, twine, and ceramic;
- residue such as soot, mineral bloom, condensation, sediment, mold, and dye.

Represent these materials through a few deliberate pixel clusters and value
steps. Material names do not authorize colored metal, paper-grain overlays, or
fine surface noise across the almost-monochrome world.

Avoid pristine fantasy props. Objects should show handling, repair, local craft,
and exposure to their environment.

### Recurring Motifs

- vessels, droplets, stains, sediment, and separated liquid layers;
- roots, capillaries, river branches, and cracked glaze;
- eclipses, concentric rings, orbital diagrams, and measurement marks;
- smoke moving against the wind;
- windows or doorways framing distant unknown places;
- a small pale light surrounded by a larger field of dark emptiness;
- three-color marks used sparingly to communicate alchemical information.

Abstract alchemical geometry may use rings, ratios, and diagrams. It must not
become an alphabetic magical language or generic glowing glyph decoration.

## Visual Direction

### Production Format

- Final presentation is **pure 2D pixel art**, not painted images with a pixel
  filter and not live skeletal artwork rendered at low resolution.
- Gameplay uses a fixed **top-down three-quarter** view with eight-direction
  movement and four authored visual facings. It is not an isometric-grid game.
- The permanent project canvas is **1920 x 1080**. Author full-screen menu art at
  that exact size and use responsive anchors for smaller 16:9 or wider windows.
- Use nearest texture sampling and integer placement for pixel-art assets. Do
  not add a low-resolution SubViewport solely to force a universal pixel size.
- Character cells, full sheet dimensions, gameplay camera scale, terrain grid,
  and flask dimensions are not fixed until gameplay composition is approved.
  Keep the researcher compact and slightly taller than wide as a proportional
  direction, not a pixel-count contract.
- Backgrounds, actors, props, UI, menus, and effects use the same pixel density,
  lighting, and palette rules. The workshop is part of the presentation pass.
- Generated concepts are source material until approved and cleaned to a native
  grid. Review at 1x and integer enlargement; apparent pixels in a large AI image
  are not evidence of a usable sprite grid.

### Rendering Language

Translate the old ink/charcoal mood into **deliberate pixel clusters**:

- broad grayscale masses before interior detail;
- crisp stepped edges and stable outlines;
- small, purposeful highlights for glass, tools, and visible contact points;
- a few readable cloth, stone, and residue clusters instead of noisy texture;
- selective dithering only where it clarifies a material or transition;
- deliberate negative space around actors, potion paths, and the flask;
- saturated color concentrated in liquid, reagent controls, and reactions.

No anti-aliased sprite edges, painterly smears, soft gradients, smooth rotation of
pixel sprites, subpixel UI scaling, or full-screen texture grain. Avoid detail
that flickers during movement. Export clean transparent backgrounds; inspect
alpha edges against light and dark backgrounds.

### Composition

- Establish one clear focal hierarchy per image or gameplay view.
- Keep traversable ground readable before adding atmospheric marks.
- Separate actors from the ground by value, edge, or restrained rim light.
- Use simple foreground pixel masses to frame a view, not cover interaction space.
- Preserve calm regions so saturated reactions have visual authority.
- Avoid evenly distributing props, particles, or contrast across the frame.
- In gameplay backgrounds, keep the center and expected movement routes quieter
  than the perimeter.

### Camera and Perspective

For gameplay assets:

- use a consistent elevated three-quarter illustration angle, with visible heads,
  upper body planes, feet, and ground contacts;
- avoid wide-angle distortion and dramatic horizon lines;
- keep verticals consistent across actors, props, and environment pieces;
- use upper-left as the default key-light direction;
- keep contact points and feet visible;
- keep all frames within their fixed cells with a stable ground pivot;
- author each direction rather than flipping a lit sprite and its anatomical hands;
- do not bake large shadows into sprites that need independent placement.

The approved implementation maps **3 world units to 1 source pixel** and uses a
**1/3 camera zoom**, retaining existing movement and collision coordinates. Snap
rendered camera motion to the art grid; do not quantize gameplay physics or mouse
aim. These settings are planned, not current project settings.

### Canonical Palette

Ordinary characters, terrain, architecture, menus, and equipment use **eight
neutral grayscale values**. This is the initial working ramp for the approval
samples; freeze any approved adjustment before full asset production.

| Role | Color | Hex | Usage |
| --- | --- | --- | --- |
| Ink | Near black | `#101010` | outlines and deepest negative space |
| Charcoal | Dark gray | `#282828` | coat and major shadow masses |
| Slate | Low mid-gray | `#404040` | terrain separation and secondary forms |
| Stone | Mid-gray | `#606060` | ordinary material planes |
| Ash | High mid-gray | `#888888` | readable raised planes and quiet UI |
| Mist | Light gray | `#B0B0B0` | distant silhouettes and separation |
| Paper | Pale gray | `#D8D8D8` | text, faces hidden in shade, pale materials |
| Glass | Near white | `#F0F0F0` | sparse glass highlights and focal edges |

#### System Reagent Colors

Color is an information channel, not a costume or biome theme. Preserve the
existing recipe/reagent colors during conversion:

| Family | Active color | Hex |
| --- | --- | --- |
| Red | Charged warm red | `#FF2E50` |
| Green | Charged botanical green | `#9CFF38` |
| Blue | Charged mineral blue | `#29D9FF` |
| Prepared health | Charged magenta | `#FF3BD4` |
| Prepared damage | Charged teal | `#20F5D0` |

The exact source is `shared/alchemy/ChargedNeonPalette.tres`.
`PotionReagent.gd`, recipe resources, menu deposits, and reusable alchemical VFX
must consume those values rather than defining near-duplicates. Use color inside
liquid, labeled reagent controls, reaction cores, or a small clue with real
alchemical meaning. Ordinary lamps, plants, metal, menu focus, and costumes stay
grayscale. Do not reuse reagent red and green as the only way to distinguish
Friend/Foe or health status.

### Lighting

- Use a consistent upper-left key, expressed through stepped values rather than
  gradients or painted rim light.
- Suggest exposed cold and refuge warmth through composition, value, sound, and
  context; do not tint the grayscale foundation blue or amber.
- Keep practical light pools small and grayscale. Potion reactions may add brief
  localized color, never a full-screen wash.
- Any glow uses restrained pixel clusters or stepped frames. Alchemical crystal
  particles may add a localized 6-8 pixel additive aura, but never global bloom
  or a full-screen color wash.
- Reserve the lightest value for glass, readable text, and selected focal edges.

## Subject Rules

### The Researcher

The researcher should read as a practical occult scholar before reading as a
warrior:

- a strong asymmetrical silhouette;
- a compact weathered coat, apron, or traveling mantle with a readable hem;
- a broad hat, hood, or raised collar that partially obscures the face;
- a few readable equipment clusters suggesting glassware, a satchel, and gloves;
- a visible hand marker for the separate held potion, with no bottle baked into
  the character frames;
- restrained ornament based on measurements, stitching, stains, and repairs;
- a posture that suggests attention and caution rather than heroic confidence.

Avoid staffs, glowing hands, ornate armor, oversized weapons, and generic wizard
stars. The researcher manipulates substances and apparatus, not free-floating
magic.

At gameplay scale, the hat or shoulder line, coat hem, and flask arm should form
the three fastest recognition points.

Readability at the approved gameplay scale takes precedence over copying every
strap and vessel in G06. Approve front, back, side-left, and side-right
silhouettes before filling frames. The first sheet contains only idle and
walking; action poses are future scope.

### Allies and Other People

- Give each person a practical relationship to their location through clothing,
  tools, wear, and posture.
- Keep silhouettes simpler and less occult than the researcher unless the story
  specifically requires otherwise.
- Use open posture, intact materials, shape, and concise labels to distinguish
  allies without making them visually pristine.
- Avoid color-coding morality. Clothing color may support readability but should
  not replace behavior and context.

### Enemies and Creatures

Enemies should look affected by a process, environment, or material condition,
not decorated with random fantasy spikes.

Useful transformation families include:

- mineral growth, salt crust, glassing, or crystallization;
- ink leaching, staining, soaking, or erased features;
- root intrusion, fungal bloom, or medicinal overgrowth;
- smoke accumulation, kiln damage, oxidation, or chemical burns without gore;
- repeated anatomy or motion caused by a failed experiment.

Every enemy needs:

- one readable silhouette at gameplay scale;
- one dominant material condition;
- one behavior communicated by pose or motion;
- a restrained alchemical clue that can become meaningful through observation;
- clear separation between body, attack, and reaction effect.

Friend and Foe remain static test sprites in the conversion. These enemy-family
rules guide later AI and content work; they do not authorize extra enemy sheets
or combat behaviors in the initial art pass.

### Environments

- Design ground planes for movement and targeting before adding scenic detail.
- Use clustered residue, roots, cracks, value, and object placement to imply routes.
- Put the highest detail around discoveries, hazards, and landmarks.
- Simplify distant scenery through fewer value steps and sparse pixels, not blur.
- Use color clues as local evidence. A red mineral vein or blue condensation mark
  should be intentional, not ambient decoration.
- Keep each expedition visually identifiable through material and weather, not a
  full-screen color filter.

Begin with a small reusable terrain/prop set for the current sandbox. Decorative
art must not silently add collisions or change the room's mechanical layout.
Expedition concepts may explore future places; they are not current level scope.

### Props and Reagents

- Reagent containers should be identifiable by silhouette as well as color.
- Glass is uneven, repaired, stoppered, wrapped, measured, and visibly used.
- Labels should use marks, bands, shapes, or material samples when text is not
  meant to be read.
- Tools should show a plausible function: grinding, heating, filtering, measuring,
  collecting, sealing, or recording.
- Avoid identical generic bottles recolored into a complete asset set.

The current health/damage potions may share one bottle with a tinted liquid
region. Distinct future ingredient shapes are a readability tool, not a demand
for a unique animated asset per recipe.

## Interface Direction

### Combat Interface

The flask is the primary combat interface and should remain the visual center of
mixing.

- Keep it at the bottom center of the screen.
- Size the flask from the eventual gameplay composition, with reagent swatches
  to its right and enough margin for required window sizes. No production pixel
  dimensions are approved yet.
- Show unfinished reagents as clearly separated liquid layers from bottom upward.
- Show the prepared result as one unified liquid.
- For current reaction brewing, keep a readable release window, liquid momentum,
  and settling feedback inside the flask. Do not add permanent numeric progress
  and energy meters or rely solely on a color change.
- Keep reagent controls adjacent to the flask and identify them with both color
  and a simple label or shape.
- Preserve the authored glass outline at every state.
- Keep failures physical: a short pixel-step shake, stepped liquid displacement,
  or outline flash. Preserve the mixture; do not scale the pixels or add a log.
- Hide the mixer when it is irrelevant so the world remains dominant.
- Keep world-space health feedback compact and readable.
- Give swatches engine-rendered R/G/B labels. Use grayscale health bars with
  readable fill changes and shape/value feedback; color alone must not carry state.

Do not add combat logs, recipe cards, permanent ability bars, decorative nested
panels, or large tutorial paragraphs to the main combat view.

### Menus and Records

- Menus use grayscale pixel backgrounds, crisp controls, and value/shape focus.
  The active main menu establishes the native `1920 x 1080` Field Notes layout:
  dark left-side notes space, animated laboratory/window, and focused RGB vessels.
- Main-menu controls are scene-authored text with a left focus rule. Inline Music
  and SFX settings use ten stepped segments. Pause settings intentionally retain
  their existing slider presentation until a separate restyle.
- Preserve keyboard focus, settings persistence, music, routing, and transition
  input locking while presentation changes.
- The ink reveal remains conceptually aligned; its future rendering must use
  pixel-grid steps while preserving timing, input blocking, and completion.
- Keep the alchemy seal abstract and low contrast. Use pixel geometry or frames,
  not smooth arbitrary rotation that changes pixel sizes.
- An eventual research record should feel handled and accumulated, not like a
  modern database dashboard.
- Information still needs strong hierarchy, predictable navigation, and readable
  contrast. Diegetic styling is not an excuse for poor usability.
- Use symbols for familiar controls and concise text for commands.
- Do not generate final interface text inside images. Build final text in Godot.

The earlier diegetic journal/candle menu proposal is not the next implementation
scope. This conversion restyles existing interactions; additional menu mechanics
require a separate decision.

### Typography

The current `yoster.ttf` is a starting candidate, not an automatic approval.
Choose a small pixel-compatible font set verified at the native canvas size:

- readable title, command, and quantity text before decorative styling;
- integer positions and sizes with no filtering that blurs the pixel grid;
- normal letter spacing and stable dimensions;
- short labels in combat;
- sentence case for most interface text.

Avoid faux calligraphy, distressed fonts at small sizes, fractional scaling, and
large all-caps paragraphs. Do not add a new font dependency just for variety.

## Potion and Effect Direction

### RGB as Mechanical Grammar

Red, green, and blue are the prototype's base reagent families. They are a
readability contract, not necessarily final in-world ingredient names.

Future ingredients may be named substances with origin, texture, rarity, and
secondary properties. Their family color must remain identifiable during rapid
mixing. A player should be able to learn deeper fiction without losing the
clarity of the original three-color grammar.

### Brewing Interaction and Vessel Progression

**Implemented small-flask foundation:** hold Space to agitate, anticipate the
reaction, release to stop adding energy immediately, and let the liquid settle.
Residual energy briefly advances the reaction after release. The current
geometric flask shows current progress, predicted settled progress, and a broad
success bracket. This momentum must remain visible and predictable as the
placeholders are replaced.

The current flask communicates developing, ready-to-stabilize, overreacting,
and finished mixtures through geometric liquid motion, grains, markers, and
foam. Sound and final art remain future presentation work. An early release
leaves a mixture that can resume; initial overreaction costs recovery time
rather than destroying ingredients. Final success creates one dependable
potion result, not a different potency for every small timing variation.

| Context | Intended brewing experience |
| --- | --- |
| Small combat flask | Few ingredient units and one short reaction while movement and the world continue. Roughly 1-3 seconds is an experiment, not fixed tuning. |
| Larger safe-house vessel | Several meaningful additions and reaction stages using the same controls; difficulty comes from stage behavior and preparation, not a slower progress bar. |

Capacity counts repeated **ingredient units**, not distinct colors. Red, red,
blue occupies three units. Example capacities of 3, 5, and 8 are illustrative;
working headroom, exact tiers, and yields need testing. Learning a powerful
formula before owning its required apparatus is intended progression. Small
flasks retain speed and economy after larger equipment becomes available.

Brewing equipment and the portable finished bottle are separate concepts. A
large-vessel reaction may later yield a portable concentrated dose or batch;
neither multiple doses nor storage is implemented. Developing laboratory stages
are unfinished mixtures, not usable potions. The physical bottle states held,
flying, placed, and consumed begin after successful preparation.

### One Preparation, Several Uses

A finished formula determines the effect; delivery determines how it reaches
an eligible subject. A transformation potion could turn the drinker, a struck
entity, or a recipient at a deliberately activated placement into a strong
mutant. An enemy can be strengthened by receiving it. Do not switch the effect
according to Friend/Foe labels or require a gel or solid form for placement.

For example, a large-vessel transformation recipe could extract an active
compound, bind a more energetic transformation agent, and then stabilize the
formula. Only the final successful stage creates the finished preparation.
Its exact formula, power, duration, visual transformation, and any area footprint
remain future decisions. Subjects must expose the relevant capability; empty
ground does not become an actor simply because liquid touches it.

### Strategic Placement and Return

The intended first strategic placement is dormant and deliberately activated
when the player returns. Leaving a transformation dose near a passage, exploring
beyond it, and retreating to activate it should reward preparation and timing.
Recipients and any effect area must be defined explicitly; proximity traps and
remote triggers are optional later extensions.

This needs stable unused preparations and session memory across relevant
revisits, not just a longer expiry timer. A placed or stored potion does not keep
brewing by default. Current 20-second proximity bottles do not yet satisfy this
vision, and permanent save/load remains separate scope.

The [approved brewing design](./plannings/specs/2026-09-15-potion-brewing-vision-design.md)
records release examples, brewing states, the staged transformation example,
ownership constraints, and bounded validation steps. Small-flask timing is
currently editable in `SmallFlaskBrewingProfile.tres` and requires playtesting.
Larger capacity, multi-stage behavior, activation controls, and broader recipe
balance remain unimplemented.

### Reaction Sequence

Every potion effect should communicate three beats:

1. **Anticipation:** liquid state, hand pose, projectile shape, or a brief sound
   establishes what is about to happen.
2. **Contact:** glass, liquid, or vapor reaches the target with a clear point of
   impact.
3. **Consequence:** the target and health state respond with a distinct motion,
   value shift, color behavior, and sound.

These are feedback beats, not new gameplay delays. Drink, throw, and place stay
immediate in the approved conversion; no timing event is added before the effect.
Planned brewing time happens before a usable potion exists. Later deliberate
activation is a placement rule, not an animation delay on drinking or throwing.

### Visual Vocabulary

- Use a few pixel droplets, compact splashes, stepped vapor, sediment, and glass
  highlights. Reuse small frames and tinted liquid rather than bespoke large
  effect sheets for every future recipe.
- Keep the reaction core saturated and the outer effect desaturated or
  transparent.
- Match effect direction to function: restorative reactions gather, settle, or
  rise; destructive reactions cut outward, stain, erode, or rupture.
- Preserve target readability through the effect.
- Keep lingering residue only when it communicates an ongoing state.
- Use sparse, grid-consistent particles as support, not as the whole effect.
- The bottle remains grayscale with colored liquid. Visual travel orientation
  can be discrete while its world trajectory and targeting remain continuous.
- `vfx/reactive_crystal/PotionShatterParticles.tscn` defines the current
  one-shot travel-impact particle language: 24-32 grains, 5-7 bright fragments,
  slight gravity, and only the prepared potion color. It remains an isolated
  workshop asset until potion-impact integration is approved.

For the current recipes:

- **Health Potion, red + red + blue:** a restrained violet or magenta mixture;
  rounded gathering motion, upward suspension, and a return of value; heals 30.
- **Damage Potion, green + green + blue:** a teal mixture; a sharper outward
  splash, corrosive edge, and brief value loss; damages 30.

Recipe behavior is determined by the mixture, not by whether the target is called
Friend or Foe.

### Animation

**Current:** the compact 15-bone `PlayerModel` uses authored idle/walk facings at
positive scale. The physical held flask follows the animated right-hand socket.
There are no drink/throw/hit clips or animation-delayed potion effects.

**Intended replacement:** one full-body sprite sheet, not a new body-part atlas.
The earlier approval sheet remains a proportion/facing reference; its exact cell
and sheet sizes are no longer production requirements.

| Item | Production rule |
| --- | --- |
| Sheet | Four facing rows with a deliberately small frame budget; dimensions follow gameplay-composition approval |
| Facings | Front, back, side-left, side-right; no horizontal mirroring |
| Idle | Two frames per facing, 1.6-second loop, subtle silhouette changes |
| Walk | Four frames per facing, 0.72-second loop, alternating contact and passing poses |
| Turns | Retain gait phase, 0.10 directional hysteresis, last facing while idle |
| Playback | Discrete frame selection with stable ground pivot; no image crossfades |
| Hand alignment | Per-frame left/right marker positions; the held bottle remains a separate entity |
| Actions | No new action clips or delays in this conversion |

Keep the model's public motion, facing, speed, reset, socket, and signal contract
so gameplay does not depend on whether its internals are bones or sprite frames.
The workshop will show frame bounds/socket guides instead of bones. Keep a
compatibility wrapper for the current debug method during the migration.

Sparse frames reduce drawing cost, but bad contacts, shifting feet, and inconsistent
anatomy are not acceptable tradeoffs. Review the complete loop at native size.
Any later drink/throw animation must be separately designed and tested; do not
restore the removed action-timing system merely to match a concept pose.

## Audio Direction

### Music

Music should be sparse enough to leave room for weather, footsteps, glass, and
silence. The palette may include low strings, breathy woodwinds, struck metal,
frame-like percussion, glass harmonics, drones, and restrained acoustic texture.

- Refuge music is warmer, closer, and more repetitive in a reassuring way.
- Expedition music is thinner, more exposed, and willing to recede.
- Combat adds pulse and tension without becoming continuous orchestral bombast.
- Discovery moments may introduce one clear tonal change rather than a triumphant
  fanfare.

Avoid direct imitation of one living musical tradition unless the production has
the knowledge and collaborators to use it intentionally.

### Sound Effects

Prioritize tactile, layered sounds:

- cork, leather, glass taps, liquid weight, bubbles, grinding, and paper;
- distinct reagent addition sounds with a shared family structure;
- a clear successful-mix resolve and a materially different rejected mix;
- for brewing presentation, add a readable agitation build, release cue, short settling
  tail, and recoverable-overreaction sound without constant alarms;
- readable drink, throw, miss, impact, heal, and damage sounds;
- weather and location ambience that can fall nearly silent.

Sound should confirm mechanical state even when the player is looking elsewhere.

## Writing Direction

The voice is **clinical-poetic**: precise observation interrupted by restrained
wonder or unease.

### Principles

- Prefer concrete material details over abstract lore claims.
- Let uncertainty remain visible in notes and hypotheses.
- Keep interface commands direct.
- Keep research notes concise enough to scan.
- Use metaphor sparingly and tie it to physical observation.
- Avoid generic epic prophecy, modern jokes, excessive proper nouns, and lore
  paragraphs that arrive before the player has a reason to care.

### Example Register

- Functional: `Mixture incomplete.`
- Observation: `The blue sediment rises when the bell stops.`
- Hypothesis: `Heat may not be the catalyst. Fear may be.`
- Consequence: `The specimen recovered. The garden did not.`

These lines define tone, not mandatory game text.

### Naming Patterns

- Reagents: material or source plus a physical condition, such as ash, salt,
  bloom, resin, milk, rust, or distillate.
- Places: a practical site plus a remembered condition, such as a drowned
  archive, ashen pass, silent glassworks, or wind-cut garden.
- Creatures: observed behavior or material state before mythic title.
- Recipes: a concise function or observed reaction until the researcher has
  enough knowledge to assign a formal name.

## Image Generation Kit

### General Rules

1. Generate concepts without naming or imitating a living artist.
2. State whether the output is an approval concept or a production candidate.
3. Name its native grid, cell dimensions, palette, facing, and stable ground pivot.
4. Use top-down three-quarter perspective and upper-left lighting for gameplay.
5. State the focal subject and required negative space for play or menu controls.
6. Ask for no baked text, letters, logos, signatures, or watermarks. R/G/B labels
   and all functional text are rendered by Godot, not the image generator.
7. Require clean transparency and separation for isolated sprites and effects.
8. Approve the researcher and menu samples, then decide and approve gameplay
   composition separately before gameplay-art production.
   Do not bulk-generate animations until that review passes.
9. Inspect at native size and integer enlargement. Clean the result to the actual
   source grid and palette; reject inconsistent faux pixels or contaminated alpha.
10. Generated UI is a visual brief, not a replacement for scene-authored controls.

The generator may not produce exact small dimensions or consistent frames.
Request a clear integer-enlarged source study when necessary, then deliberately
rebuild/clean its pixel clusters. Never label an enlarged concept production-ready
just because nearest-neighbor reduction reaches the requested size.

### Canonical Style Prefix

Use this at the beginning of image prompts, then add the asset-specific request:

```text
Pure 2D pixel art for CombatAlchemy, melancholic dark fantasy about a forbidden
occult field researcher, invented folklore world, compact readable silhouettes,
deliberate pixel clusters and crisp stepped edges, eight neutral grayscale
values for ordinary art, selective saturated reagent and potion color only,
upper-left lighting, quiet negative space, worn functional materials simplified
to a few clear shapes, gameplay readability before detail, no painterly texture
```

### Prompt Formula

```text
[CANONICAL STYLE PREFIX].

Asset type and status: [approval concept / cleaned sprite candidate / UI study].
Native grid: [640x360 composition / 32x40 character cell / explicit prop grid].
Preview: [native size and a named integer enlargement; no interpolated pixels].

Subject and action: [one primary subject doing one readable action].
Camera: [fixed elevated three-quarter gameplay view / menu composition].
Composition: [clear movement space, stable ground pivot, UI or title margins].
Environment: [material family and practical details, not a new gameplay scope].
Lighting: [upper-left stepped values; colored light only for alchemical meaning].
Palette: [eight-value grayscale ramp plus named reagent/recipe colors].
Frame rules: [facing, contact/passing phase, empty hands, fixed cell boundaries].
Output: [transparent sprite / clean scene plate, alpha requirements, no text].

Avoid: [CANONICAL NEGATIVE CONSTRAINTS].
```

### Canonical Negative Constraints

```text
photorealism, glossy 3D, anime rendering, painterly brushwork, paper-grain overlay,
anti-aliasing, blurred edges, soft gradients, inconsistent pixel sizes, smooth
sprite rotation, subpixel detail, oversized heads outside the fixed cell, neon
world lighting, colored ordinary costumes or terrain, cheerful cozy fantasy,
generic magic glyphs, rune circles, chants, spellcasting hands, ornate heroic
armor, excessive particles, bloom, illegible silhouettes, isometric tile grid,
wide-angle distortion, cluttered HUD, card-game layout, text, letters, logo,
signature, watermark
```

Remove an item from the negative constraints only when the asset brief explicitly
requires it. Do not remove constraints merely to increase variation.

## Ready-to-Adapt Prompts

### Key Art

```text
Pure 2D pixel-art key-art study for CombatAlchemy. A lone forbidden researcher
with a broad hat and compact coat stands above a ruined mountain laboratory.
Use eight neutral grayscale values, clear silhouette clusters, upper-left
light, and a quiet sky region for a future engine-rendered title. Only liquid
in a small flask may carry color. Melancholic and practical, not heroic.
Compose on a 640x360 native grid, presented without interpolation.
No text, painted texture, soft gradients, 3D rendering, glyphs, or watermark.
```

Key art can be cinematic, but it is not the gameplay perspective specification.
Prepend the canonical prefix and append the negative constraints to each brief.

### Gameplay Expedition Environment

```text
Pure 2D pixel-art future-environment study for CombatAlchemy, 640x360 native
composition. Fixed elevated three-quarter view of ruined medicinal terraces
beside an observatory. A broad quiet central route remains clear for 32x40
characters; simple stone and root clusters frame the perimeter. Eight grayscale
values and upper-left light. One small blue residue mark is a deliberate
alchemical clue, not a colored biome theme. No actors or interface, no horizon,
isometric grid, texture grain, blur, text, or watermark.
```

This is future expedition reference. The conversion's playable environment scope
is only the existing sandbox, dressed with a small reusable terrain/prop set.

### Gameplay Approval Sample (Intentionally Deferred)

There is no canonical gameplay-composition prompt or retained sample yet. The
permanent `1920 x 1080` project canvas, compact-character direction, grayscale
foundation, and alchemy-only color remain constraints, but camera framing,
character and flask dimensions, environment composition, actor spacing, and
exact HUD relationship require a separate decision before another gameplay study.

### Main-Menu Approval Sample

```text
Pure 2D pixel-art CombatAlchemy menu background on a 640x360 native grid.
A solitary field laboratory overlooks a pale, abandoned mountain road. Use
eight neutral grayscale values, upper-left lighting, crisp clusters, and quiet
negative space reserved for a title and three functional menu commands.
One tiny reagent vessel may carry a restrained alchemical color accent; ordinary
lamps and materials remain grayscale. Lonely and tactile, not a busy equipment
catalog. No drawn buttons, baked text, smooth blur, paper texture, or watermark.
```

### Researcher Character Concept

```text
Pure 2D pixel-art researcher approval sheet: four separate 32x40 neutral poses,
front, back, side-left, and side-right. Broad worn hat, obscured face, compact
weathered coat, gloves, boots, and one readable satchel cluster. Eight neutral
grayscale values only, top-down three-quarter perspective, upper-left lighting,
stable foot pivot and consistent proportions. Both hands empty. Draw each side
independently; do not mirror lighting, equipment, or anatomical hands. Transparent
background, integer-enlarged preview, no cell labels, props in hands, grain,
anti-aliasing, text, or watermark. This is a sample, not the full walk sheet.
```

### Enemy Concept

```text
Pure 2D pixel-art future-enemy study, three separated silhouette poses on equal
native cells sized relative to a 32x40 player. An observatory keeper altered by
mineral bloom: hunched posture, one pale salt-crusted shoulder, and a hanging
measuring tool. Neutral, approach, and telegraph poses readable without internal
detail. Eight grayscale values; one tiny blue material clue. Upper-left light,
top-down three-quarter angle, transparent background. No gore, random spikes,
soft shadows, painted wash, text, or watermark. Do not treat these future poses
as additional animation scope for the current static Foe conversion.
```

### Transparent Gameplay Sprite

```text
After sample approval: create a full-body pixel-art player sheet from the
approved researcher design. Native sheet 192x160, four rows of six 32x40 cells.
Rows represent front, back, side-left, side-right; each row contains two idle
frames followed by four alternating contact/passing walk frames. Keep one foot
pivot per cell, consistent proportions, empty hands, and independent left/right
art. Eight neutral grayscale values, upper-left light, top-down three-quarter
perspective, transparent background. No joint-part atlas, motion blur, frame
blending, colored costume, attached bottle, labels, grid lines, or watermark.
```

Validate and repair every cell; exact sheet dimensions and consistent gait are
production acceptance checks, not capabilities to assume from generated output.

### Laboratory Props and Reagent Containers

```text
Pure 2D pixel-art field-alchemy prop study with separated flask, mortar, filter,
notebook, sample jar, and small burner. Use a stated consistent source-pixel
scale beside a 32x40 character reference, top-down three-quarter perspective,
upper-left light, eight grayscale values, clear functional silhouettes.
Only red, green, or blue sample contents carry saturated color. Transparent
background and clean integer-grid edges; no baked shadows, text, decorative
mechanisms, gradients, or watermark. Approve individual usable props rather
than adopting the entire concept sheet as a texture.
```

### Flask Interface Concept

```text
Pixel-art flask UI study for a 640x360 CombatAlchemy screen. Show separated
48x64 flask states: empty/open, three horizontal bottom-up reagent bands,
uniform prepared liquid, and a rejected mixture with displaced outline pixels.
Also show a composition with the mixer fully hidden. Grayscale glass outline,
red/green/blue reagents, magenta or teal prepared liquid, three small swatches
to the right with space for engine-rendered R/G/B labels. Fixed dimensions,
no enclosing card, name, log, decorative panel, baked text, blur, or watermark.
```

### Potion Projectile and Impact Effects

```text
Pure 2D pixel-art potion VFX study with separated travel, contact, and consequence
frames at a consistent scale relative to a 32x40 player. One grayscale bottle
with tinted liquid; health uses rounded magenta gathering droplets, damage uses
a small sharp teal outward splash. Few particles, stepped value changes,
transparent background, upper-left light, clear impact point and target space.
Reuse the bottle outline. No fireball, glyphs, smooth bloom, huge explosions,
opaque smoke, painted brush edges, text, or watermark. These are feedback frames,
not a request to delay existing potion effects until an animation event.
```

## Asset Generation Checklist

Before accepting a generated image as a useful concept or production candidate,
check all applicable items:

- [ ] It uses deliberate native-grid pixel art, not downsampled painted texture.
- [ ] The relevant sample has explicit approval before bulk asset production.
- [ ] Native-size and integer-enlarged previews are readable and grid-consistent.
- [ ] Ordinary art uses the agreed eight-value grayscale ramp.
- [ ] Gameplay assets use the same top-down three-quarter perspective.
- [ ] Upper-left lighting is consistent or the exception is documented.
- [ ] The primary silhouette remains readable when viewed small.
- [ ] Saturated color communicates alchemy rather than filling the whole image.
- [ ] Important interaction space is not covered by texture, fog, or props.
- [ ] The image has one clear focal hierarchy.
- [ ] Materials look handled, worn, and functionally constructed.
- [ ] No generic magical glyphs, old combat vocabulary, or spellcasting pose has
  re-entered the design.
- [ ] No text, signature, logo, or watermark is baked into an asset unless the
  image is an explicitly non-production layout study.
- [ ] Transparent assets have clean alpha, adequate padding, and no unwanted
  background or baked shadow.
- [ ] Character, prop, and effect scale matches its intended gameplay use.
- [ ] Player frame dimensions are approved against the chosen gameplay composition and stable ground pivot.
- [ ] Four facings preserve anatomy, lighting, empty hands, and socket alignment.
- [ ] Idle/walk frame order is consistent and turns do not restart the gait.
- [ ] UI fits the permanent canvas and tested window sizes; the flask does not obscure play space.
- [ ] The asset can be implemented without requiring a different visual system.

## Roadmap Guidance

### Feature Admission Test

A proposed feature belongs on the active roadmap only when:

1. It directly strengthens discovery through mixing, readable cause and effect,
   expedition tension, or knowledge progression.
2. It preserves the flask as the central interaction instead of bypassing it.
3. Its player-facing behavior can be tested in a small scene before broad content
   production.
4. Its visual and audio feedback can follow this document.
5. It has one clearly bounded player-facing purpose and can be evaluated without
   broad supporting systems.
6. It does not reintroduce a listed non-goal under another name.

For prioritization, a feature must strengthen **discovery through mixing** or be
necessary to test it. It should also strengthen at least one of readable
cause-and-effect, expedition tension, or knowledge progression. Features that
fail those tests stay out of the MVP roadmap.

### Milestone Themes

These are sequencing guides, not committed dates or content counts.

#### 1. Lock the Visual Target and Mixing Feel

Execute the [approved conversion plan](./plannings/plans/2026-09-12-pixel-art-conversion.md)
in reviewable stages: implemented native animated main menu; a separate
gameplay-composition decision; player frames; remaining current screens;
regression checks and documentation. Approve gameplay framing and representative
character, flask, health, and damage scale before multiplying gameplay assets.
Keep potion delivery rules and immediate drink/throw/place behavior unchanged.

Playtest the integrated small-flask hold/release/settle interaction. Tune
readability, predictable early/late outcomes, and repeated use before adding
vessel tiers. This gameplay work remains separate from the visual conversion
and does not settle gameplay composition.

#### 2. Add Reactive Enemy AI and Expand Combat Decisions

Build one complete enemy loop with notice, pursuit, telegraph, attack, recovery,
and potion-specific reactions. Add enough variation for observation, mixing,
drinking, throwing, placing, and selected world reactions to create different decisions.
Prioritize intent readability and reaction clarity over enemy or recipe quantity.

#### 3. Build One Complete Expedition

Create one authored location with an entrance, readable navigation, material
clues, encounters, discoveries, and a return condition. Finish one coherent route
before multiplying biomes.

Prove deliberate placement and remembered preparations on a route the player
revisits. Activation and persistence need their own tests before expanding into
remote triggers, trap chains, or multiple locations.

#### 4. Add the Refuge and Discovery Record

Give collected knowledge a place to persist, be reviewed, and suggest future
hypotheses. Build the record around actual discovery data after the mixing rules
are stable.

Introduce one larger brewing vessel and a worthwhile staged recipe. Let recipe
knowledge precede access to its apparatus. Add finished-potion storage through
the existing instance ownership boundary, not by making the mixer an inventory.

#### 5. Produce a Cohesive Vertical Slice

Connect menu, refuge, one expedition, potion combat, return, discovery, music,
settings, pause, and transitions into one presentable experience. Refine the
slice before expanding content breadth.

### Dependency Rules

- Lock a visual target before bulk asset generation.
- Finish the current-screen conversion before adding a second visual pipeline.
- Keep physics/recipe/ownership contracts stable while replacing presentation.
- Prove a discovery rule before building a large recipe catalog.
- Prove the short release/settle interaction before adding long staged recipes.
- Preserve recipe identity across delivery; validate persistence before promising
  return-and-activate strategies across scenes.
- Complete one expedition before building several locations.
- Stabilize recorded discovery data before designing a large research interface.
- Add narrative consequences only after the actions that cause them are playable.
- Prefer one focused, playable interaction over broad supporting systems.

### Reject or Defer When

- the feature primarily adds another combat subsystem beside the flask;
- it requires constant logs or tutorial overlays to be understood;
- it expands recipes without adding meaningful deduction or decisions;
- it hides reaction momentum, forces a tiny perfect-timing window, or turns
  familiar laboratory brewing into long repetitive holds;
- it adds potion forms or quality rolls without a distinct, readable decision;
- it adds lore breadth before the player can interact with existing ideas;
- it depends on generic stat inflation as its main reward;
- it needs large content production before a small behavioral prototype can work;
- it makes alchemical color less consistent or less readable;
- it requires many directions, actions, body-part atlases, or unique effects
  before the compact idle/walk and shared-bottle pipeline works;
- it treats recoloring or filtering painted images as finished pixel art;
- it treats atmosphere as more important than input, targeting, or feedback;
- it reintroduces deleted terminology, managers, or UI patterns without a new and
  explicit design reason.

## Consistency Checklist

Use this shorter checklist for roadmap reviews, pull requests, briefs, and demos.

### Experience

- [ ] Does the work support observation, hypothesis, commitment, application, or
  learning?
- [ ] Is knowledge more important than raw stat growth?
- [ ] Does real-time pressure create a decision without making controls awkward?
- [ ] Can success and failure teach the player something?
- [ ] Is release responsive and the remaining reaction energy readable?
- [ ] Does a larger vessel unlock a meaningful recipe while small flasks stay useful?

### Visuals

- [ ] Is the silhouette readable before the detail?
- [ ] Are pixel size, palette, grid alignment, and integer display scale consistent?
- [ ] Is the base palette restrained and the alchemical color intentional?
- [ ] Does the asset use the correct perspective and lighting?
- [ ] Is there enough negative space for gameplay clarity?
- [ ] Does the material wear tell a practical story?

### Interface and Feedback

- [ ] Is the flask still the central mixing interaction?
- [ ] Can cause and effect be understood without a combat log?
- [ ] Do color, motion, health response, and sound agree?
- [ ] Is a finished potion's effect consistent across drink, throw, and activation?
- [ ] Can players trust a dormant preparation to remain available on the intended return?
- [ ] Is functional text built in-engine rather than baked into art?

### Scope and Architecture

- [ ] Is this the smallest version that can test the idea?
- [ ] Does it fit the current component architecture?
- [ ] Is its supporting scope proportional to its player-facing value?
- [ ] Does it respect the explicit non-goals?
- [ ] Are current implementation, approved migration, and later goals labeled separately?

## Shared Vocabulary

Use these terms consistently in design, code discussions, prompts, and roadmap
work.

| Term | Meaning |
| --- | --- |
| **Researcher** | The player character and field alchemist. |
| **Refuge** | The safe or comparatively safe place for review and preparation. |
| **Expedition** | A bounded journey into a dangerous location with a research or practical purpose. |
| **Reagent** | A substance added to the flask. Red, green, and blue are the current base families. |
| **Layer** | One reagent addition visibly occupying part of an unfinished mixture. |
| **Ingredient unit** | One counted addition; repeated units of the same reagent each consume capacity. |
| **Mixture** | The ordered or counted set of layers before successful preparation. |
| **Recipe** | A valid combination and its resulting behavior. |
| **Brewing vessel** | Apparatus that holds ingredients and provides working capacity for a reaction; not necessarily the portable finished bottle. |
| **Brewing stage** | One meaningful operation in a recipe; intermediate completion does not create a usable potion. |
| **Reaction energy** | The proposed remaining activity that briefly advances brewing after agitation stops. |
| **Release** | Stop adding agitation immediately; not a throw or an automatic use of the potion. |
| **Settle** | Let remaining reaction energy dissipate and evaluate the brewing stage's outcome. |
| **Prepared potion** | A unique successfully mixed potion ready to drink, throw, place, or discard; future storage is a separate feature. |
| **Dormant placement** | Planned stable world preparation awaiting deliberate activation; distinct from the current temporary proximity bottle. |
| **Potion instance** | One produced potion's runtime identity, separate from its shared recipe and visual entity. |
| **Held slot** | The current one-potion ownership boundary; not a permanent limit on future storage. |
| **Source pixel** | One pixel in an authored raster asset. Full-screen menu art currently uses the 1920 x 1080 project canvas; gameplay asset scale remains undecided. |
| **Pixel cluster** | A deliberate connected group of pixels describing a readable shape or value plane. |
| **Facing** | Front, back, side-left, or side-right artwork selected independently of eight-direction movement. |
| **Reaction** | The readable visual, mechanical, and audio consequence of applying a potion. |
| **Observation** | A clue the player can notice but may not yet understand. |
| **Discovery** | Knowledge made reliable enough to record and reuse. |
| **Consequence** | A persistent or story-relevant trace left by research or potion use. |
| **Field Notes menu** | The native 1920 x 1080 laboratory entry screen with a dark command margin, animated window/weather details, and focused RGB reagent lights. |

Avoid using spell, chant, rune, cast, mana, or spellbook as active-system terms.
Use potion, mix, prepare, drink, throw, place, reagent, reaction, and discovery instead.

## Current Project Reference Boundaries

The current project contains useful fragments, not one complete production style.
Use each reference only for the qualities named below.

| File | Use as reference for | Do not inherit |
| --- | --- | --- |
| `sprites/main_menu_alchemy.png` | Historical mood, value grouping, negative space, isolation, and distant mystery | Painted texture, exact composition, palette, or direct downsampling as final pixel art |
| `mainmenu/MainMenuBackdrop.tscn` and `sprites/main_menu/animated/` | Active menu composition, grayscale value hierarchy, integer ambient motion, and focused reagent color | Gameplay camera, character scale, terrain density, or flask dimensions |
| `combat/ui/FlaskView.tscn` and `combat/ui/PotionMixerUI.tscn` | Flask-first interaction, liquid layers, and bottom-center composition | Current dimensions, polygons, tweens, or button style as immutable presentation |
| `docs/ART_REF_G06_RESEARCHER_CUTOUT_TARGET.png` | Historically approved hat, obscured face, coat, and practical equipment | Approval of a new pixel sample, detailed cutout atlases, texture, or exact anatomy |
| `characters/player/PlayerModel.tscn` | Current four-facing motion/socket contract and shared combat/workshop boundary | Its 15-bone internals as a requirement of the new sprite-sheet model |
| `characters/player/README.md` | Current implementation, planned frame workflow, API, and workshop checks | A claim that planned pixel APIs or assets are already present |
| `extra/ink_wash_shader_done.gdshader` | Current reveal timing and scene-change language | Smooth full-resolution treatment as a final pixel effect or permanent gameplay overlay |
| `docs/PROJECT_ARCHITECTURE.md` | Current technical ownership and implemented behavior | Creative or visual direction beyond its factual description |

The current target sprites, placeholders, arena, UI, logo files, and legacy assets
are not automatic style targets because they remain in the repository. Retain
existing source art and music, but use the new pixel sample approval to establish
production appearance. The active PlayerModel still uses geometric skeletal
placeholders pending the approved full-body sprite-sheet conversion.
When an existing asset conflicts with this document, retain only the explicitly
approved quality until a replacement is produced.

## Maintaining This Document

- Change this document deliberately when the creative north star changes.
- Update the vision version when design pillars, visual rules, or non-goals
  change materially.
- Keep prototype facts synchronized with `PROJECT_ARCHITECTURE.md` without
  duplicating its script-level reference.
- Record future direction as intention, not as implemented behavior.
- Record sample approval separately from approval of the conversion plan.
- Preserve historical prompts and source attribution in the art index; do not
  rewrite them to imply older images were generated from the new pixel brief.
- When an accepted asset establishes a better production rule, update the rule
  and examples rather than relying on unwritten precedent.
- When a roadmap proposal conflicts with this document, either reject the
  proposal or revise the vision explicitly. Do not quietly create two competing
  versions of CombatAlchemy.
