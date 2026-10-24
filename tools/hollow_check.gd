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
	assert(world.interaction_markers.size() == world.companion_witches.size() + world.ENVIRONMENT_INTERACTIONS.size(), "All interactable secrets have map markers")
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
	main._show_title()
	await process_frame
	main._practice_maze()
	await process_frame
	assert(main.current_level == 2 and main.world.collected.is_empty(), "Title screen starts a fresh maze practice run")
	saves.set_adventure(original)
	print("[hex-hollow] PASS: movement, pause, ordered pickups, one-at-a-time deposits, duplicate prevention, save restore, completed spell, replay, corn maze")
	quit(0)
