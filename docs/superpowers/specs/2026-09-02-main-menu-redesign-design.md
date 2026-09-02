# CombatAlchemy — Main Menu Redesign Design Spec

**Date:** 2026-09-02  
**Status:** Approved design direction  
**Branch:** `Mainmenuuiremake`  
**Scope:** Main menu presentation, interaction shell, settings presentation inside the main menu, and transition behavior.  

## 1. Purpose

Replace the current texture-button main menu with a diegetic scene that establishes CombatAlchemy's final visual identity immediately: a near-monochrome noir world in which alchemy is the primary source of saturated color.

The menu must feel like a real place in the game world rather than a conventional UI screen. It should remain technically isolated from gameplay systems and continue to use the existing application-shell services for scene routing, settings persistence, music, and transitions.

## 2. Core Design Statement

> A dark laboratory corner on the floor beside a floor-to-ceiling window during a thunderstorm. The room is almost black. A single candle is the main interior light source. An open research journal begins the expedition. Tall glass measuring vessels control audio by changing their liquid levels. Extinguishing the candle makes the screen go completely black and exits the game. The world is monochrome; alchemical substances are sparse, intensely luminous neon color.

## 3. Visual Identity

### 3.1 World rendering

The main menu uses a high-contrast noir / graphic-novel language:

- near-monochrome black, white, charcoal, and limited gray values;
- deep blacks and strong silhouette separation;
- hard directional light with controlled soft falloff from the candle;
- gritty ink / charcoal / weathered-material texture rather than glossy rendering;
- no general-purpose fantasy glow;
- no colorful environment lighting;
- no modern floating panels or beveled menu buttons.

The scene should read even when temporarily viewed in pure grayscale.

### 3.2 Color rule

Color is semantic:

> **Color belongs to alchemy, not to interface chrome.**

The menu is predominantly monochrome. Saturated color is reserved for reagents and traces of reagents.

Initial menu accents:

- dominant reagent accent: extremely bright neon cyan-blue;
- rare secondary accent: a few luminous red droplets in the lower-right floor area;
- both colors may appear almost self-luminous against the monochrome scene;
- color must remain sparse enough that every colored mark feels chemically important.

UI hover states must not introduce neon colors.

### 3.3 Light

The candle is the only persistent interior key light.

It provides:

- the main local illumination on the journal and nearby floor;
- highlights on the glass settings vessels;
- local reflections on wet / polished surfaces;
- a visible reflection in the window, especially toward the upper-right portion of the composition;
- subtle flicker in nearby shadow values.

Lightning outside is an environmental event, not a second permanent light source. A lightning flash may briefly reveal more of the room and window frame, then return the scene to candle-dominated darkness.

## 4. Scene Composition

### 4.1 Camera

- Perspective: top-down three-quarter view, approximately the same visual perspective previously approved for the research-desk concept.
- Baseline composition: 1920×1080 / 16:9.
- The camera should feel close and intimate rather than like a full-room establishing shot.

### 4.2 Location

Everything is located directly on the floor in the corner of the room.

The window:

- reaches to or almost to the floor;
- wraps the upper/right composition as the defining architectural element;
- shows a storm outside;
- carries visible rain droplets and running water streaks;
- reflects the candle flame and selected nearby highlights.

The room beyond the menu objects should mostly disappear into black.

### 4.3 Focal hierarchy

1. **Research Journal** — central / primary focal point.
2. **Settings Flasks** — grouped vertical glass forms to the left or upper-left of the journal.
3. **Candle** — right side near the window, visually important because it creates the light.
4. **Title / handwritten annotations** — readable but secondary to the physical objects.
5. **Version plaque** — small service element in the lower-left corner.
6. **Neon reagent traces** — sparse environmental storytelling, never competing with the journal.

### 4.4 Environmental details

Allowed supporting clutter:

- loose scientific notes;
- alchemical diagrams;
- mortar / small bottles;
- ink stains;
- reagent residue;
- small tools;
- cloth or paper scraps.

