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
	for i in world.ENVIRONMENT_INTERACTIONS.size():
		world.witch.position = world.ENVIRONMENT_INTERACTIONS[i].pos + Vector2(0, 58)
		assert(world.nearby_environment() == i, "Gravestone %d is readable" % i)
		var before_epitaph: int = world.environment_dialogue_index[i]
		world.interact()
		assert(world.environment_dialogue_index[i] != before_epitaph, "Gravestone %d reveals an epitaph" % i)
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
	for i in world.recipe_order.size():
		var entry: Dictionary = world.recipe_entry(world.recipe_order[i])
		world.witch.position = entry.pos + Vector2(0, 28)
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
	main._start_new_run()
	await process_frame
	assert(not main.world.won and main.world.collected.is_empty() and main.world.deposited.is_empty(), "Replay resets spell")
	main._begin_maze({})
	await process_frame
	var maze = main.world
	assert(main.current_level == 2, "Spell completion can enter the corn maze")
	assert(maze.charm_sprites.size() == 3 and maze.charm_markers.size() == 3, "Corn maze has three marked moon charms")
	for i in maze.CHARM_CELLS.size():
		maze.witch.position = maze.cell_position(maze.CHARM_CELLS[i])
		assert(not maze.nearby_target().is_empty(), "Moon charm %d is reachable" % i)
		maze.interact()
	assert(maze.collected.size() == 3, "Corn maze collects all three moon charms")
	maze.witch.position = maze.cell_position(maze.EXIT_CELL)
	assert(maze.nearby_exit(), "Corn maze exit is reachable")
	maze.interact()
	assert(main.state == "complete" and maze.won, "Corn maze completion flow starts")
	saves.set_adventure(original)
	print("[hex-hollow] PASS: movement, pause, ordered pickups, one-at-a-time deposits, duplicate prevention, save restore, completed spell, replay, corn maze")
	quit(0)
