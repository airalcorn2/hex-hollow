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
	for i in world.INGREDIENTS.size():
		var entry: Dictionary = world.INGREDIENTS[i]
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
	assert(world.won and world.deposited.size() == 6 and world.spell.visible, "Final deposit completes spell")
	assert(main.state == "complete", "Result flow starts")
	main._start_new_run()
	await process_frame
	assert(not main.world.won and main.world.collected.is_empty() and main.world.deposited.is_empty(), "Replay resets spell")
	saves.set_adventure(original)
	print("[hex-hollow] PASS: movement, pause, ordered pickups, one-at-a-time deposits, duplicate prevention, save restore, completed spell, replay")
	quit(0)
