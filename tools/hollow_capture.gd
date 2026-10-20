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
	for frame in 12:
		await process_frame
	await create_timer(0.35).timeout
	var image := root.get_texture().get_image()
	var error := image.save_png(OS.get_environment("HOLLOW_CAPTURE_PATH"))
	root.get_node("SaveStore").set_adventure(original)
	print("[hollow-capture] ", error_string(error))
	quit(0 if error == OK else 1)
