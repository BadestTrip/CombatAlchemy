# Deprecated player presentation

Archived 2026-11-17 when Researcher 01 became the active player presentation.
Original relative directories are preserved beneath this folder.

- `characters/player/`: retired skeletal model, its script/UID and locomotion
  library, former model guide, and the old 32x48 direct/fullwidth sprite experiments.
- `sprites/characters/`: unused old mage placeholder with import settings.
- `tests/PlayerModelTests.gd`: former bone-specific assertions, kept for reference.
- `player_migration_manifest.json`: original paths, archive paths and hashes.

`.gdignore` keeps all archived files out of active Godot scanning/export. No active
scene/script/resource depends on this folder. The archived model scene's two
external resource paths were adjusted to its archived script/library; other
archived content is retained. Old PNG .import records are historical metadata and
will need reimporting if restored. This is a reference archive, not a second runtime.

Restore intentionally into a separate working directory or remove .gdignore and
reimport before examining archived scenes. Do not overwrite active PlayerModel
files without also restoring the matching consumers/tests. The current public
model scene/script paths remain stable and now implement sprite playback.

The `overworld_character_TRUE_TRANSPARENT.png` image is still used by Friend and
Pursuer, so it is not a retired hero dependency and remains in the active sprites folder.
