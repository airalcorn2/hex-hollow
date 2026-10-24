extends Control

const WorldScript = preload("res://scripts/game/hollow_world.gd")
const CornMazeScript = preload("res://scripts/game/corn_maze.gd")
const Licenses = preload("res://scripts/manus/open_source_licenses.gd")
const CREAM := Color("f4e7cd")
const MUTED := Color("b7a6c2")
const MINT := Color("a4e4ba")
const GOLD := Color("e5ae67")
var world
var hud: Control
var overlay: Control
var rows: Array[Label] = []
var row_ids: Array[String] = []
var progress_label: Label
var satchel_label: Label
var prompt_label: Label
var notice_label: Label
var region_label: Label
var notice_age := 0.0
var save_age := 0.0
var state := "title"
var saved: Dictionary = {}
var current_level := 1

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("171020"))
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	for code in [KEY_E, KEY_SPACE]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		InputMap.action_add_event("interact", key)
	saved = SaveStore.get_adventure()
	_show_title()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == "playing":
			_toggle_pause()
		elif state == "paused":
			_resume()
	elif event.is_action_pressed("interact") and state == "playing":
		world.interact()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and state == "title":
		_start_new_run()

func _process(delta: float) -> void:
	if state != "playing" or world == null:
		return
	if current_level == 2:
		_process_maze(delta)
		return
	notice_age += delta
	save_age += delta
	if save_age > 4.0:
		_save_progress()
		save_age = 0.0
	var target: String = world.nearby_target()
	if target == "cauldron":
		prompt_label.text = "[ E / SPACE ]  Add %d to the cauldron" % world.collected.size() if not world.collected.is_empty() else "Your cauldron · %d / 6 brewed" % world.deposited.size()
	elif not target.is_empty():
		prompt_label.text = "[ E / SPACE ]  Gather " + world.ingredient_name(target)
	elif world.nearby_companion() >= 0:
		prompt_label.text = "[ E / SPACE ]  Talk to " + world.companion_names[world.nearby_companion()]
	elif world.nearby_environment() >= 0:
		prompt_label.text = "[ E / SPACE ]  " + world.environment_prompt(world.nearby_environment())
	else:
		prompt_label.text = "Follow the woodland trails. Look for a magical glow."
	notice_label.modulate.a = 1.0 if notice_age < 5.0 else 0.0
	var pos: Vector2 = world.witch.position
	region_label.text = "THE CAULDRON CLEARING"
	if pos.y < 350:
		region_label.text = "THE OLD GRAVEYARD" if pos.x < 650 else ("THE PUMPKIN PATCH" if pos.x > 1050 else "RAVEN'S WALK")
	elif pos.y > 660:
		region_label.text = "MOONCAP GROVE" if pos.x < 650 else ("THE WHISPERING POND" if pos.x > 1030 else "THE SOUTHERN TRAIL")

func _clear() -> void:
	for child in get_children():
		child.queue_free()
	world = null
	hud = null
	overlay = null
	rows.clear()
	row_ids.clear()

