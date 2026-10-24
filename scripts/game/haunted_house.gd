class_name HauntedHouseWorld
extends Node2D

signal message(text: String)
signal house_completed

const WORLD_SIZE := Vector2(1536, 1024)
const START_POSITION := Vector2(768, 888)
const CAULDRON_POSITION := Vector2(768, 800)
const CAULDRON_RADIUS := 22.0
const CAULDRON_REACH := 72.0
const GROUND_TEXTURE := preload("res://assets/haunted-house/manor_ground.png")
const WALKABLE_MASK_TEXTURE := preload("res://assets/haunted-house/manor_walkable_mask.png")
const CAULDRON_TEXTURE := preload("res://assets/recipe/icons/cauldron.png")
const CAULDRON_SPELL_TEXTURE := preload("res://assets/recipe/icons/cauldron_spell.png")
const ITEM_DATA := [
	{"id":"silver_key", "name":"Silver key", "hint":"The library"},
	{"id":"music_box", "name":"Music box", "hint":"The nursery"},
	{"id":"ghost_candle", "name":"Ghost candle", "hint":"Portrait gallery"},
	{"id":"velvet_ribbon", "name":"Velvet ribbon", "hint":"The dining room"},
]
const ITEM_POSITIONS := [Vector2(455, 520), Vector2(1170, 780), Vector2(1150, 260), Vector2(505, 252)]
const ITEM_TEXTURES := [
	preload("res://assets/haunted-house/icons/silver_key.png"),
	preload("res://assets/haunted-house/icons/music_box.png"),
	preload("res://assets/haunted-house/icons/ghost_candle.png"),
	preload("res://assets/haunted-house/icons/velvet_ribbon.png"),
]
const MASK_SAMPLE_OFFSETS := [
	Vector2.ZERO,
	Vector2(6, 0), Vector2(-6, 0), Vector2(0, 5), Vector2(0, -5),
	Vector2(4, 4), Vector2(-4, 4), Vector2(4, -4), Vector2(-4, -4),
]
const BUBBLE_OFFSETS := [Vector2(-22, -74), Vector2(-5, -85), Vector2(13, -79), Vector2(27, -68)]
const ENVIRONMENT_INTERACTIONS := [
	{
		"id":"portrait", "name":"The Watching Portrait", "prompt":"Study the watching portrait",
		"pos":Vector2(1040, 175), "reach":90.0, "marker_anchor":Vector2(1024, 109),
		"lines":[
			"The lady in the frame sighs. 'Do straighten your hat. We have standards, even after death.'",
			"Her eyes follow you. 'Of course I stare, dear. Nobody brings me a book.'",
			"A painted hand points toward the foyer. 'Four keepsakes. One brew. Then kindly let us sleep.'",
		],
	},
	{
		"id":"piano", "name":"The Phantom Piano", "prompt":"Listen to the phantom piano",
		"pos":Vector2(1090, 487), "reach":92.0, "marker_anchor":Vector2(1128, 439),
		"lines":[
			"One key plays by itself. The next note is a tiny, offended sneeze.",
			"A ghostly pianist whispers: 'Requests cost a shilling. Complaints cost two.'",
			"The sheet music is titled A Minor Inconvenience. Every note is a boo.",
		],
	},
	{
		"id":"clock", "name":"The Thirteenth-Hour Clock", "prompt":"Inspect the haunted clock",
		"pos":Vector2(1408, 490), "reach":88.0, "marker_anchor":Vector2(1408, 439),
		"lines":[
			"It strikes thirteen. A voice inside mutters: 'Daylight haunting time. Terrible business.'",
			"The pendulum swings backward. 'You are not late,' says the clock. 'Yesterday is early.'",
			"A little brass plaque reads: Winding optional. Existential dread included.",
		],
	},
	{
		"id":"oven", "name":"The Haunted Hearth", "prompt":"Warm your hands by the haunted hearth",
		"pos":Vector2(198, 697), "reach":88.0, "marker_anchor":Vector2(186, 664),
		"lines":[
			"Something in the chimney asks for toast. 'Lightly frightened, please.'",
			"The kettle whistles a funeral march, then apologizes. It meant to make tea.",
			"A recipe card says: Add one pinch of salt. Do not add the cook. Again.",
		],
	},
]

var witch: HollowWitch
var camera: Camera2D
var walkable_mask: Image
var cauldron: Sprite2D
var item_sprites: Array[Sprite2D] = []
var interaction_markers: Array[Label] = []
var environment_dialogue_index: Array[int] = []
var collected: Array[String] = []
var active := false
var won := false
var elapsed := 0.0
var age := 0.0

func _ready() -> void:
	walkable_mask = WALKABLE_MASK_TEXTURE.get_image()
	for i in ITEM_DATA.size():
		var sprite := Sprite2D.new()
		sprite.texture = ITEM_TEXTURES[i]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = ITEM_POSITIONS[i] + Vector2(0, -12)
		sprite.scale = Vector2.ONE * 0.40
		sprite.z_index = 3
		add_child(sprite)
		item_sprites.append(sprite)
	cauldron = Sprite2D.new()
	cauldron.texture = CAULDRON_TEXTURE
	cauldron.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cauldron.position = CAULDRON_POSITION + Vector2(0, -30)
	cauldron.scale = Vector2.ONE * 0.84
	cauldron.z_index = 4
	add_child(cauldron)
	_build_interaction_markers()
	witch = HollowWitch.new()
	witch.position = START_POSITION
	witch.set_movement_bounds(Rect2(110, 156, 1328, 772))
	witch.set_movement_validator(Callable(self, "_is_walkable_position"))
	witch.z_index = 5
	add_child(witch)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	camera.position = witch.position
	add_child(camera)
	queue_redraw()

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
	var brew := Color("a4e4ba") if not won else Color("e7c77e")
	for i in BUBBLE_OFFSETS.size():
		var phase := fmod(age * 0.9 + i * 0.27, 1.0)
		var pos: Vector2 = CAULDRON_POSITION + BUBBLE_OFFSETS[i] + Vector2(sin(age * 2.0 + i) * 2.0, -phase * 20.0)
		var tint := brew
		tint.a = 0.85 * (1.0 - phase)
		draw_circle(pos, 2.6 + phase * 2.5, tint)