Supporting clutter must not resemble additional clickable actions.

## 5. Main Menu Actions

The MVP contains exactly three primary actions.

### 5.1 Research Journal → Begin Expedition

The journal is an open or actively used research journal containing scientific notes, diagrams, vessel sketches, measurements, and observations.

Annotation:

`Begin Expedition`

Behavior:

1. Pointer enters journal interaction region.
2. Journal receives subtle white ink contour + local light isolation.
3. `Begin Expedition` annotation becomes visible.
4. Click locks the other menu interactables.
5. A short scientific-notes transition begins: restrained page motion / page turn / ink movement, approximately 1.2–1.8 s maximum.
6. Existing `SceneTransition` performs the final transition.
7. `GameManager.start_new_game()` remains the routing contract.

The journal must not contain a separate confirmation screen for MVP.

### 5.2 Settings Flasks → Adjust Instruments

Settings are represented by a physical rack of tall glass measuring vessels / graduated cylinders rather than a separate panel.

Annotation:

`Adjust Instruments`

The visual metaphor is direct: audio volume is the liquid level.

MVP controls:

- one principal tall vessel for **Music**;
- one principal tall vessel for **Effects / SFX**;
- optional secondary glassware may exist for composition, but only the two principal vessels are interactive;
- labels are engraved / handwritten and monochrome;
- the reagent liquid may use the approved neon cyan-blue accent;
- changing a value visibly raises or lowers the liquid surface.

Primary mouse interaction:

- click-drag vertically inside the vessel;
- upward drag raises the liquid level / volume;
- downward drag lowers the liquid level / volume;
- the value updates continuously while dragging.

Behavior contract:

- Music vessel delegates to `Settings.set_music_db()`;
- Effects vessel delegates to `Settings.set_sfx_db()`;
- persistence remains owned by the existing `Settings` autoload;
- the vessel component must not directly manage config files or AudioServer buses.

Settings mode should locally emphasize the glassware and slightly suppress surrounding scene contrast without opening a modern overlay.

Return behavior for MVP:

- a small physical stopcock / lever integrated into the flask rack acts as `Return`;
- activating it restores normal main-menu state;
- this preserves the previously approved principle that settings exit is a physical part of the apparatus.

### 5.3 Candle → Leave

The candle is the quit control.

Annotation:

`Leave`

Behavior:

1. Pointer hover produces the same monochrome interaction feedback as other interactables.
2. Click immediately locks the rest of the menu.
3. Flame shrinks and extinguishes.
4. A small smoke wisp may remain briefly.
5. Because the candle is the scene's only persistent interior light, the scene falls into full black.
6. Only after the image reaches black, call `GameManager.quit_game()`.

Target duration: approximately 0.5–0.8 s.

No confirmation dialog in MVP.

## 6. Interaction Language

### 6.1 Input scope

First implementation target is **mouse only**.

Keyboard and gamepad focus navigation are explicitly deferred, but the interaction code must not be structured in a way that prevents adding them later.

### 6.2 Hover feedback

Approved hover style: **combined monochrome feedback**.

On pointer hover:

- subtle imperfect white / gray ink contour;
- small local lift in value / candle exposure;
- immediate surroundings may darken slightly;
- handwritten annotation appears;
- no scaling, bouncing, neon outline, or generic glow.

Target hover transition: 120–180 ms.  
Target annotation reveal: 150–220 ms.

### 6.3 Annotation language

Use diegetic action wording rather than conventional menu labels:

- `Begin Expedition`
- `Adjust Instruments`
- `Leave`
- `Return`

Annotations should appear as ink / chalk / hand-written marks integrated with the scene, not tooltip boxes.

## 7. Atmospheric Animation

The menu uses restrained atmospheric idle animation.

Required / preferred elements:

- candle flame motion;
- subtle candle smoke;
- light flicker on immediate surfaces;
- rain droplets / streaks on the window;
- storm movement outside;
- occasional lightning flash;
- tiny movement / shimmer in the cyan reagent liquid;
- very small window reflection response to flame and lightning.

