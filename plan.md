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

## Level 3 — The Whispering Manor

The third chapter follows completion of the Mooncorn Maze and takes place inside a roofless, top-down illustrated haunted house. Keep the same original 16-bit Halloween art direction, witch locomotion, E / Space interactions, fixed HUD, pause/resume and local saves. Wide connected halls and doorways join six furnished rooms: dining room, portrait gallery, library, music parlor, kitchen and nursery. Collect four cursed keepsakes (silver key, music box, ghost candle and velvet ribbon), then return them to a bubbling cauldron in the foyer to finish an unhaunting spell. There is no combat or countdown. Optional fixed, precisely anchored environmental indicators reveal playful haunted-house flavor text. Rugs and decorative floor details remain walkable; structural walls and substantial furniture do not.

Add `scripts/game/haunted_house.gd` for the third chapter, original room art and keepsake icons in `assets/haunted-house/`, and a reproducible Gaussian walkable mask with reviewed architectural corrections under `config/collisions/`. Extend `scripts/hollow_main.gd` with the Level 2-to-3 transition, third-level HUD and completion, save restoration and a direct practice shortcut. Keep earlier levels and physical cauldron integrations intact; any new third-level bridge events must use an optional extension boundary rather than send unfamiliar ingredient IDs to the existing deposit endpoints. Continue saving verified managed releases and synchronize the asset-complete GitHub distribution through the existing portable sync tool.
