class_name HollowWorld
extends Node2D

signal recipe_changed
signal message(text: String)
signal spell_completed

const INGREDIENTS := [
	{"id":"mushroom", "name":"Mooncap mushroom", "hint":"Mushroom grove · southwest", "pos":Vector2(365, 790)},
	{"id":"pumpkin", "name":"Ember pumpkin", "hint":"Pumpkin patch · northeast", "pos":Vector2(1290, 225)},
	{"id":"skull", "name":"Old hollow skull", "hint":"Graveyard · northwest", "pos":Vector2(350, 190)},
	{"id":"feather", "name":"Raven feather", "hint":"Northern woodland path", "pos":Vector2(815, 170)},
	{"id":"essence", "name":"Ghost essence", "hint":"Pond bridge · southeast", "pos":Vector2(1320, 725)},
	{"id":"moonflower", "name":"Moonflower", "hint":"Eastern lantern trail", "pos":Vector2(1120, 525)}
]
const COMPANION_DIALOGUE := {
	"Violet": [
		"Ahh, the moon is a silver spoon tonight, dear. Stir clockwise for luck.",
		"A little stardust makes every spell more scholarly, you know.",
		"Ahh, do mind the ghosts. They are terribly fond of interrupting a good ritual.",
	],
	"Amber": [
		"Ooh, drop something spooky in the pot. Give it some real attitude!",
		"That cauldron's glowing again. Show-off.",
		"Ooh, if it hisses at you, just smile like you meant for that to happen.",
	],
	"Hazel": [
		"Hmph. Keep your fingers out of the brew, child. It bites.",
		"The old ways favor patience, proper shoes, and fewer explosions.",
		"Mind the moonflower. It wilts when young witches hurry.",
	],
}
const ENVIRONMENT_INTERACTIONS := [
	{
		"id":"gravestone_crooked",
		"name":"The crooked gravestone",
		"pos":Vector2(264, 169),
		"prompt":"Read the epitaph",
		"epitaphs":[
			"Here lies Reginald. He chased a ghost. The ghost won.",
			"He asked the moon for directions. It pointed down.",
		],
	},
	{
		"id":"gravestone_mossy",
		"name":"The mossy gravestone",
		"pos":Vector2(465, 180),
		"prompt":"Read the epitaph",
		"epitaphs":[
			"Beloved Beatrice. She always said the grave was half full.",
			"Rest in peace. Please leave the offerings where they are.",
		],
	},
	{
		"id":"lantern",
		"name":"The lantern with no flame",
		"pos":Vector2(402, 620),
		"prompt":"Inspect the lantern",
		"epitaphs":[
			"The flame went out years ago. Its shadow still flickers.",
			"Someone lit this lantern at midnight. Someone else answered.",
		],
	},
	{
		"id":"oak",
		"name":"The whispering oak",
		"pos":Vector2(880, 770),
		"prompt":"Listen to the tree",
		"epitaphs":[
			"The oak whispers your name, but only on the second listen.",
			"A face is carved in the bark. It looks more awake than you do.",
		],
	},
	{
		"id":"pond_sign",
		"name":"The crooked pond sign",
		"pos":Vector2(1218, 694),
		"prompt":"Read the pond sign",
		"epitaphs":[
			"POND RULES: No feeding the fish. They remember faces.",
			"The water is six inches deep. The reflection is much deeper.",
		],
	},
	{
		"id":"pumpkin_winking",
		"name":"The winking pumpkin",
		"pos":Vector2(1210, 175),
		"prompt":"Inspect the pumpkin",
		"epitaphs":[
			"This pumpkin has a heartbeat. It is trying to pretend it doesn't.",
			"The grin is painted on. The blink was not.",
		],
	},
	{
		"id":"pumpkin_smallest",
		"name":"The smallest pumpkin",
		"pos":Vector2(1370, 245),
		"prompt":"Inspect the pumpkin",
		"epitaphs":[
			"It is holding a secret. It refuses to share.",
			"A tiny stem, a tiny curse, an enormous attitude.",
		],
	},
]
const ICONS := {
	"cauldron":preload("res://assets/recipe/icons/cauldron.png"),
	"cauldron_spell":preload("res://assets/recipe/icons/cauldron_spell.png"),
	"mushroom":preload("res://assets/recipe/icons/mushroom.png"),
	"pumpkin":preload("res://assets/recipe/icons/pumpkin.png"),
	"skull":preload("res://assets/recipe/icons/skull.png"),
	"feather":preload("res://assets/recipe/icons/feather.png"),
	"essence":preload("res://assets/recipe/icons/essence.png"),
	"moonflower":preload("res://assets/recipe/icons/moonflower.png"),
	"tree":preload("res://assets/recipe/icons/tree.png"),
	"gravestone":preload("res://assets/recipe/icons/gravestone.png"),
	"lantern":preload("res://assets/recipe/icons/lantern.png"),
	"spell":preload("res://assets/recipe/icons/spell.png"),
}
const CAULDRON := Vector2(800, 525)
const START_POSITION := Vector2(800, 635)
const WORLD_SIZE := Vector2(1600, 1067)
const MOVEMENT_BOUNDS := Rect2(90, 90, 1420, 887)
const WALKABLE_MASK_TEXTURE := preload("res://assets/hollow/hollow_walkable_mask.png")
# Same forgiving feet-sized footprint as the Mooncorn Maze.
const MASK_SAMPLE_OFFSETS := [
	Vector2.ZERO,
	Vector2(6, 0), Vector2(-6, 0), Vector2(0, 5), Vector2(0, -5),
	Vector2(4, 4), Vector2(-4, 4), Vector2(4, -4), Vector2(-4, -4),
]
var witch: HollowWitch
var camera: Camera2D
var walkable_mask: Image
var collected: Array[String] = []
var deposited: Array[String] = []
var pickup_sprites: Dictionary = {}
var cauldron: Sprite2D
var spell: Sprite2D
var active := false
var won := false
var elapsed := 0.0
var age := 0.0
var completion_age := 0.0
var nearest := ""
var glows: Array[Sprite2D] = []
var companion_witches: Array[HollowWitch] = []
var companion_names: Array[String] = []
var bubbles: Array[Sprite2D] = []
var bubble_origins: Array[Vector2] = []
var cauldron_home := Vector2.ZERO
var companion_dialogue_index := {"Violet":0, "Amber":0, "Hazel":0}
var environment_dialogue_index: Array[int] = []
var recipe_order: Array[String] = []
var interaction_markers: Array[Label] = []
var interaction_marker_origins: Array[Vector2] = []
func _ready() -> void:
	walkable_mask = WALKABLE_MASK_TEXTURE.get_image()
	recipe_order = _new_recipe_order()
	for _landmark in ENVIRONMENT_INTERACTIONS:
		environment_dialogue_index.append(0)
	var terrain := Sprite2D.new()
	terrain.texture = preload("res://assets/hollow/map.png")
	terrain.centered = false
	terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(terrain)
	cauldron_home = CAULDRON + Vector2(0, -35)
	cauldron = _sprite("cauldron", cauldron_home, 1.05)
	cauldron.z_index = 3
	_build_cauldron_bubbles()
	_build_companion_witches()
	_build_interaction_markers()
	for ingredient in INGREDIENTS:
		var glow := _sprite("spell", ingredient.pos + Vector2(0, -15), 0.48)
		glow.modulate = Color(0.9, 0.85, 1.0, 0.3)
		glows.append(glow)
		var icon := _sprite(ingredient.id, ingredient.pos + Vector2(0, -17), 0.46)
		pickup_sprites[ingredient.id] = icon
	witch = HollowWitch.new()
	witch.position = START_POSITION
	witch.set_movement_bounds(MOVEMENT_BOUNDS)
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
	spell = _sprite("spell", CAULDRON + Vector2(0, -75), 2.0)
	spell.visible = false
	spell.z_index = 10