Avoid:

- constant large moving particles;
- rotating magical seals;
- continuous screen-wide shader spectacle;
- idle movement of the journal solely to attract attention.

## 8. Service Information

A small plaque remains in the bottom-left corner.

It should read project metadata from the existing project-info resource rather than duplicate hard-coded values where practical.

Current example content:

- `Version 0.2.1`
- `Prototype`
- `First game loop`

The plaque is non-interactive and visually subordinate.

## 9. Title Treatment

`COMBATALCHEMY` appears as a monochrome title integrated into the dark scene.

Rules:

- high-contrast white / light gray treatment;
- rough ink / brush / graphic-novel character;
- no neon title glow;
- title must not compete with the journal as the interaction focal point.

Any tagline is optional presentation content and not required for MVP functionality.

## 10. Scene Architecture

The earlier `ResearchDesk` naming is superseded by this floor-corner composition.

Recommended structure:

```text
mainmenu/
├── StartMenu.tscn
├── LaboratoryCorner.tscn
├── LaboratoryCorner.gd
│
├── interactables/
│   ├── DiegeticInteractable.gd
│   ├── ResearchJournal.tscn
│   ├── ResearchJournal.gd
│   ├── SettingsFlasks.tscn
│   ├── SettingsFlasks.gd
│   ├── ExitCandle.tscn
│   └── ExitCandle.gd
│
├── settings/
│   ├── LiquidLevelControl.tscn
│   ├── LiquidLevelControl.gd
│   └── SettingsBinding.gd
│
└── components/
    ├── InkAnnotation.tscn
    └── VersionPlaque.tscn
```

`StartMenu.tscn` remains the composition root / entry scene unless implementation proves a small rename is materially cleaner.

### 10.1 Shared interactable contract

`DiegeticInteractable` owns only reusable pointer interaction behavior:

```text
hover_enter
hover_exit
activate
enabled / disabled
annotation visibility
hover visual state
```

It must not know what action a concrete object performs.

### 10.2 Specialized objects

- `ResearchJournal` owns expedition-start presentation and delegates routing to `GameManager`.
- `SettingsFlasks` owns settings-mode presentation and delegates values through `SettingsBinding`.
- `ExitCandle` owns extinguish presentation and delegates quitting to `GameManager`.

### 10.3 Screen-level state

`LaboratoryCorner.gd` orchestrates only scene-level state.

Recommended states:

```text
IDLE
SETTINGS
STARTING_EXPEDITION
EXITING
```

It must not contain hard-coded implementation details for every child control.

## 11. Existing Systems to Preserve

Do not rewrite the application shell as part of the menu redesign.

Preserve these contracts:

- `GameManager.start_new_game()`
- `GameManager.go_to_main_menu()`
- `GameManager.quit_game()`
- `SceneTransition`
- `Settings.set_music_db()`
- `Settings.set_sfx_db()`
- Settings persistence in `user://settings.cfg`
- `MusicManager` / existing menu music integration
- scene registry routing

The redesign is a presentation-layer replacement, not a gameplay architecture rewrite.

## 12. Responsive Layout Rules

Baseline artwork may target 1920×1080, but the implementation must not depend on one hard-coded pixel layout.

Rules:

- preserve the Journal / Flasks / Candle triangle as the safe composition core;
- background / window art may crop at edges to fit aspect ratio;
- interaction bounds follow the physical objects;
- ultrawide may reveal more darkness / window / floor rather than stretching the art;
- narrower aspect ratios may crop decorative clutter before cropping interactive objects;
- avoid the old pattern of hard-sized 1920×1080 controls plus arbitrary `scale = 0.75` as the primary layout mechanism.

## 13. Asset Production List

Minimum visual assets / layers expected for implementation:

### Environment

