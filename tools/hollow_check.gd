extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var saves = root.get_node("SaveStore")
	var original: Dictionary = saves.get_adventure()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._start_new_run()
	await process_frame
	var world = main.world
	assert(world.witch.movement_validator.is_valid(), "The Hollow uses mask-validated movement")
	assert(world._is_walkable_position(world.START_POSITION), "The Hollow spawn is walkable")
	for radius in [60.0, 150.0, 190.0, 200.0]:
		for i in 32:
			var angle := TAU * i / 32.0
			var point: Vector2 = world.CAULDRON + Vector2(cos(angle), sin(angle)) * radius
			assert(world._is_walkable_position(point), "Decorative weeds do not block the cauldron clearing")
	world.witch.position = world.CAULDRON + Vector2(175, 0)
	for i in range(1, 25):
		var angle := TAU * i / 24.0
		var destination: Vector2 = world.CAULDRON + Vector2(cos(angle), sin(angle)) * 175.0
		var motion: Vector2 = destination - world.witch.position
		world.witch.move_direction(motion, motion.length() / world.witch.speed)
		assert(world.witch.position.distance_to(destination) < 0.5, "Witch can walk a full lap through the clearing's weed ring")
	assert(not world._is_walkable_position(world.CAULDRON + Vector2(0, -15)), "The clearing exception keeps the cauldron solid")
	for companion in world.companion_witches:
		assert(not world._is_walkable_position(companion.position), "The clearing exception keeps companion witches solid")
	world.witch.position = world.START_POSITION
	world.witch.move_direction(Vector2.DOWN, 0.3)
	assert(world.witch.position.y > world.START_POSITION.y + 40.0, "Witch can leave the Hollow spawn")
	world.witch.position = Vector2(984, 266)
	world.witch.move_direction(Vector2.RIGHT, 0.5)
	assert(world.witch.position.x < 1030.0 and world._is_walkable_position(world.witch.position), "Woodland foliage blocks movement without trapping the witch")
	world.witch.position = Vector2(1264, 705)
	assert(world._is_walkable_position(world.witch.position), "The bridge entrance is walkable")
	world.witch.move_direction(Vector2.RIGHT, 0.55)
	assert(world.witch.position.x > 1368.0, "Witch can cross the wooden bridge")
	world.witch.position = Vector2(1320, 705)
	world.witch.move_direction(Vector2.DOWN, 0.5)
	assert(world.witch.position.y < 735.0, "The pond blocks stepping off the bridge into water")
	var old_water_save: Dictionary = world.snapshot()
	old_water_save.x = 1320
	old_water_save.y = 820
	world.restore(old_water_save)
	assert(world._is_walkable_position(world.witch.position), "An old save in water restores onto valid ground")
	assert(world.recipe_order == old_water_save.recipe_order, "Safe position recovery preserves the shuffled recipe")
	assert(world.recipe_order.size() == world.INGREDIENTS.size(), "New run creates a full recipe order")
	var recipe_ids := {}
	for id in world.recipe_order:
		recipe_ids[id] = true
	assert(recipe_ids.size() == world.INGREDIENTS.size(), "Recipe order contains each ingredient exactly once")
	assert(world.companion_witches.size() == 3, "Three companion witches surround the cauldron")
	assert(world.companion_names == ["Violet", "Amber", "Hazel"], "Companion names match the physical cauldron registry")
	assert(world.interaction_markers.size() == world.ENVIRONMENT_INTERACTIONS.size(), "Only environment objects have question marks; companions do not")
	for i in world.ENVIRONMENT_INTERACTIONS.size():
		assert(world.interaction_markers[i].position + Vector2(12, 34) == world.ENVIRONMENT_INTERACTIONS[i].marker_anchor, "Hollow marker points precisely to its visible object")
	assert(world.bubbles.size() == 4, "Cauldron has multiple bubbling sprites")
	var bubble_start: Vector2 = world.bubbles[0].position
	await create_timer(0.2).timeout
	assert(world.bubbles[0].position != bubble_start, "Cauldron bubbles animate while playing")
	var companion_offsets := [Vector2(0, -70), Vector2(0, 65), Vector2(0, 65)]
	for i in world.companion_witches.size():
		world.witch.position = world.companion_witches[i].position + companion_offsets[i]
		assert(world.nearby_companion() == i, "Companion %s is interactable" % world.companion_names[i])
		var companion_name: String = world.companion_names[i]
		var before_dialogue: int = world.companion_dialogue_index[companion_name]
		world.interact()
		assert(world.companion_dialogue_index[companion_name] != before_dialogue, "Companion %s speaks" % companion_name)
	var environment_approaches := [Vector2(270, 223), Vector2(465, 238), Vector2(446, 674), Vector2(891, 803), Vector2(1243, 720), Vector2(1196, 223), Vector2(1370, 301)]
	for i in world.ENVIRONMENT_INTERACTIONS.size():
		world.witch.position = environment_approaches[i]
		assert(world._is_walkable_position(world.witch.position), "Hollow landmark %d has a walkable approach" % i)
		assert(world.nearby_environment() == i, "Hollow landmark %d is readable" % i)
		var before_epitaph: int = world.environment_dialogue_index[i]
		world.interact()
		assert(world.environment_dialogue_index[i] != before_epitaph, "Hollow landmark %d reveals flavor text" % i)
		assert(world.interaction_markers[i].position + Vector2(12, 34) == world.ENVIRONMENT_INTERACTIONS[i].marker_anchor, "Hollow marker remains fixed during play")
	world.witch.position = Vector2(800, 635)
	var start: Vector2 = world.witch.position
	Input.action_press("move_right")
	await create_timer(0.2).timeout
	Input.action_release("move_right")
	assert(world.witch.position.x > start.x + 15.0, "Movement must move the witch")
	main._toggle_pause()
	var stopped: Vector2 = world.witch.position
	Input.action_press("move_right")
	await create_timer(0.15).timeout
	Input.action_release("move_right")
	assert(world.witch.position.distance_to(stopped) < 1.0, "Pause stops movement")
	main._resume()
	var saved_recipe_order: Array[String] = world.recipe_order.duplicate()
	var ingredient_approaches := {"mushroom":Vector2(365, 818), "pumpkin":Vector2(1299, 244), "skull":Vector2(350, 218), "feather":Vector2(815, 198), "essence":Vector2(1321, 716), "moonflower":Vector2(1120, 553)}
	for i in world.recipe_order.size():
		var entry: Dictionary = world.recipe_entry(world.recipe_order[i])
		world.witch.position = ingredient_approaches[entry.id]
		assert(world._is_walkable_position(world.witch.position), "Ingredient %s has a walkable approach" % entry.id)
		assert(world.next_required() == entry.id, "Recipe order advances one ingredient at a time")
		assert(world.nearby_target() == entry.id, "Ingredient must be interactable")
		world.interact()
		assert(world.collected.size() == 1 and entry.id in world.collected, "Gather adds exactly one item to satchel")
		assert(world.nearby_target().is_empty(), "Full satchel prevents another pickup")
		world.interact()
		assert(world.collected.size() == 1, "A full satchel cannot gather twice")
		world.witch.position = world.CAULDRON + Vector2(0, 65)
		world.interact()
		assert(world.collected.is_empty() and world.deposited.size() == i + 1, "Deposit advances the recipe")
		if i == 1:
			var snapshot: Dictionary = world.snapshot()
			world.restore(snapshot)
			assert(world.collected.is_empty() and world.deposited.size() == 2, "Save restore keeps cauldron progression")
			assert(world.recipe_order == saved_recipe_order, "Save restore keeps the shuffled recipe order")
	assert(world.won and world.deposited.size() == 6 and world.spell.visible, "Final deposit completes spell")
	assert(main.state == "complete", "Result flow starts")
	await create_timer(1.8).timeout
	assert(main.overlay != null, "First-level completion overlay appears after the sparkle")
	main._start_new_run()
	await process_frame
	assert(not main.world.won and main.world.collected.is_empty() and main.world.deposited.is_empty(), "Replay resets spell")
	main._begin_maze({})
	await process_frame
	var maze = main.world
	assert(main.current_level == 2, "Spell completion can enter the corn maze")
	assert(maze.witch.position == maze.START_POSITION, "Maze starts at the entrance plaza")
	assert(maze._is_walkable_position(maze.START_POSITION), "Maze spawn footprint is walkable")
	maze.witch.move_direction(Vector2.RIGHT, 0.3)
	assert(maze.witch.position.x > maze.START_POSITION.x + 40.0, "Witch can walk right out of the spawn")
	maze.witch.position = maze.START_POSITION
	maze.witch.move_direction(Vector2.DOWN, 0.3)
	assert(maze.witch.position.y > maze.START_POSITION.y + 40.0, "Witch can walk down out of the spawn")
	maze.witch.position = Vector2(508, 230)
	maze.witch.move_direction(Vector2.RIGHT, 1.0)
	assert(maze.witch.position.x < 545.0, "Corn patch in the walkable mask blocks movement")
	maze.witch.position = Vector2(370, 101)
	maze.witch.move_direction(Vector2.DOWN, 0.2)
	assert(maze.witch.position.y > 101.0, "Witch can always move out of an invalid spot inside corn")
	assert(maze.treat_sprites.size() == 3, "Corn maze has three illustrated fall treats")
	maze.witch.position = Vector2(1078, 705)
	maze.witch.move_direction(Vector2.UP, 0.5)
	assert(maze.witch.position.y > maze.CAULDRON_POSITION.y + maze.CAULDRON_RADIUS, "The maze cauldron is solid")
	assert(maze.nearby_cauldron(), "Witch can stand beside the maze cauldron")
	maze.interact()
	assert(not maze.won, "The cauldron refuses to finish before all treats are found")
	assert(maze.interaction_markers.size() == 3, "All three maze landmarks have question-mark indicators")
	var approach_points := [Vector2(700, 248), Vector2(441, 519), Vector2(1016, 500)]
	for i in maze.ENVIRONMENT_INTERACTIONS.size():
		var landmark: Dictionary = maze.ENVIRONMENT_INTERACTIONS[i]
		assert(maze.interaction_markers[i].text == "?" and maze.interaction_markers[i].visible, "Maze landmark marker is visible")
		assert(maze.interaction_markers[i].position + Vector2(12, 34) == landmark.marker_anchor, "Maze pointer remains fixed on its visible object")
		maze.witch.position = approach_points[i]
		assert(maze._is_walkable_position(maze.witch.position), "Landmark %s has a walkable approach" % landmark.name)
		assert(maze.nearby_environment() == i, "Landmark %s can be inspected from the path" % landmark.name)
		main._process_maze(0.0)
		assert(main.prompt_label.text.ends_with(landmark.prompt), "HUD offers the matching landmark action")
		for line_index in landmark.lines.size():
			maze.interact()
			assert(main.notice_label.text == "%s: \"%s\"" % [landmark.name, landmark.lines[line_index]], "Landmark reveals the next flavor line")
		assert(maze.environment_dialogue_index[i] == 0, "Landmark dialogue cycles back to the first line")
		assert(maze.collected.is_empty() and not maze.won, "Landmark inspection leaves treat and spell progression unchanged")
	for i in maze.TREAT_POSITIONS.size():
		assert(maze._is_walkable_position(maze.TREAT_POSITIONS[i]), "Fall treat %d sits on a walkable path" % i)
		maze.witch.position = maze.TREAT_POSITIONS[i]
		assert(not maze.nearby_target().is_empty(), "Fall treat %d is reachable" % i)
		assert(maze.nearby_environment() == -1, "Treat pickups take priority over nearby landmarks")
		maze.interact()
	assert(maze.collected.size() == 3, "Corn maze collects all three fall treats")
	maze.witch.position = approach_points[0]
	maze.interact()
	assert(maze.collected.size() == 3 and not maze.won, "Landmarks remain optional while carrying all three treats")
	maze.witch.position = Vector2(1078, 620)
	assert(maze._is_walkable_position(maze.witch.position), "The path north of the cauldron is walkable")
	assert(maze.nearby_cauldron(), "Witch can reach the cauldron from the north side")
	maze.interact()
	assert(main.state == "complete" and maze.won, "Corn maze completion flow starts")
	await create_timer(1.3).timeout
	assert(main.overlay != null, "Maze completion presents the next chapter")
	var found_house_button := false
	for child in main.overlay.get_children():
		if child is Button and child.text.begins_with("Enter the haunted house"):
			found_house_button = true
			child.pressed.emit()
			break
	assert(found_house_button, "Maze completion offers entry to the haunted house")
	await process_frame
	assert(main.current_level == 3, "Next-chapter button enters the haunted house")
	var house = main.world
	assert(house._is_walkable_position(house.START_POSITION), "Manor spawn has an open feet footprint")
	assert(house.witch.movement_validator.is_valid(), "The house uses the shared forgiving mask movement")
	var tour := [Vector2(768, 855), Vector2(848, 855), Vector2(848, 735), Vector2(768, 735), Vector2(575, 735), Vector2(400, 735), Vector2(768, 735), Vector2(978, 735), Vector2(1170, 780), Vector2(978, 735), Vector2(768, 735), Vector2(768, 475), Vector2(578, 475), Vector2(455, 520), Vector2(578, 475), Vector2(768, 475), Vector2(985, 475), Vector2(1005, 555), Vector2(1005, 475), Vector2(768, 475), Vector2(768, 235), Vector2(578, 235), Vector2(505, 252), Vector2(578, 235), Vector2(768, 235), Vector2(978, 235), Vector2(1150, 260)]
	for destination in tour:
		var motion: Vector2 = destination - house.witch.position
		house.witch.move_direction(motion, motion.length() / house.witch.speed)
		assert(house.witch.position.distance_to(destination) < 1.0, "All manor rooms can be reached through their open doorways")
	house.witch.position = Vector2(560, 280)
	house.witch.move_direction(Vector2.DOWN, 0.5)
	assert(house.witch.position.y < 317 and house._is_walkable_position(house.witch.position), "House walls prevent walking between rooms except through doorways")
	house.witch.position = Vector2(1100, 263)
	house.witch.move_direction(Vector2.RIGHT, 0.4)
	assert(house.witch.position.x > 1170, "Decorative gallery rugs are fully walkable")
	assert(not house._is_walkable_position(Vector2(1100, 460)), "The piano stays solid despite its walkable rug")
	assert(not house._is_walkable_position(house.CAULDRON_POSITION), "The foyer cauldron is solid")
	house.witch.position = Vector2(768, 860)
	house.interact()
	assert(not house.won, "The house cauldron waits for all four keepsakes")
	var house_approaches := [Vector2(1040, 197), Vector2(1030, 500), Vector2(1340, 495), Vector2(230, 730)]
	assert(house.interaction_markers.size() == house.ENVIRONMENT_INTERACTIONS.size(), "Hauntings have precisely anchored indicators")
	for i in house.ENVIRONMENT_INTERACTIONS.size():
		house.witch.position = house_approaches[i]
		assert(house._is_walkable_position(house.witch.position) and house.nearby_environment() == i, "Each haunting has a reachable inspection point")
		var before_line: int = house.environment_dialogue_index[i]
		house.interact()
		assert(house.environment_dialogue_index[i] != before_line and house.collected.is_empty(), "Hauntings reveal flavor text without awarding keepsakes")
	for i in 2:
		house.witch.position = house.ITEM_POSITIONS[i]
		assert(house._is_walkable_position(house.witch.position), "Each keepsake sits on connected floor")
		house.interact()
		house.interact()
		assert(house.collected.size() == i + 1, "Keepsakes can only be gathered once")
	main._toggle_pause()
	var paused_position: Vector2 = house.witch.position
	Input.action_press("move_right")
	await create_timer(0.12).timeout
	Input.action_release("move_right")
	assert(house.witch.position == paused_position, "Pause stops movement in the manor")
	main._resume()
	var house_save: Dictionary = house.snapshot()
	house_save.x = 616
	house_save.y = 332
	house.restore(house_save)
	assert(house.witch.position == house.START_POSITION and house.collected.size() == 2, "An invalid old house position restores safely without losing keepsakes")
	main._save_progress()
	main._show_title()
	await process_frame
	main._continue_run()
	await process_frame
	house = main.world
	assert(main.current_level == 3 and house.collected.size() == 2, "Title continuation restores the correct chapter and keepsakes")
	for i in range(2, 4):
		house.witch.position = house.ITEM_POSITIONS[i]
		house.interact()
	assert(house.collected.size() == 4 and not house.won, "Gathering keepsakes does not finish the house before brewing")
	main._save_progress()
	main._show_title()
	await process_frame
	var found_continue := false
	for child in main.get_children():
		if child is Button and child.text == "Continue in the manor":
			found_continue = true
	assert(found_continue, "A full satchel is still resumable before brewing")
	main._continue_run()
	await process_frame
	house = main.world
	assert(house.collected.size() == 4 and not house.won, "All four keepsakes survive saved-run continuation")
	house.witch.position = Vector2(768, 860)
	house.interact()
	assert(main.state == "complete" and house.won and not house.active, "The foyer cauldron completes the unhaunting spell once")
	await create_timer(1.3).timeout
	assert(main.overlay != null, "The manor presents the final adventure ending")
	main._show_title()
	await process_frame
	main._practice_maze()
	await process_frame
	assert(main.current_level == 2 and main.world.collected.is_empty(), "Title screen starts a fresh maze practice run")
	main._show_title()
	await process_frame
	main._practice_house()
	await process_frame
	assert(main.current_level == 3 and main.world.collected.is_empty() and not main.world.won, "Title screen starts a fresh haunted-house practice run")
	saves.set_adventure(original)
	print("[hex-hollow] PASS: woodland, corn maze, haunted house, doorway traversal, rugs and walls, keepsakes, hauntings, pause, full-satchel save restore, spell completion, replay")
	quit(0)
