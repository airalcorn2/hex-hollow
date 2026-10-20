# Hex Hollow

Approved blueprint: top-down 2D exploration inspired by SNES Zelda, a witch collecting ingredients and depositing them in a cauldron to complete a spell. English only. Standard effort, original AI-generated visuals, no concept mockups or online features.

## Implementation
Extend the initialized Godot Generic starter, replacing its reference maze with a compact Halloween woodland. Preserve its font theme, input actions, save service, license screen, asset pipeline, loading mechanics, and managed export. Author gameplay in `scripts/game/hollow_world.gd`, witch locomotion in `scripts/entities/witch.gd`, and menu/HUD flow in `scripts/hollow_main.gd`. A world SubViewport with a follow camera keeps the map separate from the fixed recipe sidebar. Native simulation owns movement, collision, collection, deposit and the spell outcome; visuals only present those states.

Six ingredients occupy clear reachable parts of the Halloween map: mooncap mushroom, ember pumpkin, old skull, raven feather, ghost essence, and moonflower. Walk close to an ingredient and press E/Space to gather it; return to the central cauldron and press E/Space to deposit the satchel. There is no combat or countdown. Show recipe progress, clear interaction prompts, pause/resume, completion and replay. Saves retain an in-progress recipe locally.

## Design
The user's SNES Zelda reference defines the aesthetic: crisp 16-bit pixel-art fantasy with a cozy Halloween mood. Midnight plum and teal foliage contrasts with amber pumpkins, cream text and mint magic. A framed woodland viewport sits beside a spellbook-like dark recipe panel. Live typography uses the starter's bundled display and body fonts. Distinctive motifs are a crooked witch hat, bubbling green cauldron, and amber/teal ingredient glows. Animations use directional walking frames, small pickup floats and a restrained completed-spell burst. Voice is playful and concise: “A little mischief. A little magic.” and “Into the cauldron.”

## Project structure
- `scripts/hollow_main.gd`: title, start/continue, HUD, pause, results and replay.
- `scripts/game/hollow_world.gd`: world rendering, interaction, ingredients, recipe state and collision shapes.
- `scripts/entities/witch.gd`: movement, directional animation and player collision.
- `assets/hollow/`, `assets/witch/`, `assets/recipe/`, `assets/share/`: generated environment, frames, ingredient art and sharing art.
- `web/loading.html`: customized recoverable loader.
- `tools/`: bounded native capture and core-loop check, excluded from release.

Static managed Web export uses the configured `true` build and `site` output; no server or database is needed.
