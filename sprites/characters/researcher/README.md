# Researcher Cutout Asset

This folder contains the current articulated Player artwork. It is a detailed
prototype skin for the reusable humanoid rig, not a final locked character
design.

Technical source of truth:

- `../../../characters/animation/HumanoidCutoutRig.tscn`: generic skeleton,
  playback graph, sockets, and placeholder geometry.
- `../../../characters/animation/ResearcherCutoutRig.tscn`: inherited
  researcher skin and all atlas regions, pivots, scales, and visual layers.
- `../../../characters/animation/HumanoidAnimationLibrary.tres`: shared clips,
  coat motion, and action events.
- `../../../experiments/character_animation/README.md`: rigging and playback
  workflow.

## Files

| File | Contents |
| --- | --- |
| `researcher_core.png` | Hat, head/scarf, torso, chest equipment, pelvis/belt, and satchel |
| `researcher_arms.png` | Paired upper arms, forearms, and gloved hands |
| `researcher_legs.png` | Paired thighs, shins, and boots |
| `researcher_coat.png` | Left, center, and right articulated coat-tail panels |
| `../../../docs/ART_REF_G06_RESEARCHER_CUTOUT_TARGET.png` | Approved neutral model and costume target |

All four atlases are 1254 x 1254 RGBA PNG files. Their four corner pixels are
fully transparent. The source generation used a flat `#ff00ff` background,
then soft-matte chroma removal and despill. The generated source plates are not
stored in the project.

Do not crop these atlases into duplicate files. The rig uses `AtlasTexture`
regions so every cutout remains editable from one source sheet.

## Approved Visual Target

The approved target is a one-view front/top-down three-quarter researcher in a
neutral A-pose. The final skin preserves:

- a broad worn hat and obscured face;
- a long weathered dark coat;
- practical gloves and boots;
- repaired chest glassware and copper fittings;
- an expedition satchel and field notebook;
- empty hands, because the active potion is a separate runtime prop.

Horizontal mirroring supplies the second facing direction. A back view requires
a separate visual set.

## Atlas Regions And Rig Placement

`Rect2` values are source-pixel regions. `Pivot` is measured inside the region
unless noted otherwise. Each `Sprite2D` remains at local `Vector2.ZERO` and
uses:

```text
offset = region_size / 2 - pivot
```

This places the documented source pivot at its controlling bone origin.

| Part | Atlas | Rect2 | Parent bone | Scale | Pivot px | Z |
| --- | --- | --- | --- | ---: | --- | ---: |
| Hat | Core | `(40, 168, 425, 308)` | `Head` | 0.170 | `(212.5, 216)` | 4 |
| Head/scarf | Core | `(489, 105, 281, 416)` | `Head` | 0.145 | `(140.5, 190)` | 4 |
| Torso coat | Core | `(840, 97, 375, 471)` | `Spine` | 0.160 | `(188, 100)` | 2 |
| Chest equipment | Core | `(46, 636, 369, 457)` | `Spine` | 0.140 | `(184.5, 100)` | 5 |
| Pelvis/belt | Core | `(457, 741, 347, 347)` | `Root` | 0.150 | `(173.5, 80)` | 2 |
| Satchel | Core | `(874, 703, 353, 407)` | `Spine` | 0.105 | `(-190.5, -238.1)` | 5 |
| Upper arm L | Arms | `(327, 44, 169, 487)` | `UpperArm_L` | 0.095 | `(84.5, 40)` | 1 |
| Upper arm R | Arms | `(755, 44, 169, 488)` | `UpperArm_R` | 0.095 | `(84.5, 40)` | 3 |
| Forearm L | Arms | `(353, 575, 131, 299)` | `Forearm_L` | 0.125 | `(65.5, 30)` | 1 |
| Forearm R | Arms | `(760, 575, 131, 299)` | `Forearm_R` | 0.125 | `(65.5, 30)` | 3 |
| Hand L | Arms | `(358, 922, 152, 276)` | `Hand_L` | 0.080 | `(76, 38)` | 1 |
| Hand R | Arms | `(731, 922, 154, 276)` | `Hand_R` | 0.080 | `(77, 38)` | 3 |
| Thigh L | Legs | `(329, 38, 184, 378)` | `Thigh_L` | 0.130 | `(92, 35)` | 1 |
| Thigh R | Legs | `(746, 42, 176, 373)` | `Thigh_R` | 0.130 | `(88, 35)` | 3 |
| Shin L | Legs | `(342, 462, 133, 314)` | `Shin_L` | 0.140 | `(66.5, 28)` | 1 |
| Shin R | Legs | `(770, 467, 135, 309)` | `Shin_R` | 0.140 | `(67.5, 28)` | 3 |
| Boot L | Legs | `(278, 824, 182, 337)` | `Foot_L` | 0.090 | `(91, 28)` | 1 |
| Boot R | Legs | `(785, 833, 148, 353)` | `Foot_R` | 0.090 | `(74, 28)` | 3 |
| Coat tail L | Coat | `(63, 228, 294, 866)` | `CoatTail_L` | 0.095 | `(147, 40)` | 0 |
| Coat tail C | Coat | `(434, 148, 420, 962)` | `CoatTail_C` | 0.095 | `(210, 40)` | 0 |
| Coat tail R | Coat | `(903, 251, 290, 820)` | `CoatTail_R` | 0.095 | `(145, 40)` | 0 |

