# CombatAlchemy Style and Vision

> Status: Living creative reference
> Working title: CombatAlchemy
> Vision version: 0.1
> Last updated: 2026-07-16
> Technical companion: [Project Architecture](./PROJECT_ARCHITECTURE.md)

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

## North Star

> A melancholic ink-wash dark-fantasy game about a forbidden occult researcher
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
- **I apply:** the same potion can be drunk, thrown, or eventually used on the
  world, depending on its properties.
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

## Design Pillars

### Knowledge Is Progression

The most important thing the player brings home is understanding. New recipes,
ingredient properties, enemy reactions, environmental observations, and reliable
theories should matter more than linear stat increases.

Progression should favor new decisions over larger numbers. Better progression
widens what the player can attempt, interpret, combine, or risk.

### Alchemy Happens Under Pressure

Mixing remains part of the real-time world. The player must choose when it is
safe to open the flask, add layers, finish a potion, drink it, or throw it. The
interface must be quick enough to use in danger but physical enough to feel like
mixing rather than hotbar selection.

Pressure should come from the world and encounter, not from intentionally
awkward controls.

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
   and available leads.
2. **Choose an expedition:** enter one dangerous location with a clear practical
   or research purpose.
3. **Observe:** read material clues, creature behavior, color, residue, weather,
   and environmental reactions.
4. **Collect and test:** obtain reagents and form mixtures from known rules or new
   hypotheses.
5. **Apply under pressure:** drink, throw, or eventually use a preparation on an
   object or environmental condition.
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
| Player | Movable 2D actor with a following camera | A readable occult researcher with field equipment |
| Encounters | Stationary Friend and Foe test targets | Enemies, allies, terrain, and pressure create potion decisions |
| Mixing | Three RGB layers and two count-based recipes | A readable rule set expanded through discoveries and ingredient properties |
| Application | Drink self or throw at a target | Drink, throw, and later interact with selected world conditions |
| Progression | None | Knowledge and recorded discoveries lead; statistics remain secondary |
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
- a conventional skill-tree power climb;
- bright, whimsical, cozy potion-shop fantasy;
- explicit body horror or gore-first dark fantasy;
- a constant stream of combat logs, recipe names, tutorials, or floating text;
- a glossy mobile-fantasy interface covered in panels and currencies;
- a direct recreation of one real historical culture;
- a system where ambiguity is created by unreadable feedback;
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

Ink wash is the visual medium, not permission to copy sacred symbols, historical
clothing, or culturally specific calligraphy without research and intent.
Alchemy is expressed through vessels, stains, measurements, natural processes,
and abstract geometry rather than borrowed religious iconography.

### Emotional Register

The dominant mood is **melancholic mystery**:

- loneliness without total hopelessness;
- danger without constant spectacle;
- wonder that feels earned through attention;
- old places whose original purpose is only partly understood;
- quiet warmth in the refuge against cold or exposed expedition spaces;
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

Avoid pristine fantasy props. Objects should show handling, repair, local craft,
and exposure to their environment.

### Recurring Motifs

- vessels, droplets, stains, sediment, and separated liquid layers;
- roots, capillaries, river branches, and cracked glaze;
- eclipses, concentric rings, orbital diagrams, and measurement marks;
- smoke moving against the wind;
- windows or doorways framing distant unknown places;
- a small warm light surrounded by a larger field of cool emptiness;
- three-color marks used sparingly to communicate alchemical information.

Abstract alchemical geometry may use rings, ratios, and diagrams. It must not
become an alphabetic magical language or generic glowing glyph decoration.

## Visual Direction

### Production Format

- Final presentation is **pure 2D raster**.
- Gameplay uses a **top-down three-quarter** perspective.
- Backgrounds, actors, props, UI art, and effects should share one lighting and
  perspective system.
- Key art may use a more cinematic angle, but it must preserve the same materials,
  silhouette language, palette, and emotional tone.
- Generated concepts are references until rebuilt or cleaned for production.

### Rendering Language

The target is hand-painted ink wash and charcoal on textured paper, adapted for
gameplay clarity:

