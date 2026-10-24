class_name CornMazeWorld
extends Node2D

signal message(text: String)
signal maze_completed

const CELL := 64
const GRID_W := 19
const GRID_H := 13
const WORLD_SIZE := Vector2(GRID_W * CELL, GRID_H * CELL)
const START_CELL := Vector2i(1, 1)
const EXIT_CELL := Vector2i(17, 11)
const CHARM_CELLS := [Vector2i(3, 3), Vector2i(13, 3), Vector2i(9, 9)]
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
const CORN_TUFT_TEXTURE := preload("res://assets/corn-maze/corn_hedge_tuft_clean.png")

var witch: HollowWitch
var camera: Camera2D
var active := false
var won := false
var elapsed := 0.0
var age := 0.0
var walls: Array = []
var charm_sprites: Array[Sprite2D] = []
var wall_sprites: Array[Sprite2D] = []
var collected: Array[String] = []
var exit_marker: Label

func _ready() -> void:
	_generate_maze()
	_build_visuals()
	_build_collisions()
	_build_charm_sprites()
	_build_exit_marker()
	witch = HollowWitch.new()
	witch.position = cell_position(START_CELL)
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

func _generate_maze() -> void:
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			row.append(true)
		walls.append(row)
	var stack: Array[Vector2i] = [START_CELL]
	walls[START_CELL.y][START_CELL.x] = false
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var shuffled := directions.duplicate()
		shuffled.shuffle()
		var carved := false
		for direction: Vector2i in shuffled:
			var next := current + direction * 2
			if next.x <= 0 or next.x >= GRID_W - 1 or next.y <= 0 or next.y >= GRID_H - 1:
				continue
			if not walls[next.y][next.x]:
				continue
			walls[current.y + direction.y][current.x + direction.x] = false
			walls[next.y][next.x] = false
			stack.append(next)
			carved = true
			break
		if not carved:
			stack.pop_back()
	walls[EXIT_CELL.y][EXIT_CELL.x] = false
	walls[EXIT_CELL.y][EXIT_CELL.x - 1] = false

func _build_collisions() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			if walls[y][x]:
				_add_wall_collision(Vector2(x * CELL + CELL * 0.5, y * CELL + CELL * 0.5))
	for rect in [Rect2(-16, 0, 16, WORLD_SIZE.y), Rect2(WORLD_SIZE.x, 0, 16, WORLD_SIZE.y), Rect2(0, -16, WORLD_SIZE.x, 16), Rect2(0, WORLD_SIZE.y, WORLD_SIZE.x, 16)]:
		_add_rect_collision(rect)

func _add_wall_collision(center: Vector2) -> void:
	_add_rect_collision(Rect2(center - Vector2(CELL * 0.5, CELL * 0.5), Vector2(CELL, CELL)))

func _add_rect_collision(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	node.shape = shape
	body.add_child(node)
	add_child(body)

func cell_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL * 0.5)

func _build_charm_sprites() -> void:
	for i in CHARM_CELLS.size():
		var sprite := Sprite2D.new()
		sprite.texture = CHARM_ICONS[i]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = cell_position(CHARM_CELLS[i]) + Vector2(0, -10)
		sprite.scale = Vector2.ONE * 0.48
		sprite.modulate = CHARM_DATA[i].color
		sprite.z_index = 3
		add_child(sprite)
		charm_sprites.append(sprite)

func _build_visuals() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			if not walls[y][x]:
				continue
			var hedge := Sprite2D.new()
			hedge.texture = CORN_TUFT_TEXTURE
			hedge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			hedge.position = Vector2(x * CELL + CELL * 0.5, y * CELL + CELL * 0.5) + Vector2(0, 3)
			hedge.scale = Vector2(68, 76) / CORN_TUFT_TEXTURE.get_size()
			hedge.flip_h = (x + y) % 2 == 0
			hedge.modulate = Color(0.88 + (x % 3) * 0.035, 0.92 + (y % 2) * 0.03, 0.84, 1.0)
			hedge.z_index = 2
			add_child(hedge)
			wall_sprites.append(hedge)

func _build_exit_marker() -> void:
	exit_marker = _marker("EXIT", cell_position(EXIT_CELL) + Vector2(-30, -48), Color("a4e4ba"))

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
	for y in range(GRID_H):
		for x in range(GRID_W):
			if walls[y][x]:
				continue
			var path_rect := Rect2(x * CELL + 5, y * CELL + 5, CELL - 10, CELL - 10)
			draw_rect(path_rect, Color(0.08, 0.11, 0.08, 0.34))
			draw_rect(path_rect, Color(0.42, 0.31, 0.20, 0.18), false, 2.0)
	draw_circle(cell_position(EXIT_CELL), 25.0, Color("3d6749"))
	draw_arc(cell_position(EXIT_CELL), 27.0, 0.0, TAU, 24, Color("a4e4ba"), 2.0)

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
		charm_sprites[i].position.y = cell_position(CHARM_CELLS[i]).y - 10 + sin(age * 2.4 + i) * 3.0
	if won:
		exit_marker.modulate.a = 0.7 + sin(age * 3.0) * 0.2

func nearby_target() -> String:
	for i in CHARM_DATA.size():
		if CHARM_DATA[i].id in collected:
			continue
		if witch.position.distance_to(cell_position(CHARM_CELLS[i])) < 52.0:
			return CHARM_DATA[i].id
	return ""

func target_name(id: String) -> String:
	for entry in CHARM_DATA:
		if entry.id == id:
			return entry.name
	return id

func nearby_exit() -> bool:
	return witch.position.distance_to(cell_position(EXIT_CELL)) < 62.0

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
	witch.position = Vector2(float(data.get("x", cell_position(START_CELL).x)), float(data.get("y", cell_position(START_CELL).y)))
	camera.position = witch.position
	camera.reset_smoothing()

func snapshot() -> Dictionary:
	return {"level":2, "collected":collected.duplicate(), "elapsed":elapsed, "x":witch.position.x, "y":witch.position.y}
