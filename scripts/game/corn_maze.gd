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
# (footprint-aware flood fill from the entrance plaza, with the cauldron solid).
const CAULDRON_POSITION := Vector2(1078.0, 662.0)
const CAULDRON_RADIUS := 16.0
const CAULDRON_REACH := 64.0
const TREAT_POSITIONS := [Vector2(197.0, 251.0), Vector2(785.0, 213.0), Vector2(620.0, 608.0)]
const TREAT_DATA := [
	{"id":"candy_apple", "name":"Candy apple"},
	{"id":"caramel_corn", "name":"Caramel corn ball"},
	{"id":"candy_corn", "name":"Candy corn"},
]
const TREAT_ICONS := [
	preload("res://assets/recipe/icons/candy_apple.png"),
	preload("res://assets/recipe/icons/caramel_corn.png"),
	preload("res://assets/recipe/icons/candy_corn.png"),
]
const CAULDRON_TEXTURE := preload("res://assets/recipe/icons/cauldron.png")
const CAULDRON_SPELL_TEXTURE := preload("res://assets/recipe/icons/cauldron_spell.png")
const GROUND_TEXTURE := preload("res://assets/corn-maze/corn_maze_ground.png")
const WALKABLE_MASK_TEXTURE := preload("res://assets/corn-maze/corn_maze_walkable_mask.png")
# Forgiving feet-sized footprint: the witch's sprite and hat may overlap corn
# visually, but only a small area around her feet is tested against the mask.
const MASK_SAMPLE_OFFSETS := [
	Vector2.ZERO,
	Vector2(6, 0), Vector2(-6, 0), Vector2(0, 5), Vector2(0, -5),
	Vector2(4, 4), Vector2(-4, 4), Vector2(4, -4), Vector2(-4, -4),
]
const BUBBLE_OFFSETS := [Vector2(-18, -58), Vector2(-4, -66), Vector2(12, -60), Vector2(22, -52)]
const ENVIRONMENT_INTERACTIONS := [
	{
		"id":"well", "name":"Wishing Well", "prompt":"Peer into the wishing well",
		"pos":Vector2(700, 214), "reach":90.0, "marker_anchor":Vector2(702, 147),
		"lines":[
			"Drop in a wish, not a witch. The last one clogged the bucket.",
			"Your reflection winks first. How terribly impolite.",
			"A voice below whispers: 'One penny for luck. Two for plausible deniability.'",
		],
	},
	{
		"id":"tree", "name":"Lantern Tree", "prompt":"Listen to the lantern tree",
		"pos":Vector2(414, 443), "reach":90.0, "marker_anchor":Vector2(407, 422),
		"lines":[
			"The branches creak: 'I know every shortcut. I just enjoy watching you wander.'",
			"The lantern flickers twice. A leaf lands on your hat like a tiny blessing.",
			"'No broom parking,' says the tree. 'The squirrels have complained.'",
		],
	},
	{
		"id":"wagon", "name":"Pumpkin Wagon", "prompt":"Inspect the pumpkin wagon",
		"pos":Vector2(1016, 454), "reach":80.0, "marker_anchor":Vector2(1023, 411),
		"lines":[
			"The delivery note reads: 'Three pumpkins, two curses. Handle with scare.'",
			"One pumpkin rolls an inch toward you. You politely pretend not to notice.",
			"The wheels turn without a breeze. Even the wagons go haunting after hours.",
		],
	},
]

var witch: HollowWitch
var camera: Camera2D
var walkable_mask: Image
var active := false
var won := false
var elapsed := 0.0
var age := 0.0
var treat_sprites: Array[Sprite2D] = []
var collected: Array[String] = []
var cauldron: Sprite2D
var interaction_markers: Array[Label] = []
var environment_dialogue_index: Array[int] = []