- broad value masses before surface detail;
- dry-brush edges and controlled ink bleed;
- visible paper grain in quiet areas;
- charcoal or soot-dark silhouettes;
- selective sharp edges at gameplay-relevant contacts;
- restrained interior detail at gameplay scale;
- deliberate negative space around important actors and interactions;
- local color concentrated in alchemical liquids and reactions.

Do not apply paper texture uniformly at full strength. Important silhouettes,
flask boundaries, collision-relevant objects, and active effects need cleaner
edges than distant scenery.

### Composition

- Establish one clear focal hierarchy per image or gameplay view.
- Keep traversable ground readable before adding atmospheric marks.
- Separate actors from the ground by value, edge, or restrained rim light.
- Use foreground brush masses to frame a view, not cover interaction space.
- Preserve calm regions so saturated reactions have visual authority.
- Avoid evenly distributing props, particles, or contrast across the frame.
- In gameplay backgrounds, keep the center and expected movement routes quieter
  than the perimeter.

### Camera and Perspective

For gameplay assets:

- use a fixed top-down three-quarter view, approximately 35 to 45 degrees above
  the ground;
- avoid wide-angle distortion and dramatic horizon lines;
- keep verticals consistent across actors, props, and environment pieces;
- use upper-left as the default key-light direction;
- keep contact points and feet visible;
- give each isolated sprite enough transparent padding for effects and motion;
- do not bake large directional shadows into sprites if shadows need to respond
  independently in-engine.

### Canonical Palette

The palette is built from ink, cool atmosphere, weathered materials, and limited
alchemical color. Parchment is a grounding neutral, not a requirement that every
gameplay environment be beige.

| Role | Color | Hex | Usage |
| --- | --- | --- | --- |
| Soot Ink | Very dark warm neutral | `#171411` | silhouettes, outlines, deep UI shade |
| Deep Wash | Charcoal gray | `#2B2B28` | secondary dark masses and terrain |
| Paper Bone | Pale neutral | `#E7E0CE` | high-value paper, glass glints, sparse text |
| Weathered Parchment | Muted warm neutral | `#C9BDA2` | menus, records, warm environmental planes |
| Mist Gray | Cool gray-green | `#9BA39D` | fog, distant terrain, quiet separation |
| Ember Gold | Muted warm accent | `#C58E3D` | refuge light, focus, selected UI accents |
| Oxide Red | Earthy reagent red | `#B83B35` | world materials and inactive red-family clues |
| Verdigris Green | Earthy reagent green | `#3F7F55` | plants, oxidation, inactive green-family clues |
| Lapis Blue | Earthy reagent blue | `#3D6098` | minerals, cold atmosphere, inactive blue clues |
| Reaction Violet | Mixed accent | `#7D4F88` | prepared healing-family reactions |
| Reaction Teal | Mixed accent | `#2F8980` | prepared damage-family reactions |

#### System Reagent Colors

The active reagent colors may be more saturated than the world palette because
they carry mechanical information:

| Family | Active color | Hex |
| --- | --- | --- |
| Red | Clear warm red | `#E62933` |
| Green | Clear botanical green | `#33C759` |
| Blue | Clear mineral blue | `#2673F2` |

Use these active colors inside liquid, a selected reagent control, a reaction
core, or a brief impact accent. Do not wash entire environments, costumes, or UI
panels in saturated RGB.

### Lighting

- Expeditions favor overcast ambient light, cold open air, mist, and isolated
  pools of practical warmth.
- The refuge favors ember light, candle glow, reflected copper, and dark corners.
- Alchemical reactions may cast a short local color onto nearby surfaces.
- Bloom must remain narrow and brief. It cannot erase the shape of the flask,
  target, or impact.
- Pure white is reserved for glass glints, the hottest reaction center, or a
  single high-priority focal edge.

## Subject Rules

### The Researcher

The researcher should read as a practical occult scholar before reading as a
warrior:

- a strong asymmetrical silhouette;
- a long layered coat, robe, apron, or traveling mantle built for weather;
- a broad hat, hood, or raised collar that partially obscures the face;
- visible glass, sample cases, field notes, gloves, ties, and repaired equipment;
- one clearly readable flask hand or throwing gesture during potion actions;
- restrained ornament based on measurements, stitching, stains, and repairs;
- a posture that suggests attention and caution rather than heroic confidence.