func _process(delta: float) -> void:
	camera.position = witch.position
	var motion_enabled := not bool(TuningStore.get_active_value("ui.reduced_motion", false))
	if motion_enabled:
		age += delta
	if active:
		elapsed += delta
	for i in item_sprites.size():
		item_sprites[i].position.y = ITEM_POSITIONS[i].y - 12 + (sin(age * 2.4 + i) * 2.0 if motion_enabled else 0.0)
	cauldron.position = CAULDRON_POSITION + Vector2(0, -30 + (sin(age * 4.0) * 0.5 if motion_enabled else 0.0))
	var nearest := nearby_environment()
	for i in interaction_markers.size():
		interaction_markers[i].modulate.a = 1.0 if i == nearest else 0.90
	queue_redraw()

func _is_walkable_position(candidate: Vector2) -> bool:
	if walkable_mask == null:
		return false
	if candidate.distance_to(CAULDRON_POSITION) < CAULDRON_RADIUS + 6.0:
		return false
	for offset in MASK_SAMPLE_OFFSETS:
		var sample := Vector2i(roundi(candidate.x + offset.x), roundi(candidate.y + offset.y))
		if sample.x < 0 or sample.y < 0 or sample.x >= walkable_mask.get_width() or sample.y >= walkable_mask.get_height():
			return false
		if walkable_mask.get_pixelv(sample).r < 0.5:
			return false
	return true

func set_active(value: bool) -> void:
	active = value and not won
	witch.active = active

func nearby_target() -> String:
	for i in ITEM_DATA.size():
		if ITEM_DATA[i].id not in collected and witch.position.distance_to(ITEM_POSITIONS[i]) < 52.0:
			return ITEM_DATA[i].id
	return ""

func target_name(id: String) -> String:
	for item in ITEM_DATA:
		if item.id == id:
			return item.name
	return id

func nearby_cauldron() -> bool:
	return witch.position.distance_to(CAULDRON_POSITION) < CAULDRON_REACH

func nearby_environment() -> int:
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
	return ENVIRONMENT_INTERACTIONS[index].prompt if index >= 0 and index < ENVIRONMENT_INTERACTIONS.size() else "Inspect the manor"

func region_name() -> String:
	var pos := witch.position
	if pos.x >= 635 and pos.x <= 905:
		return "THE FOYER" if pos.y > 700 else "THE WHISPERING HALL"
	if pos.y < 350:
		return "THE DINING ROOM" if pos.x < 635 else "THE PORTRAIT GALLERY"
	if pos.y < 620:
		return "THE LIBRARY" if pos.x < 635 else "THE MUSIC PARLOR"
	return "THE HAUNTED KITCHEN" if pos.x < 635 else "THE NURSERY"

func interact() -> void:
	if not active:
		return
	var target := nearby_target()
	if not target.is_empty():
		collected.append(target)
		for i in ITEM_DATA.size():
			if ITEM_DATA[i].id == target:
				item_sprites[i].visible = false
		message.emit("Found the %s. One less memory for the manor to hold." % target_name(target).to_lower())
		CauldronBridge.notify_house_event("pickup", {"keepsake":target})
		return
	if nearby_cauldron():
		if collected.size() == ITEM_DATA.size():
			won = true
			set_active(false)
			cauldron.texture = CAULDRON_SPELL_TEXTURE
			message.emit("The keepsakes dissolve into starlight. At last, the manor sighs and settles.")
			CauldronBridge.notify_house_event("victory")
			house_completed.emit()
		else:
			message.emit("The unhaunting spell needs four keepsakes. %d still linger in the manor." % (ITEM_DATA.size() - collected.size()))
		return
	var index := nearby_environment()
	if index >= 0:
		var landmark: Dictionary = ENVIRONMENT_INTERACTIONS[index]
		var line_index: int = environment_dialogue_index[index]
		var lines: Array = landmark.lines
		message.emit("%s: \"%s\"" % [landmark.name, lines[line_index]])
		CauldronBridge.notify_house_event("landmark", {"landmark":landmark.id, "line":line_index})
		environment_dialogue_index[index] = (line_index + 1) % lines.size()
		return
	message.emit("The floorboards whisper. Search the rooms, then return to the foyer cauldron.")

func restore(data: Dictionary) -> void:
	collected.clear()
	var valid_ids: Array = ITEM_DATA.map(func(item): return item.id)
	for id in data.get("collected", []):
		if id in valid_ids and id not in collected:
			collected.append(id)
	for i in ITEM_DATA.size():
		item_sprites[i].visible = ITEM_DATA[i].id not in collected
	elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	won = bool(data.get("won", false)) and collected.size() == ITEM_DATA.size()
	cauldron.texture = CAULDRON_SPELL_TEXTURE if won else CAULDRON_TEXTURE
	var candidate := Vector2(float(data.get("x", START_POSITION.x)), float(data.get("y", START_POSITION.y)))
	witch.position = candidate if _is_walkable_position(candidate) else START_POSITION
	camera.position = witch.position
	camera.reset_smoothing()

func snapshot() -> Dictionary:
	return {"level":3, "collected":collected.duplicate(), "elapsed":elapsed, "won":won, "x":witch.position.x, "y":witch.position.y}