func _build_companion_witches() -> void:
	var profiles := [
		{"name":"Violet", "position":Vector2(800, 405), "tint":Color("c58cff"), "label":Color("d7b1ff")},
		{"name":"Amber", "position":Vector2(914, 545), "tint":Color("ffad72"), "label":Color("ffc28c")},
		{"name":"Hazel", "position":Vector2(686, 545), "tint":Color("9eea7d"), "label":Color("baf49b")},
	]
	for profile: Dictionary in profiles:
		var companion := HollowWitch.new()
		companion.position = profile.position
		companion.z_index = 4 if profile.name != "Hazel" else 2
		companion.modulate = profile.tint
		companion.active = false
		add_child(companion)
		companion_witches.append(companion)
		companion_names.append(profile.name)
		var nameplate := Label.new()
		nameplate.text = profile.name
		nameplate.position = Vector2(-45, -82)
		nameplate.size = Vector2(90, 22)
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameplate.add_theme_font_size_override("font_size", 12)
		nameplate.add_theme_font_override("font", preload("res://assets/template/fonts/display/generic_heading.tres"))
		nameplate.add_theme_color_override("font_color", profile.label)
		nameplate.add_theme_color_override("font_shadow_color", Color("171020"))
		nameplate.add_theme_constant_override("shadow_offset_x", 1)
		nameplate.add_theme_constant_override("shadow_offset_y", 1)
		companion.add_child(nameplate)

