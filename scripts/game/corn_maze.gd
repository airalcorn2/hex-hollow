class_name CornMazeWorld
extends Node2D

signal message(text: String)
signal maze_completed

const CELL := 64
const GRID_W := 19
const GRID_H := 13
const WORLD_SIZE := Vector2(GRID_W * CELL, GRID_H * CELL)
const START_POSITION := Vector2(100.0, 88.0)
# Positions verified reachable from START_POSITION on the walkable mask
# (footprint-eroded flood fill from the entrance plaza).
const EXIT_POSITION := Vector2(1075.0, 650.0)
const CHARM_POSITIONS := [Vector2(197.0, 251.0), Vector2(785.0, 213.0), Vector2(620.0, 608.0)]
const CHARM_DATA := [
	{"id":"amber_cob", "name":"Amber cob", "color":Color("f2bd58")},
	{"id":"moon_cob", "name":"Moonlit cob", "color":Color("b9e5a2")},
	{"id":"ghost_cob", "name":"Ghost cob", "color":Color("b7b6e8")},
]
const CHARM_ICONS := [
	preload("res://assets/recipe/icons/pumpkin.png"),
	preload("res://assets/recipe/icons/moonflower.png"),
	preload("res://assets/recipe/icons/essence.png"),
]
const GROUND_TEXTURE := preload("res://assets/corn-maze/corn_maze_ground.png")
const WALKABLE_MASK_TEXTURE := preload("res://assets/corn-maze/corn_maze_walkable_mask.png")
# Forgiving feet-sized footprint: the witch's sprite and hat may overlap corn
# visually, but only a small area around her feet is tested against the mask.
const MASK_SAMPLE_OFFSETS := [
	Vector2.ZERO,
	Vector2(6, 0), Vector2(-6, 0), Vector2(0, 5), Vector2(0, -5),
	Vector2(4, 4), Vector2(-4, 4), Vector2(4, -4), Vector2(-4, -4),
]

var witch: HollowWitch
var camera: Camera2D
var walkable_mask: Image
var active := false
var won := false
var elapsed := 0.0
var age := 0.0
var charm_sprites: Array[Sprite2D] = []
var collected: Array[String] = []
var exit_marker: Label

func _ready() -> void:
	walkable_mask = WALKABLE_MASK_TEXTURE.get_image()
	_build_charm_sprites()
	_build_exit_marker()
	witch = HollowWitch.new()
	witch.position = START_POSITION
	witch.set_movement_bounds(Rect2(14.0, 14.0, WORLD_SIZE.x - 28.0, WORLD_SIZE.y - 28.0))
	witch.set_movement_validator(Callable(self, "_is_walkable_position"))
	witch.z_index = 5
	add_child(witch)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WORLD_SIZE.x
	camera.limit_bottom = WORLD_SIZE.y
	camera.position = witch.position
	add_child(camera)
	queue_redraw()

func _is_walkable_position(candidate: Vector2) -> bool:
	if walkable_mask == null:
		return false
	for offset in MASK_SAMPLE_OFFSETS:
		var sample := Vector2i(roundi(candidate.x + offset.x), roundi(candidate.y + offset.y))
		if sample.x < 0 or sample.y < 0 or sample.x >= walkable_mask.get_width() or sample.y >= walkable_mask.get_height():
			return false
		if walkable_mask.get_pixelv(sample).r < 0.5:
			return false
	return true

func cell_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL * 0.5)

func _build_charm_sprites() -> void:
	for i in CHARM_POSITIONS.size():
		var sprite := Sprite2D.new()
		sprite.texture = CHARM_ICONS[i]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = CHARM_POSITIONS[i] + Vector2(0, -10)
		sprite.scale = Vector2.ONE * 0.48
		sprite.modulate = CHARM_DATA[i].color
		sprite.z_index = 3
		add_child(sprite)
		charm_sprites.append(sprite)

func _build_exit_marker() -> void:
	exit_marker = _marker("EXIT", EXIT_POSITION + Vector2(-30, -48), Color("a4e4ba"))

func _marker(text: String, pos: Vector2, color: Color) -> Label:
	var marker := Label.new()
	marker.text = text
	marker.position = pos
	marker.size = Vector2(60, 28)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 18 if text == "?" else 12)
	marker.add_theme_font_override("font", preload("res://assets/template/fonts/display/generic_heading.tres"))
	marker.add_theme_color_override("font_color", color)
	marker.add_theme_color_override("font_shadow_color", Color("171020"))
	marker.add_theme_constant_override("shadow_offset_x", 2)
	marker.add_theme_constant_override("shadow_offset_y", 2)
	marker.z_index = 20
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marker)
	return marker

func _draw() -> void:
	draw_texture_rect(GROUND_TEXTURE, Rect2(Vector2.ZERO, WORLD_SIZE), false)
	draw_circle(EXIT_POSITION, 25.0, Color("3d6749"))
	draw_arc(EXIT_POSITION, 27.0, 0.0, TAU, 24, Color("a4e4ba"), 2.0)

func set_active(value: bool) -> void:
	active = value and not won
	witch.active = active

func _process(delta: float) -> void:
	camera.position = witch.position
	if not active and not won:
		return
	age += delta
	if active:
		elapsed += delta
	for i in charm_sprites.size():
		if not charm_sprites[i].visible:
			continue
		charm_sprites[i].position.y = CHARM_POSITIONS[i].y - 10 + sin(age * 2.4 + i) * 3.0
	if won:
		exit_marker.modulate.a = 0.7 + sin(age * 3.0) * 0.2

func nearby_target() -> String:
	for i in CHARM_DATA.size():
		if CHARM_DATA[i].id in collected:
			continue
		if witch.position.distance_to(CHARM_POSITIONS[i]) < 52.0:
			return CHARM_DATA[i].id
	return ""

func target_name(id: String) -> String:
	for entry in CHARM_DATA:
		if entry.id == id:
			return entry.name
	return id

func nearby_exit() -> bool:
	return witch.position.distance_to(EXIT_POSITION) < 62.0

func interact() -> void:
	if not active:
		return
	var target := nearby_target()
	if not target.is_empty():
		collected.append(target)
		for i in CHARM_DATA.size():
			if CHARM_DATA[i].id == target:
				charm_sprites[i].visible = false
		message.emit("Found %s. The maze remembers your footsteps." % target_name(target))
		return
	if nearby_exit():
		if collected.size() == CHARM_DATA.size():
			won = true
			set_active(false)
			message.emit("The corn parts before you. The moonlit path is open!")
			maze_completed.emit()
		else:
			message.emit("The maze gate is sealed. Find all three moon charms first.")
		return
	message.emit("The corn whispers from every direction. Follow the moonlit charms.")

func restore(data: Dictionary) -> void:
	collected.clear()
	for id in data.get("collected", []):
		if id in ["amber_cob", "moon_cob", "ghost_cob"] and id not in collected:
			collected.append(id)
	for i in CHARM_DATA.size():
		var hidden: bool = CHARM_DATA[i].id in collected
		charm_sprites[i].visible = not hidden
	var saved_position := Vector2(float(data.get("x", START_POSITION.x)), float(data.get("y", START_POSITION.y)))
	witch.position = saved_position if _is_walkable_position(saved_position) else START_POSITION
	camera.position = witch.position
	camera.reset_smoothing()

func snapshot() -> Dictionary:
	return {"level":2, "collected":collected.duplicate(), "elapsed":elapsed, "x":witch.position.x, "y":witch.position.y}