Avoid staffs, glowing hands, ornate armor, oversized weapons, and generic wizard
stars. The researcher manipulates substances and apparatus, not free-floating
magic.

At gameplay scale, the hat or shoulder line, coat hem, and flask arm should form
the three fastest recognition points.

### Allies and Other People

- Give each person a practical relationship to their location through clothing,
  tools, wear, and posture.
- Keep silhouettes simpler and less occult than the researcher unless the story
  specifically requires otherwise.
- Use warmth, openness, and intact materials to distinguish trust without making
  allies visually pristine.
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

### Environments

- Design ground planes for movement and targeting before adding scenic detail.
- Use brush density, residue, roots, cracks, and object placement to imply routes.
- Put the highest detail around discoveries, hazards, and landmarks.
- Let distant scenery dissolve into mist and paper rather than using uniform blur.
- Use color clues as local evidence. A red mineral vein or blue condensation mark
  should be intentional, not ambient decoration.
- Keep each expedition visually identifiable through material and weather, not a
  full-screen color filter.

### Props and Reagents

- Reagent containers should be identifiable by silhouette as well as color.
- Glass is uneven, repaired, stoppered, wrapped, measured, and visibly used.
- Labels should use marks, bands, shapes, or material samples when text is not
  meant to be read.
- Tools should show a plausible function: grinding, heating, filtering, measuring,
  collecting, sealing, or recording.
- Avoid identical generic bottles recolored into a complete asset set.

## Interface Direction

### Combat Interface

The flask is the primary combat interface and should remain the visual center of
mixing.

- Keep it at the bottom center of the screen.
- Show unfinished reagents as clearly separated liquid layers from bottom upward.
- Show the prepared result as one unified liquid.
- Keep reagent controls adjacent to the flask and identify them with both color
  and a simple label or shape.
- Preserve the authored glass outline at every state.
- Keep failures physical: a shake, unstable liquid, brief ink flare, or glass
  stress. Do not replace feedback with a large error message.
- Hide the mixer when it is irrelevant so the world remains dominant.
- Keep world-space health feedback compact and readable.

Do not add combat logs, recipe cards, permanent ability bars, decorative nested
panels, or large tutorial paragraphs to the main combat view.

### Menus and Records

- Menus use ink, paper, stained wood, dark translucent wash, and muted gold focus.
- The existing ink reveal transition is aligned with the vision.
- An eventual research record should feel handled and accumulated, not like a
  modern database dashboard.
- Information still needs strong hierarchy, predictable navigation, and readable
  contrast. Diegetic styling is not an excuse for poor usability.
- Use symbols for familiar controls and concise text for commands.
- Do not generate final interface text inside images. Build final text in Godot.

### Typography

The current `yoster.ttf` is a prototype display face, not a mandatory final font.
The intended typography system uses:

- one weathered but readable display face for titles and major labels;
- one highly legible companion face for settings, quantities, notes, and body
  text;
- normal letter spacing and stable sizes;
- short labels in combat;
- sentence case for most interface text.

Avoid faux calligraphy for functional UI, distressed fonts at small sizes, and
large all-caps paragraphs.

## Potion and Effect Direction

### RGB as Mechanical Grammar

Red, green, and blue are the prototype's base reagent families. They are a
readability contract, not necessarily final in-world ingredient names.

Future ingredients may be named substances with origin, texture, rarity, and
secondary properties. Their family color must remain identifiable during rapid
mixing. A player should be able to learn deeper fiction without losing the
clarity of the original three-color grammar.

### Reaction Sequence

Every potion effect should communicate three beats:

1. **Anticipation:** liquid state, hand pose, projectile shape, or a brief sound
   establishes what is about to happen.
2. **Contact:** glass, liquid, or vapor reaches the target with a clear point of
   impact.
3. **Consequence:** the target and health state respond with a distinct motion,
   value shift, color behavior, and sound.

### Visual Vocabulary