The satchel pivot is intentionally outside its crop. It represents a strap
attachment above and left of the visible bag while keeping the `Sprite2D`
itself at the `Spine` origin.

The researcher skin moves the shoulder origins from generic `x = +/-31` to
`x = +/-27`. This closes the painted shoulder seams without changing the
generic rig or any animation track path.

## Layer Contract

Use only nonnegative visual layers:

| Layer | Use |
| ---: | --- |
| 0 | Rear coat panels |
| 1 | Rear arm and leg |
| 2 | Pelvis and torso |
| 3 | Front arm and leg |
| 4 | Head and hat |
| 5 | Chest equipment and satchel |
| 12 | Runtime held flask |
| 20 | Optional bone debug lines |

The inherited skin hides every placeholder `Polygon2D`; it does not delete
them. The generic rig therefore remains useful as a structural template.

## Joint Overlap

Every limb crop includes source pixels beyond the visible joint seam. Preserve
that hidden overlap when repainting:

- upper arms overlap shoulders and elbows;
- forearms overlap elbows and wrists;
- hands overlap wrists;
- thighs overlap hips and knees;
- shins overlap knees and ankles;
- boots overlap ankles;
- coat panels overlap beneath the belt and each other.

Do not move a bone to compensate for transparent padding until the sprite pivot
has been checked. Do not bake the held flask into a hand texture.

## Generation Prompts

The prompts below are retained so future revisions can preserve costume and
part separation. Generated output still requires human review, alpha cleanup,
region measurement, pivoting, and in-engine animation checks.

### Neutral target

```text
Create one detailed forbidden occult field researcher for a pure 2D raster
skeletal cutout game. Match the CombatAlchemy researcher references: broad
weathered hat, face obscured by shadow and scarf, long asymmetrical dark coat,
repaired chest glassware, copper fittings, sample satchel, field notebook,
gloves, and practical boots. Show one full-body elevated top-down
three-quarter view in a neutral mild A-pose, with both arms separated from the
torso and both legs separated enough to expose every future joint. Both hands
are empty. Preserve consistent upper-left lighting, strong gameplay
silhouette, charcoal and ink-wash texture, restrained parchment highlights,
and deliberate wear. Use a perfectly flat solid #ff00ff background. No floor,
shadow, text, labels, grid, watermark, runes, spellcasting, weapon, potion,
glossy 3D, anime rendering, or cropped body parts.
```

### Core atlas

```text
Create a production reference atlas of ONLY six separate core costume parts
for the approved forbidden occult researcher, preserving the exact approved
design, top-down three-quarter perspective, dark ink-wash material, proportions,
and upper-left lighting. Arrange a clean 3-column by 2-row atlas on a perfectly
flat solid #ff00ff background: top-left broad hat; top-center head, hair, face
shadow, and scarf; top-right torso coat with collar and shoulder overlap;
bottom-left chest harness and repaired glass apparatus; bottom-center
pelvis, belt, and short waistcoat section; bottom-right satchel and attached
field notebook. Keep every group isolated with generous magenta spacing.
Include hidden seam overlap where the head meets the torso and torso meets the
pelvis. No limbs, full body, complete character, labels, grid lines, floor,
cast shadows, text, watermark, runes, potion in either hand, or bright magenta
inside the parts. Crisp cutout-ready edges and readable gameplay-scale detail.
```

### Arms atlas

