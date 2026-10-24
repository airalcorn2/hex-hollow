#!/usr/bin/env python3
"""Generate reviewable collision regions from a static top-down background.

This is an assistive tool, not a final authority. It uses configurable HSV
heuristics to find likely vegetation, snaps the result to a coarse grid, merges
adjacent occupied cells into rectangles, and writes pixel-level and rectangle
debug overlays. Review the overlays before importing the generated shapes into
gameplay.

Example:
  python3 tools/generate_collision_mask.py \
    --image assets/corn-maze/corn_maze_ground.png \
    --output-json /tmp/corn-collisions.json \
    --output-preview /tmp/corn-collisions-preview.png \
    --output-pixel-mask /tmp/corn-collisions-pixels.png \
    --output-gdscript /tmp/corn-collisions.gd \
    --world-width 1216 --world-height 832 --cell-size 16
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


@dataclass(frozen=True)
class Rect:
    x: int
    y: int
    w: int
    h: int

    @property
    def area(self) -> int:
        return self.w * self.h

    def polygon(self) -> list[list[int]]:
        return [[self.x, self.y], [self.x + self.w, self.y], [self.x + self.w, self.y + self.h], [self.x, self.y + self.h]]


def rgb_to_hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    values = rgb.astype(np.float32) / 255.0
    red, green, blue = values[..., 0], values[..., 1], values[..., 2]
    maximum = values.max(axis=-1)
    minimum = values.min(axis=-1)
    delta = maximum - minimum
    hue = np.zeros_like(maximum)
    nonzero = delta > 1e-5
    red_max = nonzero & (maximum == red)
    green_max = nonzero & (maximum == green)
    blue_max = nonzero & (maximum == blue)
    hue[red_max] = ((green[red_max] - blue[red_max]) / delta[red_max]) % 6.0
    hue[green_max] = ((blue[green_max] - red[green_max]) / delta[green_max]) + 2.0
    hue[blue_max] = ((red[blue_max] - green[blue_max]) / delta[blue_max]) + 4.0
    hue *= 60.0
    saturation = np.zeros_like(maximum)
    nonblack = maximum > 1e-5
    saturation[nonblack] = delta[nonblack] / maximum[nonblack]
    return hue, saturation * 255.0, maximum * 255.0


def segment(image: Image.Image, args: argparse.Namespace) -> np.ndarray:
    rgb = np.asarray(image.convert("RGB"), dtype=np.uint8)
    hue, saturation, value = rgb_to_hsv(rgb)
    green = (hue >= args.green_hue_min) & (hue <= args.green_hue_max)
    gold = (hue >= args.gold_hue_min) & (hue <= args.gold_hue_max)
    mask = ((green & (saturation >= args.saturation_min) & (value <= args.value_max)) |
            (gold & (saturation >= args.gold_saturation_min) & (value <= args.gold_value_max)))
    mask_image = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    if args.close_size > 1:
        size = args.close_size if args.close_size % 2 else args.close_size + 1
        mask_image = mask_image.filter(ImageFilter.MaxFilter(size)).filter(ImageFilter.MinFilter(size))
    return np.asarray(mask_image) >= 128


def edge_map(image: Image.Image, percentile: float) -> np.ndarray:
    """Return a high-frequency edge map for texture-density filtering."""
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    gray = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    gx = np.diff(gray, axis=1, prepend=gray[:, :1])
    gy = np.diff(gray, axis=0, prepend=gray[:1, :])
    magnitude = np.sqrt(gx * gx + gy * gy)
    threshold = np.percentile(magnitude, percentile)
    return magnitude >= threshold


def occupied_grid(mask: np.ndarray, cell_size: int, occupancy: float, edges: np.ndarray | None = None, min_edge_density: float = 0.0) -> np.ndarray:
    height, width = mask.shape
    usable_width = (width // cell_size) * cell_size
    usable_height = (height // cell_size) * cell_size
    cropped = mask[:usable_height, :usable_width]
    grid = cropped.reshape(usable_height // cell_size, cell_size, usable_width // cell_size, cell_size)
    fraction = grid.mean(axis=(1, 3))
    occupied = fraction >= occupancy
    if edges is not None and min_edge_density > 0.0:
        edge_crop = edges[:usable_height, :usable_width]
        edge_grid = edge_crop.reshape(usable_height // cell_size, cell_size, usable_width // cell_size, cell_size)
        edge_density = edge_grid.mean(axis=(1, 3))
        occupied &= edge_density >= min_edge_density
    return occupied


def merge_grid(grid: np.ndarray, cell_size: int, inset: int, min_area: int) -> list[Rect]:
    """Greedily merge occupied grid cells into reviewable axis-aligned rectangles."""
    rows, cols = grid.shape
    used = np.zeros_like(grid, dtype=bool)
    rects: list[Rect] = []
    for row in range(rows):
        for col in range(cols):
            if not grid[row, col] or used[row, col]:
                continue
            width = 0
            while col + width < cols and grid[row, col + width] and not used[row, col + width]:
                width += 1
            height = 1
            while row + height < rows and np.all(grid[row + height, col:col + width]) and not np.any(used[row + height, col:col + width]):
                height += 1
            used[row:row + height, col:col + width] = True
            x = col * cell_size + inset
            y = row * cell_size + inset
            w = width * cell_size - inset * 2
            h = height * cell_size - inset * 2
            if w > 0 and h > 0 and w * h >= min_area:
                rects.append(Rect(x, y, w, h))
    return rects


def write_godot(path: Path, rects: list[Rect]) -> None:
    lines = ["# Generated by tools/generate_collision_mask.py. Review before using.", "const GENERATED_COLLISION_POLYGONS := ["]
    for rect in rects:
        points = ", ".join("Vector2(%d, %d)" % (x, y) for x, y in rect.polygon())
        lines.append("    PackedVector2Array([%s])," % points)
    lines.append("]")
    path.write_text("\n".join(lines) + "\n")


def write_preview(image: Image.Image, rects: list[Rect], path: Path, opacity: int) -> None:
    preview = image.convert("RGBA")
    layer = Image.new("RGBA", preview.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for rect in rects:
        box = (rect.x, rect.y, rect.x + rect.w, rect.y + rect.h)
        draw.rectangle(box, fill=(222, 56, 68, opacity), outline=(255, 232, 126, 255), width=2)
    preview.alpha_composite(layer)
    preview.save(path)


def write_pixel_mask(mask: np.ndarray, edges: np.ndarray, path: Path) -> None:
    """Write a false-color pixel diagnostic for the pre-grid heuristic.

    Blue pixels pass the HSV vegetation/gold test, orange pixels are detected
    as high-frequency edges, and bright green pixels pass both tests. This is
    intentionally separate from the coarse rectangle preview: it shows the
    evidence available before cell occupancy and rectangle merging discard
    pixel-level detail.
    """
    rgb = np.zeros((*mask.shape, 3), dtype=np.uint8)
    rgb[mask] = (40, 110, 255)
    rgb[edges] = (255, 150, 30)
    rgb[mask & edges] = (80, 255, 120)
    Image.fromarray(rgb, mode="RGB").save(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--output-json", required=True, type=Path)
    parser.add_argument("--output-preview", required=True, type=Path)
    parser.add_argument("--output-pixel-mask", type=Path, help="False-color pixel diagnostic: blue=color, orange=edge, green=both")
    parser.add_argument("--output-gdscript", type=Path)
    parser.add_argument("--world-width", type=int, required=True)
    parser.add_argument("--world-height", type=int, required=True)
    parser.add_argument("--cell-size", type=int, default=16)
    parser.add_argument("--occupancy", type=float, default=0.34)
    parser.add_argument("--inset", type=int, default=3)
    parser.add_argument("--min-area", type=int, default=384)
    parser.add_argument("--close-size", type=int, default=5)
    parser.add_argument("--edge-percentile", type=float, default=78.0, help="Global gradient percentile used as the edge threshold")
    parser.add_argument("--min-edge-density", type=float, default=0.18, help="Minimum fraction of high-gradient pixels in an occupied cell; use 0 to disable")
    parser.add_argument("--green-hue-min", type=float, default=25.0)
    parser.add_argument("--green-hue-max", type=float, default=110.0)
    parser.add_argument("--gold-hue-min", type=float, default=8.0)
    parser.add_argument("--gold-hue-max", type=float, default=38.0)
    parser.add_argument("--saturation-min", type=float, default=45.0)
    parser.add_argument("--gold-saturation-min", type=float, default=70.0)
    parser.add_argument("--value-max", type=float, default=210.0)
    parser.add_argument("--gold-value-max", type=float, default=220.0)
    parser.add_argument("--preview-opacity", type=int, default=92)
    args = parser.parse_args()

    image = Image.open(args.image).convert("RGB").resize((args.world_width, args.world_height), Image.Resampling.LANCZOS)
    mask = segment(image, args)
    edges = edge_map(image, args.edge_percentile)
    grid = occupied_grid(mask, args.cell_size, args.occupancy, edges, args.min_edge_density)
    rects = merge_grid(grid, args.cell_size, args.inset, args.min_area)
    rects.sort(key=lambda rect: (rect.y, rect.x))

    payload = {
        "source": str(args.image),
        "worldSize": [args.world_width, args.world_height],
        "cellSize": args.cell_size,
        "method": "HSV vegetation/gold segmentation + local edge-density filter -> coarse occupancy grid -> greedy rectangle merge",
        "reviewRequired": True,
        "settings": {key: getattr(args, key) for key in ["occupancy", "inset", "min_area", "close_size", "edge_percentile", "min_edge_density", "green_hue_min", "green_hue_max", "gold_hue_min", "gold_hue_max", "saturation_min", "gold_saturation_min", "value_max", "gold_value_max"]},
        "rectangles": [{"x": r.x, "y": r.y, "width": r.w, "height": r.h} for r in rects],
        "polygons": [r.polygon() for r in rects],
    }
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_preview.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(payload, indent=2) + "\n")
    write_preview(image, rects, args.output_preview, args.preview_opacity)
    if args.output_pixel_mask:
        args.output_pixel_mask.parent.mkdir(parents=True, exist_ok=True)
        write_pixel_mask(mask, edges, args.output_pixel_mask)
    if args.output_gdscript:
        args.output_gdscript.parent.mkdir(parents=True, exist_ok=True)
        write_godot(args.output_gdscript, rects)
    print(json.dumps({"rectangles": len(rects), "json": str(args.output_json), "preview": str(args.output_preview), "pixelMask": str(args.output_pixel_mask) if args.output_pixel_mask else None, "gdscript": str(args.output_gdscript) if args.output_gdscript else None}, indent=2))


if __name__ == "__main__":
    main()
