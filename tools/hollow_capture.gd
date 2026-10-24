extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 800)
	var original: Dictionary = root.get_node("SaveStore").get_adventure()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if OS.get_environment("HOLLOW_CAPTURE_MODE") == "game":
		main._start_new_run()
		await process_frame
		if OS.get_environment("HOLLOW_CAPTURE_POINT") == "bridge":
			main.world.witch.position = Vector2(1321, 705)
			main.world.camera.position = main.world.witch.position
			main.world.camera.reset_smoothing()
	elif OS.get_environment("HOLLOW_CAPTURE_MODE") == "maze":
		main._practice_maze()
		await process_frame
		var index := clampi(OS.get_environment("HOLLOW_CAPTURE_LANDMARK").to_int(), 0, 2)
		var approach_points := [Vector2(700, 248), Vector2(441, 519), Vector2(1016, 500)]
		main.world.witch.position = approach_points[index]
		main.world.camera.position = main.world.witch.position
		main.world.camera.reset_smoothing()
		main.world.interact()
	for frame in 12:
		await process_frame
	await create_timer(0.35).timeout
	var image := root.get_texture().get_image()
	var error := image.save_png(OS.get_environment("HOLLOW_CAPTURE_PATH"))
	root.get_node("SaveStore").set_adventure(original)
	print("[hollow-capture] ", error_string(error))
	quit(0 if error == OK else 1)