- Use liquid arcs, splashes, droplets, vapor, sediment, ink blooms, dry-brush
  wipes, and controlled glass fragments.
- Keep the reaction core saturated and the outer effect desaturated or
  transparent.
- Match effect direction to function: restorative reactions gather, settle, or
  rise; destructive reactions cut outward, stain, erode, or rupture.
- Preserve target readability through the effect.
- Keep lingering residue only when it communicates an ongoing state.
- Use particles as supporting texture, not as the whole effect.

For the current recipes:

- **Health Potion, red + red + blue:** a restrained violet or magenta mixture;
  rounded gathering motion, upward suspension, and a warm return of value.
- **Damage Potion, green + green + blue:** a teal mixture; sharper outward wash,
  corrosive edge, and a brief loss of value.

Recipe behavior is determined by the mixture, not by whether the target is called
Friend or Foe.

### Animation

- Favor clear poses, held silhouettes, and a few deliberate painterly transitions.
- Use brush smears and ink displacement for fast motion rather than uniform blur.
- Keep idle movement subtle.
- Camera shake should be short, low amplitude, and reserved for meaningful impact.
- Do not use constant floating, pulsing, or particle emission on every object.

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
2. State whether the image is key art, environment concept, production sprite,
   prop sheet, UI concept, or effect sheet.
3. Specify top-down three-quarter perspective for every gameplay asset.
4. Specify upper-left key lighting unless the scene intentionally overrides it.
5. Name the one focal subject and one focal action.
6. State where negative space is needed for gameplay or title placement.
7. Ask for no text, letters, logos, signatures, or watermark.
8. For isolated assets, explicitly require a transparent background and clean
   separation between objects.
9. Treat generated UI as a visual brief. Rebuild functional UI in Godot.
10. Review generated work against the asset checklist before adding it to the
    project.

### Canonical Style Prefix

Use this at the beginning of image prompts, then add the asset-specific request:

```text
2D raster artwork for CombatAlchemy, melancholic ink-wash dark fantasy in an
invented syncretic folklore world, charcoal and dry-brush linework on subtly
textured paper, strong readable silhouettes, deliberate negative space,
restrained soot, cool-mist, and weathered-material palette, selective saturated
alchemical color, hand-painted edges, atmospheric but gameplay-readable
```

### Prompt Formula

```text
[CANONICAL STYLE PREFIX].

Asset type: [key art / gameplay environment / character concept / transparent
sprite / prop sheet / UI concept / VFX sheet].

Subject and action: [one primary subject doing one readable action].
Camera: [top-down three-quarter for gameplay, framing, lens restrictions].
Composition: [focal hierarchy, clear movement space, requested negative space].
Environment: [location family, weather, ground material, practical details].
Lighting: [upper-left key light, cool ambience, warm practical light, reaction
light if relevant].
Palette: [base neutrals plus named limited accent colors].
Material details: [glass, cloth, metal, paper, residue, wear].
Output requirements: [aspect ratio, transparent background, padding, separated
objects, no baked shadow, or clean UI-free plate].

Avoid: [CANONICAL NEGATIVE CONSTRAINTS].
```

### Canonical Negative Constraints

```text
photorealism, glossy 3D render, cel-shaded anime, cheerful cozy fantasy,
high-saturation full-frame color, neon cyberpunk lighting, generic glowing magic
glyphs, rune circles, spellcasting hands, ornate heroic armor, oversized weapons,
random spikes, excessive particles, heavy bloom, muddy silhouettes, fisheye or
wide-angle distortion, cluttered HUD, card-game layout, legible text, letters,
logo, signature, watermark
```

Remove an item from the negative constraints only when the asset brief explicitly
requires it. Do not remove constraints merely to increase variation.

## Ready-to-Adapt Prompts

### Key Art