- laboratory-corner base background;
- floor texture / shadow layer;
- floor-to-ceiling window / frame layer;
- storm exterior layer or animation source;
- window rain / droplet layer;
- lightning flash mask / illumination layer;
- candle reflection layer or reflection mask.

### Journal

- journal base / open pages;
- scientific notes page art;
- optional page-turn layer(s);
- journal hover contour / mask;
- interaction region.

### Settings flasks

- rack / holder base;
- two principal graduated vessels;
- vessel glass overlays / highlights;
- two independent liquid masks / fill layers;
- measurement marks;
- return stopcock / lever;
- hover contour / masks.

### Candle

- candle / holder base;
- flame animation;
- local light / illumination mask;
- smoke frames or particle texture;
- extinguish state;
- hover contour / mask.

### Color accents

- cyan reagent stains / droplets;
- small cyan liquid accents in glassware;
- sparse red droplets in lower-right composition.

### UI presentation

- CombatAlchemy title treatment;
- ink annotation style / reusable annotation marks;
- bottom-left version plaque.

## 14. Audio / Atmosphere

Optional but strongly aligned with the scene:

- rain loop;
- low storm ambience;
- infrequent thunder;
- small candle / room tone;
- subtle glass interaction sound when entering settings;
- restrained liquid movement sound while adjusting volume;
- candle extinguish sound on exit;
- page movement / paper sound on Begin Expedition.

Audio must remain subdued and should not turn the menu into a cinematic intro sequence every time it opens.

## 15. MVP Boundaries / Non-Goals

Do **not** add during this implementation unless separately approved:

- Continue;
- save-slot selection;
- Credits;
- difficulty selection;
- expedition selection;
- graphics settings;
- resolution settings;
- control rebinding;
- accessibility page;
- keyboard/gamepad menu navigation;
- reagent inventory UI redesign;
- combat HUD redesign;
- Pause Menu visual redesign;
- gameplay system changes;
- large universal UI framework.

The current task is the main menu and its Music/SFX presentation only.

## 16. Minimal Verification Requirements

Implementation should include lightweight retained verification rather than a large UI-test framework.

At minimum verify:

1. Start menu instantiates without errors in headless / test-compatible context where practical.
2. Journal activation delegates to the existing new-game routing contract exactly once.
3. Music liquid control reaches `Settings.set_music_db()`.
4. SFX liquid control reaches `Settings.set_sfx_db()`.
5. Candle activation enters `EXITING` and calls quit only after the blackout sequence completes.
6. Interactions are disabled while `STARTING_EXPEDITION` or `EXITING` is active.
7. Missing optional atmospheric assets do not prevent the menu from loading during incremental production.

Manual GUI verification is still required for visual composition, hover regions, liquid drag feel, rain readability, candle-light balance, and aspect-ratio behavior.

## 17. Acceptance Criteria

The redesign is considered visually and functionally complete when:

- the first screen communicates CombatAlchemy's monochrome-noir / neon-alchemy identity without explanation;
- the journal is clearly the primary action without looking like a conventional button;
- Music and Effects can be changed by manipulating visible liquid levels in tall glass vessels;
- the candle clearly reads as a physical scene object and successfully performs the full extinguish → black → quit sequence;
- rain and droplets are visible on the floor-to-ceiling window;
- candle reflection is visible in the window;
- cyan reagent traces are vivid but sparse;
- a small number of red droplets appear in the lower-right area;
- the version/build plaque is present in the lower-left;
- the menu does not introduce neon hover UI or modern panels;
- existing `GameManager`, `Settings`, `SceneTransition`, music, and persistence contracts continue to work;
- main-menu implementation is no longer tightly dependent on paths equivalent to `UI/FlowContainer/HFlowContainer/NewGame`.

## 18. Production Principle

When choosing between extra atmosphere and reliable interaction, reliable interaction wins.

When choosing between more colored decoration and preserving the meaning of alchemical color, preserve the meaning of color.

When choosing between a new framework and a small component that solves the real menu requirement, use the small component.
