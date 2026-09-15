# Animated 1920 x 1080 Main Menu Rebuild

> Date: 2026-09-12
> Status: Implemented; final visual tuning and manual resize review remain
> Scope: Start menu and inline main-menu settings only
> Architecture: [Project Architecture](../../PROJECT_ARCHITECTURE.md)
> Creative direction: [Style and Vision](../../STYLE_AND_VISION.md)

## Goal

Replace the painted-button start screen with the approved Field Notes layout:
a native pixel-art laboratory, dark command space at left, restrained grayscale
values, and saturated color limited to active reagent crystal deposits.

The permanent project canvas is `1920 x 1080`. The historical `640 x 360`
approval sample is composition reference only. This plan does not decide
gameplay composition, character dimensions, terrain scale, or flask dimensions.

## Delivered Structure

- `StartMenu.tscn` retains `LevelMusic` and instances only `MainMenu.tscn`.
- `MainMenuBackdrop.tscn` owns the native laboratory base and ambient layers.
- Two seamless cloud strips move right at 4 and 8 native pixels per second.
- Two foliage sprites use staggered four-frame 3.2-second loops.
- Three pinned notes use staggered four-frame 3.6-second loops plus authored sway.
- Three table and three smaller shelf deposits instance
  `ReactiveCrystalPile.tscn`, with staggered low-simmer motes and centralized
  Charged Neon palette colors.
- `MainMenuCommandButton.tscn` supplies scene-backed text commands, a left focus
  rule, hover/focus brightness, and two-pixel pressed displacement.
- `MainMenuSettingsView.tscn` replaces only the command list. The backdrop remains
  loaded and animated.
- `AudioStepControl.tscn` exposes ten visible steps for Music and SFX. Step zero
  maps to `-80 dB`; steps 1-10 map linear amplitudes `0.1-1.0` to decibels.
- `VersionStone.tscn` is an unframed version/build/current-focus text block.

## Preserved Contracts

- `GameManager.start_new_game()` and `quit_game()` remain the routing boundary.
- `SceneTransition.set_transition_duration()` and `is_busy()` retain duplicate-
  input blocking and transition timing.
- `Settings` continues to persist to `user://settings.cfg` and apply the Music
  and SFX buses immediately.
- `MusicManager` and StartMenu's `LevelMusic` request are unchanged.
- `mainmenu/Settings.tscn` and `SettingsMenu.gd` remain unchanged because the
  pause menu still owns that slider-based settings presentation.
- Combat, gameplay composition, and pause-menu presentation are out of scope.
- `PotionShatterParticles.tscn` is available for isolated VFX testing but is not
  integrated into active potion impact resolution in this pass.

## Retired Menu-Only Files

After reference validation, remove the procedural `AlchemySeal`, old main-menu
shader, old `MainMenuStyleData` resource, painted New Game/Settings/Quit button
textures, and their preview. Retain Back textures and the settings shader for
the pause menu. Retain `sprites/main_menu_alchemy.png` as historical mood art.

## Verification

- Run `tests/MainMenuTests.tscn` for parsing, focus, inline replacement, step
  clamping/conversion, transition locking, texture dimensions, alpha, and loops.
- Run all retained player and potion test scenes.
- Smoke-test `StartMenu.tscn`, `CombatScene.tscn`, and the registered project.
- Confirm menu music, New Game routing, Quit, Back/Escape, immediate audio
  persistence, and continued backdrop animation while Settings is open.
- Inspect at `1920 x 1080` and smaller/wider windows for overlap and clipping.
- Run `git diff --check` and verify no references remain to retired menu files.