func _ready() -> void:
	walkable_mask = WALKABLE_MASK_TEXTURE.get_image()
	_build_treat_sprites()
	_build_cauldron()
	_build_interaction_markers()
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
	# The cauldron is a solid prop in the middle of the lantern gate.
	if candidate.distance_to(CAULDRON_POSITION) < CAULDRON_RADIUS + 6.0:
		return false
	for offset in MASK_SAMPLE_OFFSETS:
		var sample := Vector2i(roundi(candidate.x + offset.x), roundi(candidate.y + offset.y))
		if sample.x < 0 or sample.y < 0 or sample.x >= walkable_mask.get_width() or sample.y >= walkable_mask.get_height():
			return false
		if walkable_mask.get_pixelv(sample).r < 0.5:
			return false
	return true

func _build_treat_sprites() -> void:
	for i in TREAT_POSITIONS.size():
		var sprite := Sprite2D.new()
		sprite.texture = TREAT_ICONS[i]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = TREAT_POSITIONS[i] + Vector2(0, -10)
		sprite.scale = Vector2.ONE * 0.36
		sprite.z_index = 3
		add_child(sprite)
		treat_sprites.append(sprite)

func _build_cauldron() -> void:
	cauldron = Sprite2D.new()
	cauldron.texture = CAULDRON_TEXTURE
	cauldron.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cauldron.position = CAULDRON_POSITION + Vector2(0, -22)
	cauldron.scale = Vector2.ONE * 0.62
	cauldron.z_index = 4
	add_child(cauldron)
	# Bubbles are drawn procedurally in _draw so the brew can change color.

func _build_interaction_markers() -> void:
	for landmark in ENVIRONMENT_INTERACTIONS:
		var marker := Label.new()
		marker.text = "?"
		marker.position = landmark.marker_anchor - Vector2(12, 34)
		marker.size = Vector2(24, 34)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 21)
		marker.add_theme_font_override("font", preload("res://assets/template/fonts/display/generic_heading.tres"))
		marker.add_theme_color_override("font_color", Color("f4c46f"))
		marker.add_theme_color_override("font_shadow_color", Color("171020"))
		marker.add_theme_constant_override("shadow_offset_x", 2)
		marker.add_theme_constant_override("shadow_offset_y", 2)
		marker.z_index = 20
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pointer := Polygon2D.new()
		pointer.polygon = PackedVector2Array([Vector2(9, 28), Vector2(15, 28), Vector2(12, 34)])
		pointer.color = Color("f4c46f")
		marker.add_child(pointer)
		add_child(marker)
		interaction_markers.append(marker)
		environment_dialogue_index.append(0)

func _draw() -> void:
	draw_texture_rect(GROUND_TEXTURE, Rect2(Vector2.ZERO, WORLD_SIZE), false)
	var brew := Color("a4e4ba") if collected.size() < TREAT_DATA.size() else Color("f2bd58")
	for i in BUBBLE_OFFSETS.size():
		var phase := fmod(age * 0.9 + i * 0.27, 1.0)
		var pos: Vector2 = CAULDRON_POSITION + BUBBLE_OFFSETS[i] + Vector2(sin(age * 2.0 + i) * 2.0, -phase * 22.0)
		var tint := brew
		tint.a = 0.85 * (1.0 - phase)
		draw_circle(pos, 2.5 + phase * 2.5, tint)

func set_active(value: bool) -> void:
	active = value and not won
	witch.active = active

func _process(delta: float) -> void:
	camera.position = witch.position
	age += delta
	if active:
		elapsed += delta
	for i in treat_sprites.size():
		if treat_sprites[i].visible:
			treat_sprites[i].position.y = TREAT_POSITIONS[i].y - 10 + sin(age * 2.4 + i) * 3.0
	cauldron.position = CAULDRON_POSITION + Vector2(0, -22 + sin(age * 4.0) * 0.6)
	cauldron.scale = Vector2.ONE * (0.62 + sin(age * 4.0) * 0.008)
	var nearest := nearby_environment()
	for i in interaction_markers.size():
		interaction_markers[i].position = ENVIRONMENT_INTERACTIONS[i].marker_anchor - Vector2(12, 34)
		interaction_markers[i].modulate = Color.WHITE if i == nearest else Color(1.0, 1.0, 1.0, 0.85)
	queue_redraw()