```text
2D raster artwork for CombatAlchemy, melancholic ink-wash dark fantasy in an
invented syncretic folklore world, charcoal and dry-brush linework on subtly
textured paper, strong readable silhouettes, deliberate negative space,
restrained soot, cool-mist, and weathered-material palette, selective saturated
alchemical color, hand-painted edges, atmospheric but gameplay-readable.

Key art of a solitary forbidden occult researcher standing on a wind-cut ridge,
seen from behind at a restrained cinematic angle. Their asymmetrical traveling
coat and broad weathered hat move in the wind; a small glass flask glows with
three separated red, green, and blue layers in one lowered hand. Across a pale
valley stands a ruined mountain laboratory joined to an ancient observatory.
Large quiet sky and mist create negative space on the upper right for a title.
Cool overcast ambience, one distant amber window, black ink foreground, no combat
pose. 16:9 composition, no text or logo.

Avoid: photorealism, glossy 3D, anime rendering, cheerful fantasy, neon lighting,
generic magic glyphs, rune circles, ornate armor, oversized staff, excessive
particles, heavy bloom, watermark.
```

### Gameplay Expedition Environment

```text
2D raster gameplay environment for CombatAlchemy, melancholic ink-wash dark
fantasy, invented syncretic folklore, charcoal and dry-brush marks on subtly
textured paper, restrained soot and cool-mist palette with sparse alchemical
color.

Top-down three-quarter view of a ruined mountain observatory surrounded by
overgrown medicinal terraces. A broad readable central route connects a broken
gate, a circular instrument platform, and a sheltered workbench. Dark pines and
stone frame the perimeter without covering movement space. Small intentional
clues include an oxide-red mineral seam, verdigris runoff, and blue condensation
near a sealed door. Upper-left overcast light, distant edges dissolve into mist,
no characters, no interface. 16:9 clean gameplay plate at 1920x1080.

Avoid: horizon-level camera, isometric grid, photorealism, 3D render, bright
fantasy colors, evenly scattered props, unreadable ground, full-screen fog,
glowing glyphs, text, watermark.
```

### Researcher Character Concept

```text
2D raster character concept for CombatAlchemy, melancholic ink-wash dark fantasy,
invented syncretic folklore, charcoal and dry-brush linework on paper, strong
silhouette, restrained palette.

Full-body forbidden occult field researcher in a neutral standing pose and one
potion-throwing pose. Long asymmetrical weatherproof coat, broad worn hat that
partly hides the face, leather sample case, stitched notebook, gloves, repaired
glass harness, practical boots, no armor. The flask arm and layered coat hem must
read clearly at small scale. Soot-black and weathered parchment clothing with
muted copper hardware; only the held liquid uses saturated blue. Front
three-quarter design view, clean light background, generous separation between
poses, no labels or text.

Avoid: wizard staff, glowing hands, stars, robes covered in symbols, heroic
armor, oversized weapon, glamorous fashion pose, photorealism, anime, 3D render,
text, watermark.
```

### Enemy Concept

```text
2D raster enemy concept for CombatAlchemy, melancholic ink-wash dark fantasy,
invented syncretic folklore, charcoal silhouette and controlled paper texture.

A once-human observatory keeper altered by mineral bloom: hunched attentive
posture, one shoulder crusted with pale salt and translucent glass growth, a
dragging measuring chain, face partly erased by ink wash. The transformation
follows gravity and repeated work rather than random spikes. Include neutral,
approach, and attack silhouettes. One restrained lapis-blue residue line serves
as an alchemical clue. Clear readable anatomy and action at gameplay scale,
light neutral background, no gore, no text.

Avoid: zombie gore, body-horror close-up, generic demon horns, random crystals,
ornate armor, neon glow, muddy silhouette, photorealism, anime, watermark.
```

### Transparent Gameplay Sprite

```text
2D raster gameplay sprite for CombatAlchemy, top-down three-quarter view about
40 degrees above the ground, melancholic ink-wash dark fantasy, charcoal and
dry-brush rendering with selective clean edges.

The forbidden occult researcher in a clear idle stance facing lower right,
wearing an asymmetrical long coat, broad weathered hat, sample satchel, and small
glass harness. Compact readable silhouette, visible feet and contact point,
upper-left key light, no large cast shadow, no atmospheric background. Centered
on a square transparent canvas with 20 percent padding, clean alpha edge, no
cropping, no text. Keep equipment forms separated so they can be animated.

Avoid: front-facing portrait angle, side-view platformer pose, isometric grid,
photorealism, 3D render, anime, glow, particles, scenery, text, watermark.
```