func _build_cauldron_bubbles() -> void:
	var origins := [
		CAULDRON + Vector2(-25, -79),
		CAULDRON + Vector2(-7, -91),
		CAULDRON + Vector2(14, -82),
		CAULDRON + Vector2(29, -70),
	]
	for i in origins.size():
		var bubble := _sprite("spell", origins[i], 0.105 + i * 0.012)
		bubble.z_index = 6
		bubble.modulate = Color(0.54, 1.0, 0.68, 0.55)
		bubbles.append(bubble)
		bubble_origins.append(origins[i])

func _build_interaction_markers() -> void:
	for companion in companion_witches:
		_add_interaction_marker(companion.position + Vector2(28, -105), Color("f4c46f"))
	for landmark in ENVIRONMENT_INTERACTIONS:
		_add_interaction_marker(landmark.pos + Vector2(0, -55), Color("f4c46f"))

func _add_interaction_marker(pos: Vector2, color: Color) -> void:
	var marker := Label.new()
	marker.text = "?"
	marker.position = pos
	marker.size = Vector2(24, 28)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 21)
	marker.add_theme_font_override("font", preload("res://assets/template/fonts/display/generic_heading.tres"))
	marker.add_theme_color_override("font_color", color)
	marker.add_theme_color_override("font_shadow_color", Color("171020"))
	marker.add_theme_constant_override("shadow_offset_x", 2)
	marker.add_theme_constant_override("shadow_offset_y", 2)
	marker.z_index = 20
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marker)
	interaction_markers.append(marker)
	interaction_marker_origins.append(pos)