func nearby_target() -> String:
	for i in TREAT_DATA.size():
		if TREAT_DATA[i].id in collected:
			continue
		if witch.position.distance_to(TREAT_POSITIONS[i]) < 52.0:
			return TREAT_DATA[i].id
	return ""

func target_name(id: String) -> String:
	for entry in TREAT_DATA:
		if entry.id == id:
			return entry.name
	return id

func nearby_cauldron() -> bool:
	return witch.position.distance_to(CAULDRON_POSITION) < CAULDRON_REACH

func nearby_environment() -> int:
	# Preserve pickup and cauldron priority, including when holding all treats.
	if not nearby_target().is_empty() or nearby_cauldron():
		return -1
	var result := -1
	var closest := INF
	for i in ENVIRONMENT_INTERACTIONS.size():
		var landmark: Dictionary = ENVIRONMENT_INTERACTIONS[i]
		var distance: float = witch.position.distance_to(landmark.pos)
		if distance < float(landmark.reach) and distance < closest:
			closest = distance
			result = i
	return result

func environment_prompt(index: int) -> String:
	if index < 0 or index >= ENVIRONMENT_INTERACTIONS.size():
		return "Inspect the surroundings"
	return ENVIRONMENT_INTERACTIONS[index].prompt

func interact() -> void:
	if not active:
		return
	var target := nearby_target()
	if not target.is_empty():
		collected.append(target)
		for i in TREAT_DATA.size():
			if TREAT_DATA[i].id == target:
				treat_sprites[i].visible = false
		message.emit("Found a %s! Sweet, sticky, and very witchy." % target_name(target).to_lower())
		# Same real-world splash/announce treatment the main hollow's
		# ingredients get -- see game_bridge.py's HOLLOW_TREATS.
		CauldronBridge.notify_treat(target)
		return
	if nearby_cauldron():
		if collected.size() == TREAT_DATA.size():
			won = true
			set_active(false)
			cauldron.texture = CAULDRON_SPELL_TEXTURE
			message.emit("The treats melt into the brew. A harvest spell bubbles over!")
			CauldronBridge.notify_maze_victory()
			maze_completed.emit()
		else:
			message.emit("The cauldron wants all three fall treats. %d still hide in the corn." % (TREAT_DATA.size() - collected.size()))
		return
	var environment_index := nearby_environment()
	if environment_index >= 0:
		var landmark: Dictionary = ENVIRONMENT_INTERACTIONS[environment_index]
		var lines: Array = landmark.lines
		var line_index: int = environment_dialogue_index[environment_index]
		message.emit("%s: \"%s\"" % [landmark.name, lines[line_index]])
		CauldronBridge.notify_landmark("corn_maze", landmark.id, line_index)
		environment_dialogue_index[environment_index] = (line_index + 1) % lines.size()
		return
	message.emit("Something sweet is hiding in the corn. Follow the paths.")

func restore(data: Dictionary) -> void:
	collected.clear()
	var valid_ids: Array = TREAT_DATA.map(func(entry): return entry.id)
	for id in data.get("collected", []):
		if id in valid_ids and id not in collected:
			collected.append(id)
	for i in TREAT_DATA.size():
		var hidden: bool = TREAT_DATA[i].id in collected
		treat_sprites[i].visible = not hidden
	var saved_position := Vector2(float(data.get("x", START_POSITION.x)), float(data.get("y", START_POSITION.y)))
	witch.position = saved_position if _is_walkable_position(saved_position) else START_POSITION
	camera.position = witch.position
	camera.reset_smoothing()

func snapshot() -> Dictionary:
	return {"level":2, "collected":collected.duplicate(), "elapsed":elapsed, "x":witch.position.x, "y":witch.position.y}