### Laboratory Props and Reagent Containers

```text
2D raster prop sheet for CombatAlchemy, top-down three-quarter gameplay
perspective, melancholic ink-wash dark fantasy, hand-painted charcoal edges and
tactile worn materials.

Eight separated field-alchemy props: repaired round flask, narrow measuring vial,
ceramic mortar, folding brass filter, corked sample tube, stained notebook,
portable charcoal burner, and wrapped specimen jar. Each has a distinct
functional silhouette and plausible construction. Include one restrained
red-family sample, one green-family sample, and one blue-family sample; keep the
rest neutral. Upper-left light, consistent scale, transparent background, 15
percent padding around every object, no labels, no text, no shared cast shadow.

Avoid: identical recolored bottles, pristine glass, steampunk decoration without
function, neon liquid, photorealism, 3D render, clutter, text, watermark.
```

### Flask Interface Concept

```text
2D raster UI concept for CombatAlchemy, melancholic ink-wash dark fantasy,
restrained glass, charcoal, paper, and muted metal materials with selective
saturated reagent color.

A single compact flask interface designed for the bottom center of a 16:9 game
screen. The flask has a strong clean glass outline and three visibly separated
horizontal liquid bands from bottom upward. Three small reagent controls sit to
the right, each distinguished by shape and red, green, or blue color. No enclosing
card, no combat log, no recipe name, no decorative nested panels. Show closed,
layered, prepared, and rejected-mix visual states as four separated studies.
Neutral background for presentation, no final text or letters; functional text
will be built in-engine.

Avoid: fantasy hotbar, card layout, ornate frame, giant glowing buttons, rounded
mobile-game panels, dense instructions, neon full-frame palette, text, logo,
watermark.
```

### Potion Projectile and Impact Effects

```text
2D raster VFX concept sheet for CombatAlchemy, top-down three-quarter gameplay
view, ink-wash and liquid physics, transparent background, strong readable
silhouettes.

Two separated effect families shown as anticipation, travel, contact, and
consequence frames. Healing mixture: restrained violet-magenta liquid gathering
in rounded droplets, a compact thrown flask, upward suspended wash, warm value
return. Damage mixture: teal liquid with a sharper projectile edge, outward
corrosive brush splash, brief dark stain, clear value loss. Saturated cores fade
into desaturated ink edges. Minimal glass fragments, no persistent cloud, no
target character, consistent upper-left light, generous padding between frames,
no text.

Avoid: laser beams, generic fireballs, glowing glyphs, rune circles, huge
explosions, excessive sparkles, heavy bloom, opaque smoke covering the impact,
photorealism, 3D render, text, watermark.
```

## Asset Generation Checklist

Before accepting a generated image as a useful concept or production candidate,
check all applicable items:

- [ ] It matches pure 2D raster ink-wash rendering.
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

Establish one production-quality gameplay frame, one researcher target, the final
flask interaction language, and representative heal/damage reactions. Prove that
ink-wash atmosphere and mechanical readability can coexist before producing many
assets.

#### 2. Expand Potion Interactions and Combat Decisions

Add enough variation for observation, mixing, drinking, and throwing to create
different decisions. Prioritize rule clarity and target reaction over recipe
quantity.

#### 3. Build One Complete Expedition

Create one authored location with an entrance, readable navigation, material
clues, encounters, discoveries, and a return condition. Finish one coherent route
before multiplying biomes.

#### 4. Add the Refuge and Discovery Record

Give collected knowledge a place to persist, be reviewed, and suggest future
hypotheses. Build the record around actual discovery data after the mixing rules
are stable.

#### 5. Produce a Cohesive Vertical Slice

Connect menu, refuge, one expedition, potion combat, return, discovery, music,
settings, pause, and transitions into one presentable experience. Refine the
slice before expanding content breadth.

### Dependency Rules