```text
Create a production reference atlas of ONLY six separate articulated arm parts
for the approved forbidden occult researcher character, preserving exactly the
same dark ink-wash costume, weathered fabric, black leather gloves, proportions,
upper-left lighting, muted charcoal and parchment palette, and elevated
top-down three-quarter gameplay perspective seen in the reference. Arrange a
clean 2-column by 3-row atlas on a perfectly flat solid #ff00ff chroma
background: top row = left upper arm, right upper arm; middle row = left
forearm, right forearm; bottom row = left gloved hand, right gloved hand. Each
part must be isolated with generous empty magenta spacing and must not touch
any other part. Orient every limb segment vertically with its proximal joint
seam at the top and distal joint seam at the bottom. Include 12-18 percent
hidden overlap beyond shoulder, elbow, and wrist seams for skeletal cutout
animation. Match left/right sleeve construction consistently but preserve the
approved asymmetric costume details. Hands are empty, relaxed, and suitable
for an A-pose. No torso, head, full arms, labels, grid lines, cast shadows,
floor, text, watermark, decorative border, runes, potion, or bright magenta
within the character parts. Crisp readable silhouettes, restrained detail at
gameplay scale, clean cutout-ready edges, 1:1 square atlas.
```

### Legs atlas

```text
Create a production reference atlas of ONLY six separate articulated leg parts
for the approved forbidden occult researcher character, preserving exactly the
same dark ink-wash costume, weathered trousers, sturdy black field boots,
proportions, upper-left lighting, muted charcoal and parchment palette, and
elevated top-down three-quarter gameplay perspective seen in the reference.
Arrange a clean 2-column by 3-row atlas on a perfectly flat solid #ff00ff
chroma background: top row = left thigh, right thigh; middle row = left
shin/lower trouser leg, right shin/lower trouser leg; bottom row = left boot,
right boot. Each part must be isolated with generous empty magenta spacing and
must not touch any other part. Orient every leg segment vertically with its
proximal joint seam at the top and distal joint seam at the bottom; boots point
slightly downward in the same neutral A-pose perspective. Include 12-18
percent hidden overlap beyond hip, knee, and ankle seams for skeletal cutout
animation. Match left/right construction consistently while preserving subtle
approved asymmetry and wear. No pelvis, torso, complete legs, coat tails,
labels, grid lines, cast shadows, floor, text, watermark, decorative border,
runes, potion, or bright magenta within the character parts. Crisp readable
silhouettes, restrained detail at gameplay scale, clean cutout-ready edges,
1:1 square atlas.
```

### Coat atlas

```text
Create a production reference atlas of ONLY three separate long coat-tail
panels for the approved forbidden occult researcher character, preserving
exactly the same dark ink-wash weathered coat fabric, torn dry-brush hems,
proportions, upper-left lighting, muted charcoal and parchment palette, and
elevated top-down three-quarter gameplay perspective seen in the reference.
Arrange three isolated vertical panels in a single horizontal row on a
perfectly flat solid #ff00ff chroma background: left coat tail, center coat
tail, right coat tail. Each panel must be fully separate with generous empty
magenta spacing and must not touch another panel. Give every panel a clean
hidden upper seam extension of 12-18 percent for attachment beneath the
torso/pelvis. Preserve intentional asymmetry: left panel about 76 units
relative length with slight outward fall, center panel longest at about 84
units, right panel about 72 units with slight opposite fall. The panels should
overlap convincingly when assembled but remain isolated in this atlas. No
torso, belt, limbs, person, labels, grid lines, cast shadows, floor, text,
watermark, decorative border, runes, potion, or bright magenta within the
parts. Crisp readable silhouettes, restrained detail at gameplay scale, clean
cutout-ready edges, 1:1 square atlas.
```

## Validation

Before replacing or regenerating a sheet:

1. Confirm all expected parts exist once and remain fully separated.
2. Confirm transparent corners and no magenta fringe at joints or torn hems.
3. Keep the current atlas regions stable, or update every affected
   `AtlasTexture`.
4. Recalculate pivots before changing bones.
5. Inspect idle, walk, drink, throw, hit, and mirrored playback in
   `CharacterAnimationLab.tscn`.
6. Confirm the held flask follows `HandSocket_R` and disappears at the
   existing action event.
7. Run `tests/CharacterAnimationRigTests.tscn`,
   `tests/PlayerAnimationControllerTests.tscn`, and
   `tests/PotionActionTimingTests.tscn`.
