# Hex Hollow

Hex Hollow is a small top-down Halloween adventure built with Godot. You play as a young witch exploring a haunted woodland, gathering enchanted ingredients, brewing a spell in the cauldron, and discovering what lies beyond the clearing.

The project is available at [github.com/airalcorn2/hex-hollow](https://github.com/airalcorn2/hex-hollow).

## Gameplay

The first level takes place in the Hollow: a moonlit woodland filled with ingredient pickups, companion witches, readable gravestones, lanterns, trees, signs, and a bubbling cauldron.

After completing the first spell, the witch can enter Level 2, the **Mooncorn Maze**. This level uses a static illustrated cornfield scene and contains three moon charms followed by an exit objective. The title screen also includes **Practice the Mooncorn Maze**, which starts Level 2 directly with a fresh set of charms for testing.

Progress is stored locally so an unfinished spell or maze run can be continued from the title screen.

## Controls

- **WASD / Arrow keys** — Move the witch
- **E / Space** — Collect ingredients, deposit them, talk to witches, and inspect landmarks
- **Esc** — Pause or resume

The title screen provides the normal adventure entry point, saved-run continuation, and direct maze practice mode.

## Project layout

```text
assets/                 Game art, icons, fonts, and static backgrounds
scenes/main.tscn        Main Godot scene
scripts/entities/       Player entity and movement
scripts/game/           Woodland and Mooncorn Maze world controllers
scripts/hollow_main.gd  Shared title, HUD, pause, save, and level flow
autoload/               Persistence, tuning, language, and cauldron integration
tools/hollow_check.gd   Native gameplay regression test
config/                 Runtime tuning configuration
web/                    Loading and web-export presentation
```

## Running locally

Install Godot 4 and Node.js, then run the project from the repository root.

To open the project in Godot:

```bash
godot --editor --path .
```

To run the game directly:

```bash
godot --path .
```

The repository also contains the managed Preview workflow:

```bash
npm run dev
npm run preview:build
npm run preview:status
```

## Verification

Run the native gameplay regression test to verify movement, pause behavior, ordered ingredient collection, cauldron deposits, save restoration, spell completion, replay, Level 2 entry, moon-charms, maze completion, and direct maze practice mode:

```bash
/usr/local/bin/godot --headless --path . --audio-driver Dummy --script tools/hollow_check.gd
```

Run the project pack verification:

```bash
npm run check -- --pack
```

## Collision-mask helper

`tools/generate_collision_mask.py` is an offline assistive tool for turning a static top-down background into reviewable collision candidates. It resizes the image to world coordinates, detects high-frequency edges, applies an approximately `k × k` Gaussian blur, classifies pixels at or below one grayscale threshold as walkable, and derives coarse obstacle candidates from the inverse mask. It writes:

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
  --obstacle-occupancy 0.50 \
  --inset 5 \
  --min-area 1536
```

The helper requires Python with Pillow and NumPy. Its output should be adjusted or hand-authored before being used as authoritative gameplay collision.

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

## Contributing

Keep gameplay authority in the Godot world controllers and entity scripts. Presentation changes should not determine collisions, rewards, or progression. When changing gameplay, update `tools/hollow_check.gd` and run the native regression test before committing.

## License notes

The repository includes the inherited project/template license screen and its bundled notices. Review the notices and the source metadata for the applicable terms of individual assets before redistributing modified or extracted assets.
