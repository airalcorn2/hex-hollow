# Hex Hollow

Hex Hollow is a small top-down Halloween adventure built with Godot. You play as a young witch exploring a haunted woodland, gathering enchanted ingredients, brewing a spell in the cauldron, and discovering what lies beyond the clearing.

The project is available at [github.com/airalcorn2/hex-hollow](https://github.com/airalcorn2/hex-hollow).

## Gameplay

The first level takes place in the Hollow: a moonlit woodland filled with ingredient pickups, companion witches, readable gravestones, lanterns, trees, signs, and a bubbling cauldron.

After completing the first spell, the witch can enter Level 2, the **Mooncorn Maze**. This level uses a static illustrated cornfield scene with three fall treats (a candy apple, a caramel corn ball, and candy corn) hidden along its paths. Once all three are gathered, the witch drops them into the bubbling cauldron in the lantern gate to finish the level. The title screen also includes **Practice the Mooncorn Maze**, which starts Level 2 directly with a fresh set of treats for testing.

The maze's **Wishing Well** (upper middle), **Lantern Tree** (center-left), and **Pumpkin Wagon** (right-hand clearing) offer optional witchy flavor text. Follow the gold **?** above each landmark, approach from the paths, and press **E / Space**. Repeated inspections cycle through different lines; these interactions do not consume treats or affect the harvest spell.

After the harvest spell, enter Level 3, **The Whispering Manor**: a haunted-house interior with six connected rooms, a portrait gallery, dining room, library, music parlor, kitchen and nursery. Gather four cursed keepsakes—a **silver key**, **music box**, **ghost candle** and **velvet ribbon**—then bring them to the bubbling cauldron in the foyer to brew an unhaunting spell. The title's **Practice the haunted house** button starts Level 3 directly.

The manor has **18 optional environmental interactions**, each with three rotating readings. Follow the fixed gold **?** pointers and press **E / Space** nearby. They reveal ghostly flavor text without awarding keepsakes or changing the spell; collectible and cauldron prompts take priority.

| Area | Objects to inspect |
| --- | --- |
| Dining room | The eternal supper and midnight sideboard |
| Portrait gallery | The watching portrait and haunted mirror |
| Library | Forbidden books, an unfinished letter, and the wandering globe |
| Music parlor | Phantom piano, haunted clock, fireplace, and vacant armchair |
| Kitchen | Haunted hearth and potion pantry |
| Nursery | Dollhouse, toy chest, rocking horse, and sleepy bed |
| North foyer | The antlered host above the hall |

The manor's object anchors, interaction ranges and dialogue live in `scripts/game/manor_interactions.gd`, separately from movement and collection logic.

Environmental **?** indicators in all three levels use fixed, object-specific anchors with small downward pointers. Violet, Amber, and Hazel keep their nameplates and **E / Space** dialogue, but do not have question-mark indicators.

Progress is stored locally so an unfinished spell, maze or manor run can be continued from the title screen, including when all collectibles are held but the cauldron spell has not been brewed. Completed earlier chapters offer continuation into the next chapter.

## Controls

- **WASD / Arrow keys** — Move the witch
- **E / Space** — Collect ingredients, deposit them, talk to witches, and inspect landmarks
- **Esc** — Pause or resume

The title screen provides the normal adventure entry point, saved-run continuation, and direct maze and haunted-house practice modes.

## Project layout

```text
assets/                 Game art, icons, fonts, and static backgrounds
scenes/main.tscn        Main Godot scene
scripts/entities/       Player entity and movement
scripts/game/           Woodland, Mooncorn Maze and haunted-house controllers
scripts/hollow_main.gd  Shared title, HUD, pause, save, and level flow
autoload/               Persistence, tuning, language, and cauldron integration
tools/hollow_check.gd   Native gameplay regression test
config/                 Runtime tuning configuration
web/                    Loading and web-export presentation
```

## Running locally

The GitHub distribution contains all game artwork, collision masks, fonts, import sidecars, and license notices. Install **Godot 4.7.2** (the tested version), then clone the repository:

```bash
git clone https://github.com/airalcorn2/hex-hollow.git
cd hex-hollow
```

Open `project.godot` in Godot and press **F6 / Run Current Scene** on `scenes/main.tscn`, or **F5 / Run Project**. Godot will rebuild its import cache automatically. No Manus account, asset hydration, Node.js, or Git LFS is required to play locally.

To open the project in Godot:

```bash
godot --editor --path .
```

To run the game directly:

```bash
godot --path .
```

The commands below are for development **inside a bound Manus project** with Node.js and its Game runtime installed; they are not required for a normal standalone Godot checkout:

```bash
npm run dev
npm run preview:build
npm run preview:status
```

### Keeping the portable GitHub version up to date

The managed project stores media separately from its own Git history. The GitHub distribution deliberately includes those files, including unused source artwork, so ordinary cloning stays self-contained. Caches (`.godot/`), build outputs, dependencies, and secrets are excluded.

After saving a verified managed release, sync it into a separate clean GitHub checkout rather than pushing the media-free source commit directly:

```bash
python3 tools/sync_portable_github.py \
  --repo-dir /absolute/path/to/hex-hollow-portable \
  --push
```

The sync command preserves GitHub's asset tracking and history, checks each asset against the saved manifest, and uses a normal non-force push. It stops on conflicts or unexpected asset edits. Omit `--push` to prepare a local version for inspection first. See `AGENTS.md` for the repository boundaries.

## Verification

Run the native gameplay regression test to verify all three chapters, movement, pause behavior, ordered ingredient collection, cauldron deposits, save restoration, spell completion, replay, chapter transitions, fall treats, haunted-house doorway traversal, walkable rugs and solid furniture, keepsakes, environmental dialogue, full-satchel continuation, and both practice modes:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --audio-driver Dummy --script tools/hollow_check.gd
```

Inside Manus, run the prepared project pack verification:

```bash
npm run check -- --pack
```

## Collision-mask helper

`tools/generate_collision_mask.py` is an offline assistive tool for turning a static top-down background into reviewable collision candidates. It resizes the image to world coordinates, detects high-frequency edges, applies an approximately `k × k` Gaussian blur, classifies pixels at or below one grayscale threshold as walkable, removes small mask specks with binary morphology, and derives coarse obstacle candidates from the inverse mask. It writes:

- JSON containing rectangles and four-point polygons
- A debug PNG with the candidate regions drawn over the background
- An optional binary walkable-space mask: white pixels are walkable and black pixels are obstacle candidates
- An optional grayscale Gaussian density field for tuning the threshold
- Optional Godot `PackedVector2Array` source

The output is intentionally not imported automatically. Review the walkable mask and density field first: paths, trees, pumpkins, and corn can all contain high-frequency detail, so the threshold still needs visual tuning.

Example:

```bash
python3 tools/generate_collision_mask.py \
  --image assets/corn-maze/corn_maze_ground.png \
  --output-json /tmp/corn-collisions.json \
  --output-preview /tmp/corn-collisions-preview.png \
  --output-pixel-mask /tmp/corn-walkable-mask.png \
  --output-density /tmp/corn-edge-density.png \
  --output-gdscript /tmp/corn-collisions.gd \
  --world-width 1216 \
  --world-height 832 \
  --cell-size 32 \
  --gaussian-kernel 21 \
  --walkable-threshold 54 \
  --cleanup-kernel 9 \
  --obstacle-occupancy 0.50 \
  --inset 5 \
  --min-area 1536
```

The helper requires Python with Pillow and NumPy. Its output should be adjusted or hand-authored before being used as authoritative gameplay collision.

All three levels sample reviewed pixel masks at runtime instead of approximating background scenery with rectangles. They share the small 12×10-pixel feet footprint, swept substeps and corner assistance. The cauldron and companion witches remain solid live props.

Regenerate the Hollow's mask with the same Gaussian and cleanup settings:

```bash
python3 tools/generate_collision_mask.py \
  --image assets/hollow/map.png \
  --world-width 1600 --world-height 1067 \
  --gaussian-kernel 21 --walkable-threshold 54 --cleanup-kernel 9 \
  --overrides config/collisions/hollow_mask_overrides.json \
  --output-json /tmp/hollow-candidates.json \
  --output-preview /tmp/hollow-candidates.png \
  --output-pixel-mask assets/hollow/hollow_walkable_mask.png \
  --output-density /tmp/hollow-density.png
```

The `--overrides` file contains reviewed world-pixel polygons and walkable circles applied to the raster mask after cleanup. These mark smooth pond water as blocked and the textured wooden bridge as walkable—the opposite of what edge density alone would infer. A **210-pixel-radius circle around the cauldron** also makes the entire central clearing and its decorative weed ring walkable; only the cauldron and companion witches remain solid there. These overrides do not create extra Godot collision rectangles. All other scenery uses the automatically generated mask. Older save positions that are now blocked are moved to nearby open ground while keeping ingredient and recipe progress.

Regenerate the haunted house's mask:

```bash
python3 tools/generate_collision_mask.py \
  --image assets/haunted-house/manor_ground.png \
  --world-width 1536 --world-height 1024 \
  --gaussian-kernel 21 --walkable-threshold 54 --cleanup-kernel 9 \
  --overrides config/collisions/manor_mask_overrides.json \
  --output-json /tmp/manor-candidates.json \
  --output-preview /tmp/manor-candidates.png \
  --output-pixel-mask assets/haunted-house/manor_walkable_mask.png
```

The manor's reviewed raster corrections preserve structural walls, keep the six illustrated doorway gaps open, and make decorative rugs and the foyer floor ornament walkable. `solid_polygons` are applied last so clearing a rug does not clear the table, piano, bed or rocking horse resting on it. These remain pixel-mask corrections, not rectangle-based physics.

Build the managed Preview export:

```bash
npm run preview:build
```

For a broader project check, use:

```bash
npm run verify
npm run verify:release
```

## Save data and integrations

Adventure progress is stored through the existing local save service. The cauldron bridge can notify the companion physical-cauldron project when the spell is completed; the game remains playable without that external hardware connection.

Existing woodland and maze bridge endpoints remain unchanged. Level 3 includes an **opt-in** `notify_house_event` hook, disabled by default. To wire up the physical prop, first implement `POST /house_event` on the Pi, then set `ENABLE_HAUNTED_HOUSE_EVENTS` to `true` in `autoload/cauldron_bridge.gd`. Payloads have `event` (`pickup`, `landmark`, or `victory`), with `keepsake` for pickups, or `landmark` and zero-based `line` for inspections. New keepsake IDs are never sent to the older `/deposit` or `/treat` endpoints.

## Contributing

Keep gameplay authority in the Godot world controllers and entity scripts. Presentation changes should not determine collisions, rewards, or progression. When changing gameplay, update `tools/hollow_check.gd` and run the native regression test before committing.

## License notes

The repository includes the inherited project/template license screen and its bundled notices. Review the notices and the source metadata for the applicable terms of individual assets before redistributing modified or extracted assets.
