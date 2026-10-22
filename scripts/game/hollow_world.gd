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
var witch: HollowWitch
var camera: Camera2D
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
func _ready() -> void:
	var terrain := Sprite2D.new()
	terrain.texture = preload("res://assets/hollow/map.png")
	terrain.centered = false
	terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(terrain)
	# Water and selected tree/stone footprints are solid; open woodland remains walkable.
	for rect in [Rect2(1065, 780, 345, 140), Rect2(1298, 625, 120, 65), Rect2(5, 5, 75, 1067), Rect2(1520, 5, 80, 1067)]:
		_add_rect_collision(rect)
	for footprint in [Vector3(265, 400, 36), Vector3(432, 410, 44), Vector3(520, 430, 34), Vector3(565, 260, 48), Vector3(660, 225, 30), Vector3(1015, 263, 42), Vector3(1215, 432, 48), Vector3(1130, 461, 34), Vector3(633, 740, 49), Vector3(670, 915, 46), Vector3(980, 777, 36), Vector3(264, 169, 24), Vector3(465, 180, 18)]:
		_add_circle_collision(Vector2(footprint.x, footprint.y), footprint.z)
	cauldron_home = CAULDRON + Vector2(0, -35)
	cauldron = _sprite("cauldron", cauldron_home, 1.05)
	cauldron.z_index = 3
	_add_circle_collision(CAULDRON + Vector2(0, -15), 28)
	_build_cauldron_bubbles()
	_build_companion_witches()
	for ingredient in INGREDIENTS:
		var glow := _sprite("spell", ingredient.pos + Vector2(0, -15), 0.48)
		glow.modulate = Color(0.9, 0.85, 1.0, 0.3)
		glows.append(glow)
		var icon := _sprite(ingredient.id, ingredient.pos + Vector2(0, -17), 0.46)
		pickup_sprites[ingredient.id] = icon
	witch = HollowWitch.new()
	witch.position = Vector2(800, 635)
	witch.z_index = 5
	add_child(witch)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1600
	camera.limit_bottom = 1067
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

func _sprite(id: String, pos: Vector2, factor: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = ICONS[id]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = pos
	sprite.scale = Vector2.ONE * factor
	add_child(sprite)
	return sprite

func _add_rect_collision(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	node.shape = shape
	body.add_child(node)
	add_child(body)

func _add_circle_collision(pos: Vector2, radius: float) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	node.shape = shape
	body.add_child(node)
	add_child(body)

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
	if won:
		completion_age += 0.0 if bool(TuningStore.get_active_value("ui.reduced_motion", false)) else delta
		spell.rotation = sin(completion_age) * 0.08
		spell.scale = Vector2.ONE * (1.8 + sin(completion_age * 2.0) * 0.15)

func next_required() -> String:
	if deposited.size() >= INGREDIENTS.size():
		return ""
	return INGREDIENTS[deposited.size()].id

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
	elif not collected.is_empty():
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
	witch.position = Vector2(x, y)
	camera.position = witch.position
	camera.reset_smoothing()

func snapshot() -> Dictionary:
	return {"collected":collected.duplicate(), "deposited":deposited.duplicate(), "elapsed":elapsed, "x":witch.position.x, "y":witch.position.y}