func _label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color = CREAM, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if heading:
		label.add_theme_font_override("font", preload("res://assets/template/fonts/display/generic_heading.tres"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _panel(parent: Node, rect: Rect2, color: Color, border: Color = Color("49364e"), radius: int = 14) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

func _button(parent: Node, text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = GOLD if primary else Color("34253e")
	normal.border_color = GOLD if primary else Color("665077")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f1c78e") if primary else Color("50335e")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color("281b2c") if primary else CREAM)
	button.add_theme_color_override("font_hover_color", Color("281b2c") if primary else CREAM)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _picture(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.position = rect.position
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.size = texture.get_size()
	image.scale = rect.size / texture.get_size()
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _show_title() -> void:
	state = "title"
	_clear()
	var art := _picture(self, preload("res://assets/share/cover.png"), Rect2(0, 0, 1280, 720))
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_panel(self, Rect2(0, 628, 1280, 172), Color("201527"), Color("6c4c43"), 0)
	_label(self, "A LITTLE MISCHIEF. A LITTLE MAGIC.", Vector2(44, 645), Vector2(650, 28), 14, GOLD, true)
	_label(self, "Gather six enchanted ingredients. Brew a spell before the night is through.", Vector2(44, 684), Vector2(735, 30), 20)
	_label(self, "WASD / arrows to wander    ·    E / Space to gather & brew    ·    Esc to pause", Vector2(44, 734), Vector2(820, 28), 15, MUTED)
	_button(self, "Enter the hollow  →", Rect2(924, 661, 310, 50), _start_new_run, true)
	_button(self, "Practice the Mooncorn Maze", Rect2(924, 718, 310, 38), _practice_maze)
	var has_incomplete_save := false
	if not saved.is_empty():
		has_incomplete_save = saved.get("collected", []).size() < 3 if int(saved.get("level", 1)) == 2 else saved.get("deposited", []).size() < 6
	if has_incomplete_save:
		var continue_text := "Continue in the maze" if int(saved.get("level", 1)) == 2 else "Continue your spell"
		_button(self, continue_text, Rect2(924, 760, 310, 34), _continue_run)
	else:
		_label(self, "A cozy, moonlit adventure", Vector2(931, 765), Vector2(298, 25), 15, MUTED)
	_button(self, "Open Source Licenses", Rect2(22, 17, 195, 33), func(): Licenses.open(self))

func _start_new_run() -> void:
	_begin_run({})

func _practice_maze() -> void:
	_begin_maze({})

func _continue_run() -> void:
	if int(saved.get("level", 1)) == 2:
		_begin_maze(saved)
	else:
		_begin_run(saved)

func _begin_run(data: Dictionary) -> void:
	_clear()
	current_level = 1
	state = "playing"
	TuningStore.begin_run()
	var container := SubViewportContainer.new()
	container.position = Vector2(24, 116)
	container.size = Vector2(956, 612)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(956, 612)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	add_child(container)
	world = WorldScript.new()
	viewport.add_child(world)
	if not data.is_empty():
		world.restore(data)
	world.recipe_changed.connect(_recipe_changed)
	world.message.connect(_show_message)
	world.spell_completed.connect(_completed)
	world.set_active(true)
	_build_hud()
	_recipe_changed()
	_show_message("The midnight spell awaits. Find six ingredients—and follow the gold ? markers for secrets!")

func _begin_maze(data: Dictionary = {}) -> void:
	_clear()
	current_level = 2
	state = "playing"
	TuningStore.begin_run()
	var container := SubViewportContainer.new()
	container.position = Vector2(24, 116)
	container.size = Vector2(956, 612)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(956, 612)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	add_child(container)
	world = CornMazeScript.new()
	viewport.add_child(world)
	if not data.is_empty():
		world.restore(data)
	world.message.connect(_show_message)
	world.maze_completed.connect(_maze_completed)
	world.set_active(true)
	_build_maze_hud()
	_show_message("Level 2: the Mooncorn Maze. Gather three fall treats and bring them to the cauldron!")

func _process_maze(delta: float) -> void:
	notice_age += delta
	save_age += delta
	if save_age > 4.0:
		_save_progress()
		save_age = 0.0
	var target: String = world.nearby_target()
	if not target.is_empty():
		prompt_label.text = "[ E / SPACE ]  Gather " + world.target_name(target)
	elif world.nearby_cauldron():
		prompt_label.text = "[ E / SPACE ]  Drop the treats into the cauldron" if world.collected.size() == 3 else "The cauldron is waiting · Find all 3 fall treats"
	elif world.nearby_environment() >= 0:
		prompt_label.text = "[ E / SPACE ]  " + world.environment_prompt(world.nearby_environment())
	else:
		prompt_label.text = "Sniff out the fall treats · Inspect landmarks marked with ?"
	progress_label.text = "%d / 3 fall treats found" % world.collected.size()
	satchel_label.text = "TREATS  ·  %d / 3" % world.collected.size()
	notice_label.modulate.a = 1.0 if notice_age < 5.0 else 0.0
	region_label.text = "THE MOONCORN MAZE"

func _build_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_picture(hud, preload("res://assets/share/favicon.png"), Rect2(24, 18, 55, 55))
	_label(hud, "HEX HOLLOW", Vector2(91, 18), Vector2(430, 43), 30, CREAM, true)
	_label(hud, "A witch's midnight gathering", Vector2(94, 65), Vector2(400, 25), 14, MUTED)
	_label(hud, "HALLOWEEN NIGHT", Vector2(900, 27), Vector2(260, 25), 13, GOLD, true)
	_button(hud, "Ⅱ", Rect2(1198, 24, 56, 45), _toggle_pause)
	region_label = _label(hud, "THE CAULDRON CLEARING", Vector2(27, 88), Vector2(790, 23), 12, GOLD, true)
	_panel(hud, Rect2(1004, 116, 252, 612), Color("281d30"))
	_label(hud, "THE MIDNIGHT", Vector2(1026, 139), Vector2(218, 28), 13, GOLD, true)
	_label(hud, "Spellbook", Vector2(1024, 173), Vector2(215, 38), 26, CREAM, true)
	_label(hud, "Six ingredients. One little spell.", Vector2(1027, 222), Vector2(210, 25), 13, MUTED)
	progress_label = _label(hud, "0 / 6 brewed", Vector2(1027, 265), Vector2(209, 30), 16, MINT)
	var recipe_entries: Array = world.recipe_entries()
	for i in recipe_entries.size():
		var item: Dictionary = recipe_entries[i]
		var y: float = 310 + i * 51
		_picture(hud, WorldScript.ICONS[item.id], Rect2(1019, y - 6, 46, 46))
		rows.append(_label(hud, item.name, Vector2(1072, y), Vector2(173, 24), 14))
		row_ids.append(item.id)
		_label(hud, item.hint.split(" · ")[0], Vector2(1072, y + 23), Vector2(173, 20), 11, MUTED)
	_panel(hud, Rect2(1022, 634, 215, 72), Color("34253e"), Color("56415e"), 8)
	satchel_label = _label(hud, "SATCHEL  ·  0", Vector2(1034, 642), Vector2(190, 24), 13, GOLD, true)
	_label(hud, "Bring your finds to the cauldron", Vector2(1034, 674), Vector2(190, 22), 11, MUTED)
	_panel(hud, Rect2(24, 740, 1232, 43), Color("281d30"), Color("49364e"), 8)
	prompt_label = _label(hud, "", Vector2(44, 750), Vector2(850, 24), 15, CREAM)
	_label(hud, "WASD / ARROWS   ·   E / SPACE INTERACT   ·   ESC PAUSE", Vector2(875, 752), Vector2(370, 22), 11, MUTED)
	notice_label = _label(hud, "", Vector2(44, 133), Vector2(903, 36), 15, CREAM)
	notice_label.add_theme_color_override("font_shadow_color", Color("171020"))
	notice_label.add_theme_constant_override("shadow_offset_x", 1)
	notice_label.add_theme_constant_override("shadow_offset_y", 2)

func _build_maze_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_picture(hud, preload("res://assets/share/favicon.png"), Rect2(24, 18, 55, 55))
	_label(hud, "HEX HOLLOW · LEVEL 2", Vector2(91, 18), Vector2(500, 43), 30, CREAM, true)
	_label(hud, "The Mooncorn Maze", Vector2(94, 65), Vector2(400, 25), 14, MUTED)
	_label(hud, "HALLOWEEN NIGHT", Vector2(900, 27), Vector2(260, 25), 13, GOLD, true)
	_button(hud, "Ⅱ", Rect2(1198, 24, 56, 45), _toggle_pause)
	region_label = _label(hud, "THE MOONCORN MAZE", Vector2(27, 88), Vector2(790, 23), 12, GOLD, true)
	_panel(hud, Rect2(1004, 116, 252, 612), Color("281d30"))
	_label(hud, "THE SECOND SPELL", Vector2(1026, 139), Vector2(218, 28), 13, GOLD, true)
	_label(hud, "Mooncorn Maze", Vector2(1024, 173), Vector2(215, 38), 25, CREAM, true)
	_label(hud, "Three treats. One harvest brew.", Vector2(1027, 222), Vector2(210, 25), 13, MUTED)
	progress_label = _label(hud, "0 / 3 fall treats found", Vector2(1027, 265), Vector2(209, 30), 16, MINT)
	for i in CornMazeScript.TREAT_DATA.size():
		var y: float = 310 + i * 51
		_picture(hud, CornMazeScript.TREAT_ICONS[i], Rect2(1019, y - 6, 46, 46))
		_label(hud, CornMazeScript.TREAT_DATA[i].name, Vector2(1072, y + 8), Vector2(173, 24), 14)
	_label(hud, "Bring all three to the cauldron\nin the lantern gate.", Vector2(1027, 470), Vector2(205, 60), 13, MUTED)
	_panel(hud, Rect2(1022, 634, 215, 72), Color("34253e"), Color("56415e"), 8)
	satchel_label = _label(hud, "TREATS  ·  0 / 3", Vector2(1034, 642), Vector2(190, 24), 13, GOLD, true)
	_label(hud, "The corn remembers the way in", Vector2(1034, 674), Vector2(190, 22), 11, MUTED)
	_panel(hud, Rect2(24, 740, 1232, 43), Color("281d30"), Color("49364e"), 8)
	prompt_label = _label(hud, "", Vector2(44, 750), Vector2(850, 24), 15, CREAM)
	_label(hud, "WASD / ARROWS   ·   E / SPACE INTERACT   ·   ESC PAUSE", Vector2(875, 752), Vector2(370, 22), 11, MUTED)
	notice_label = _label(hud, "", Vector2(44, 133), Vector2(903, 36), 15, CREAM)
	notice_label.add_theme_color_override("font_shadow_color", Color("171020"))
	notice_label.add_theme_constant_override("shadow_offset_x", 1)
	notice_label.add_theme_constant_override("shadow_offset_y", 2)

func _recipe_changed() -> void:
	if progress_label == null:
		return
	progress_label.text = "%d / 6 ingredients brewed" % world.deposited.size()
	satchel_label.text = "SATCHEL  ·  %d INGREDIENT%s" % [world.collected.size(), "" if world.collected.size() == 1 else "S"]
	# Ingredients must now be gathered in order (see hollow_world.gd's
	# next_required()), so the sidebar highlights which one's actually
		# next -- without this, "why can't I pick that one up yet" has no
		# visible answer.
	var required: String = world.next_required()
	for i in rows.size():
		var id: String = row_ids[i]
		var item: Dictionary = world.recipe_entry(id)
		rows[i].text = item.name
		if id in world.deposited:
			rows[i].text = "✓ " + rows[i].text
			rows[i].add_theme_color_override("font_color", MINT)
		elif id in world.collected:
			rows[i].add_theme_color_override("font_color", GOLD)
		elif id == required:
			rows[i].add_theme_color_override("font_color", GOLD)
		else:
			rows[i].add_theme_color_override("font_color", MUTED)
	_save_progress()

func _show_message(text: String) -> void:
	if notice_label != null:
		notice_label.text = text
		notice_age = 0.0

func _save_progress() -> void:
	if world != null:
		saved = world.snapshot()
		saved["level"] = current_level
		SaveStore.set_adventure(saved)

func _toggle_pause() -> void:
	if state != "playing":
		return
	state = "paused"
	world.set_active(false)
	_save_progress()
	_make_overlay("A moment by moonlight", "Your ingredients are safe. The forest can wait.")
	_button(overlay, "Return to the hollow", Rect2(470, 388, 340, 48), _resume, true)
	_button(overlay, "Start a new spell", Rect2(470, 450, 340, 46), _start_new_run)
	_button(overlay, "Back to title", Rect2(470, 512, 340, 46), _show_title)

func _resume() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null
	state = "playing"
	world.set_active(true)

func _make_overlay(title: String, subtitle: String) -> void:
	overlay = Control.new()
	overlay.size = Vector2(1280, 800)
	add_child(overlay)
	_panel(overlay, Rect2(0, 0, 1280, 800), Color(0.07, 0.035, 0.1, 0.82), Color.TRANSPARENT, 0)
	_panel(overlay, Rect2(407, 191, 466, 414), Color("281d30"), Color("9b735b"), 18)
	_picture(overlay, preload("res://assets/share/favicon.png"), Rect2(608, 214, 64, 64))
	var heading := _label(overlay, title, Vector2(425, 285), Vector2(430, 42), 23, CREAM, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := _label(overlay, subtitle, Vector2(435, 336), Vector2(410, 45), 14, MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _completed() -> void:
	state = "complete"
	_save_progress()
	TuningStore.end_run()
	await get_tree().create_timer(1.6).timeout
	if state != "complete":
		return
	_make_overlay(
		"The spell is complete!",
		"Six enchanted ingredients, one perfect brew.\nNow find the Mooncorn Maze beyond the clearing."
	)
	_button(overlay, "Enter the corn maze  →", Rect2(470, 428, 340, 48), _begin_maze, true)
	_button(overlay, "Brew another spell", Rect2(470, 490, 340, 46), _start_new_run)
	_button(overlay, "Back to title", Rect2(470, 552, 340, 40), _show_title)

func _maze_completed() -> void:
	state = "complete"
	_save_progress()
	TuningStore.end_run()
	await get_tree().create_timer(1.2).timeout
	if state != "complete":
		return
	_make_overlay(
		"The maze is conquered!",
		"Three fall treats and one bubbling harvest brew.\nThe hollow has no more secrets tonight."
	)
	_button(overlay, "Brew another spell  →", Rect2(470, 428, 340, 48), _start_new_run, true)
	_button(overlay, "Back to title", Rect2(470, 490, 340, 46), _show_title)