- Lock a visual target before bulk asset generation.
- Prove a discovery rule before building a large recipe catalog.
- Complete one expedition before building several locations.
- Stabilize recorded discovery data before designing a large research interface.
- Add narrative consequences only after the actions that cause them are playable.
- Prefer one focused, playable interaction over broad supporting systems.

### Reject or Defer When

- the feature primarily adds another combat subsystem beside the flask;
- it requires constant logs or tutorial overlays to be understood;
- it expands recipes without adding meaningful deduction or decisions;
- it adds lore breadth before the player can interact with existing ideas;
- it depends on generic stat inflation as its main reward;
- it needs large content production before a small behavioral prototype can work;
- it makes alchemical color less consistent or less readable;
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

### Visuals

- [ ] Is the silhouette readable before the detail?
- [ ] Is the base palette restrained and the alchemical color intentional?
- [ ] Does the asset use the correct perspective and lighting?
- [ ] Is there enough negative space for gameplay clarity?
- [ ] Does the material wear tell a practical story?

### Interface and Feedback

- [ ] Is the flask still the central mixing interaction?
- [ ] Can cause and effect be understood without a combat log?
- [ ] Do color, motion, health response, and sound agree?
- [ ] Is functional text built in-engine rather than baked into art?

### Scope and Architecture

- [ ] Is this the smallest version that can test the idea?
- [ ] Does it fit the current component architecture?
- [ ] Is its supporting scope proportional to its player-facing value?
- [ ] Does it respect the explicit non-goals?

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
| **Mixture** | The ordered or counted set of layers before successful preparation. |
| **Recipe** | A valid combination and its resulting behavior. |
| **Prepared potion** | A successfully mixed potion ready to drink or throw. |
| **Reaction** | The readable visual, mechanical, and audio consequence of applying a potion. |
| **Observation** | A clue the player can notice but may not yet understand. |
| **Discovery** | Knowledge made reliable enough to record and reuse. |
| **Consequence** | A persistent or story-relevant trace left by research or potion use. |
| **Alchemy seal** | Abstract decorative measurement and orbital geometry, not a magical alphabet. |

Avoid using spell, chant, rune, cast, mana, or spellbook as active-system terms.
Use potion, mix, prepare, drink, throw, reagent, reaction, and discovery instead.

## Current Project Reference Boundaries

The current project contains useful fragments, not one complete production style.
Use each reference only for the qualities named below.

| File | Use as reference for | Do not inherit |
| --- | --- | --- |
| `sprites/mage_cliff_hell_yeah.png` | Mood-only reference for ink wash, paper texture, negative space, isolation, and distant mystery | The staff-bearing wizard pose, giant celestial ring, exact costume, or architecture as world canon |
| `mainmenu/AlchemySeal.tscn` | Slow decorative motion, restrained RGB marks, and abstract measurement geometry in the current menu | A magical alphabet, combat symbol system, or seal motif repeated across unrelated assets |
| `combat/ui/FlaskView.tscn` and `combat/ui/PotionMixerUI.tscn` | The flask-first interaction, visible liquid layers, and bottom-center composition | Placeholder geometry, button styling, or current dimensions as mandatory final art |
| `extra/ink_wash_shader_done.gdshader` | The current ink reveal transition language | A full-screen effect to apply continuously to gameplay or every asset |
| `docs/PROJECT_ARCHITECTURE.md` | Current technical ownership and implemented behavior | Creative or visual direction beyond its factual description |

The current actor sprites, placeholder arena, UI geometry, logo files, and unused
legacy assets are not automatic style targets merely because they remain in the
repository. When an existing asset conflicts with this document, retain only the
explicitly approved quality until a replacement is produced.

## Maintaining This Document

- Change this document deliberately when the creative north star changes.
- Update the vision version when design pillars, visual rules, or non-goals
  change materially.
- Keep prototype facts synchronized with `PROJECT_ARCHITECTURE.md` without
  duplicating its script-level reference.
- Record future direction as intention, not as implemented behavior.
- When an accepted asset establishes a better production rule, update the rule
  and examples rather than relying on unwritten precedent.
- When a roadmap proposal conflicts with this document, either reject the
  proposal or revise the vision explicitly. Do not quietly create two competing
  versions of CombatAlchemy.