func _sprite(id: String, pos: Vector2, factor: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = ICONS[id]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = pos
	sprite.scale = Vector2.ONE * factor
	add_child(sprite)
	return sprite

func _is_walkable_position(candidate: Vector2) -> bool:
	if walkable_mask == null or not MOVEMENT_BOUNDS.has_point(candidate):
		return false
	# Live props are separate from the background-derived mask.
	if candidate.distance_to(CAULDRON + Vector2(0, -15)) < 34.0:
		return false
	for companion in companion_witches:
		if candidate.distance_to(companion.position) < 19.0:
			return false
	for offset in MASK_SAMPLE_OFFSETS:
		var sample := Vector2i(roundi(candidate.x + offset.x), roundi(candidate.y + offset.y))
		if sample.x < 0 or sample.y < 0 or sample.x >= walkable_mask.get_width() or sample.y >= walkable_mask.get_height():
			return false
		if walkable_mask.get_pixelv(sample).r < 0.5:
			return false
	return true

func _safe_restore_position(saved: Vector2) -> Vector2:
	if _is_walkable_position(saved):
		return saved
	# Old saves can now be inside a tree or in water. Keep progress, but move the
	# witch to nearby open ground instead of restoring into a blocked footprint.
	var nearest_position := START_POSITION
	var nearest_distance := INF
	for y in range(-96, 97, 4):
		for x in range(-96, 97, 4):
			var candidate := saved + Vector2(x, y)
			var distance := candidate.distance_squared_to(saved)
			if distance < nearest_distance and _is_walkable_position(candidate):
				nearest_position = candidate
				nearest_distance = distance
	return nearest_position

func set_active(value: bool) -> void:
	active = value and not won
	witch.active = active

func _process(delta: float) -> void:
	camera.position = witch.position
	if not active and not won:
		return
	age += 0.0 if bool(TuningStore.get_active_value("ui.reduced_motion", false)) else delta
	if active:
		elapsed += delta
		nearest = nearby_target()
	for i in INGREDIENTS.size():
		var entry: Dictionary = INGREDIENTS[i]
		var icon: Sprite2D = pickup_sprites[entry.id]
		icon.position.y = entry.pos.y - 17 + sin(age * 2.4 + i) * 3.0
		glows[i].scale = Vector2.ONE * (0.44 + sin(age * 2.0 + i) * 0.035)
	var motion_enabled := not bool(TuningStore.get_active_value("ui.reduced_motion", false))
	cauldron.position = cauldron_home + Vector2(0, sin(age * 4.0) * 0.8 if motion_enabled else 0.0)
	cauldron.scale = Vector2.ONE * (1.05 + (sin(age * 4.0) * 0.012 if motion_enabled else 0.0))
	cauldron.modulate = Color(1.0, 1.0, 1.0, 0.93 + sin(age * 3.0) * 0.07 if motion_enabled else 0.93)
	for i in bubbles.size():
		var cycle := fmod(age * (0.42 + i * 0.055) + i * 0.21, 1.0)
		var bubble: Sprite2D = bubbles[i]
		bubble.position = bubble_origins[i] + Vector2(sin(age * 3.4 + i) * 3.0, -cycle * 28.0)
		bubble.modulate.a = (0.12 + (1.0 - cycle) * 0.7) if motion_enabled else 0.38
	for i in interaction_markers.size():
		var marker: Label = interaction_markers[i]
		marker.position = interaction_marker_origins[i] + Vector2(0, sin(age * 2.8 + i) * 3.0 if motion_enabled else 0.0)
		marker.modulate.a = 0.72 + (sin(age * 3.4 + i) * 0.18 if motion_enabled else 0.0)
		if won:
			completion_age += 0.0 if bool(TuningStore.get_active_value("ui.reduced_motion", false)) else delta
			spell.rotation = sin(completion_age) * 0.08
			spell.scale = Vector2.ONE * (1.8 + sin(completion_age * 2.0) * 0.15)

func _new_recipe_order() -> Array[String]:
	var order: Array[String] = []
	for entry in INGREDIENTS:
		order.append(entry.id)
	order.shuffle()
	return order

func _valid_recipe_order(candidate: Variant) -> bool:
	if not candidate is Array or candidate.size() != INGREDIENTS.size():
		return false
	var valid_ids := {}
	for entry in INGREDIENTS:
		valid_ids[entry.id] = true
	var seen := {}
	for id in candidate:
		if not valid_ids.has(str(id)) or seen.has(str(id)):
			return false
		seen[str(id)] = true
	return true

func recipe_entry(id: String) -> Dictionary:
	for entry in INGREDIENTS:
		if entry.id == id:
			return entry
	return {}

func recipe_entries() -> Array:
	var entries: Array = []
	for id in recipe_order:
		entries.append(recipe_entry(id))
	return entries

func next_required() -> String:
	if deposited.size() >= INGREDIENTS.size():
		return ""
	return recipe_order[deposited.size()]

func nearby_target() -> String:
	if witch.position.distance_to(CAULDRON) < 92.0:
		return "cauldron"
	# Only one ingredient fits in the satchel at a time, and ingredients
	# must be gathered in recipe order -- so there's ever at most one
	# ingredient actually targetable: the single next-required one, and
	# only while the satchel is empty.
	if not collected.is_empty():
		return ""
	var required := next_required()
	if required.is_empty():
		return ""
	for entry in INGREDIENTS:
		if entry.id == required and witch.position.distance_to(entry.pos) < 65.0:
			return required
	return ""

func nearby_companion() -> int:
	if witch.position.distance_to(CAULDRON) < 92.0:
		return -1
	var closest := 76.0
	var result := -1
	for i in companion_witches.size():
		var distance: float = witch.position.distance_to(companion_witches[i].position)
		if distance < closest:
			closest = distance
			result = i
	return result

func nearby_environment() -> int:
	if witch.position.distance_to(CAULDRON) < 92.0:
		return -1
	var closest := 70.0
	var result := -1
	for i in ENVIRONMENT_INTERACTIONS.size():
		var distance: float = witch.position.distance_to(ENVIRONMENT_INTERACTIONS[i].pos)
		if distance < closest:
			closest = distance
			result = i
	return result

func environment_prompt(index: int) -> String:
	if index < 0 or index >= ENVIRONMENT_INTERACTIONS.size():
		return "Inspect the surroundings"
	return ENVIRONMENT_INTERACTIONS[index].prompt

# The nearby ingredient (if any) that's out of reach right now -- either
# because something's already in the satchel, or because it's not next in
# the recipe order -- for a specific "not yet" message instead of the
# generic "nothing here" one.
func nearby_locked() -> String:
	var required := next_required()
	var closest := 65.0
	var result := ""
	for entry in INGREDIENTS:
		if entry.id in collected or entry.id in deposited or (entry.id == required and collected.is_empty()):
			continue
		var distance: float = witch.position.distance_to(entry.pos)
		if distance < closest:
			closest = distance
			result = entry.id
	return result

func interact() -> void:
	if not active:
		return
	var target := nearby_target()
	if target == "cauldron":
		if collected.is_empty():
			message.emit("The cauldron is hungry. Find a glowing ingredient!")
			return
		# Exactly one item in the satchel at a time (see nearby_target()),
		# so there's only ever one to deposit here.
		var id: String = collected[0]
		collected.clear()
		deposited.append(id)
		message.emit("%s added to the cauldron." % ingredient_name(id))
		# The real cauldron prop (if one's connected -- see CauldronBridge)
		# handles the actual spectacle: a witch announcing the ingredient,
		# a splash, and a color flash reflecting it. This screen only ever
		# shows plain state, not a faked stand-in for that.
		CauldronBridge.notify_deposit(id)
		recipe_changed.emit()
		if deposited.size() == INGREDIENTS.size():
			won = true
			set_active(false)
			cauldron.texture = ICONS.cauldron_spell
			spell.visible = true
			CauldronBridge.notify_victory()
			spell_completed.emit()
	elif not target.is_empty():
		collected.append(target)
		(pickup_sprites[target] as Sprite2D).visible = false
		for i in INGREDIENTS.size():
			if INGREDIENTS[i].id == target:
				glows[i].visible = false
		message.emit("Found %s. Tucked safely in your satchel." % ingredient_name(target))
		recipe_changed.emit()
	else:
		var companion_index := nearby_companion()
		if companion_index >= 0:
			var companion_name: String = companion_names[companion_index]
			var lines: Array = COMPANION_DIALOGUE[companion_name]
			var line_index: int = int(companion_dialogue_index[companion_name])
			message.emit("%s: \"%s\"" % [companion_name, lines[line_index]])
			# The real witch of the same name speaks her own line for real
			# on the physical cauldron -- see game_bridge.py's
			# HOLLOW_COMPANION_LINES, which must stay in sync with
			# COMPANION_DIALOGUE above.
			CauldronBridge.notify_companion(companion_name, line_index)
			companion_dialogue_index[companion_name] = (line_index + 1) % lines.size()
			return
		var environment_index := nearby_environment()
		if environment_index >= 0:
			var landmark: Dictionary = ENVIRONMENT_INTERACTIONS[environment_index]
			var epitaphs: Array = landmark.epitaphs
			var epitaph_index: int = environment_dialogue_index[environment_index]
			message.emit("%s: \"%s\"" % [landmark.name, epitaphs[epitaph_index]])
			CauldronBridge.notify_landmark("hollow", landmark.id, epitaph_index)
			environment_dialogue_index[environment_index] = (epitaph_index + 1) % epitaphs.size()
			return
	if not collected.is_empty():
		message.emit("Your satchel is full. Bring it to the cauldron first.")
	else:
		var locked := nearby_locked()
		if not locked.is_empty():
			message.emit("Not yet! The spell calls for %s first." % ingredient_name(next_required()))
		else:
			message.emit("Look for sparkling ingredients along the woodland trails.")

func ingredient_name(id: String) -> String:
	for entry in INGREDIENTS:
		if entry.id == id:
			return entry.name
	return id

func restore(data: Dictionary) -> void:
	collected.clear()
	deposited.clear()
	var saved_order: Variant = data.get("recipe_order", [])
	if _valid_recipe_order(saved_order):
		recipe_order.clear()
		for id in saved_order:
			recipe_order.append(str(id))
	else:
		recipe_order = _new_recipe_order()
	for entry in INGREDIENTS:
		if entry.id in data.get("deposited", []):
			deposited.append(entry.id)
		elif entry.id in data.get("collected", []):
			collected.append(entry.id)
		var hidden: bool = entry.id in collected or entry.id in deposited
		(pickup_sprites[entry.id] as Sprite2D).visible = not hidden
		glows[INGREDIENTS.find(entry)].visible = not hidden
	elapsed = maxf(0.0, float(data.get("elapsed", 0)))
	var x := clampf(float(data.get("x", 800)), 100.0, 1500.0)
	var y := clampf(float(data.get("y", 635)), 100.0, 960.0)
	witch.position = _safe_restore_position(Vector2(x, y))
	camera.position = witch.position
	camera.reset_smoothing()

func snapshot() -> Dictionary:
	return {"collected":collected.duplicate(), "deposited":deposited.duplicate(), "recipe_order":recipe_order.duplicate(), "elapsed":elapsed, "x":witch.position.x, "y":witch.position.y}
