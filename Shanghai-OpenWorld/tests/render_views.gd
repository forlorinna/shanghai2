extends SceneTree

const Scene = preload("res://game/main.tscn")
var game
var output := "res://builds"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	call_deferred("_run")

func _wait(count: int) -> void:
	for index in count:
		await process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var view := root.get_texture().get_image()
	var result := view.save_png(output.path_join(name + ".png"))
	print("Frame ", name, " ", result)

func _run() -> void:
	seed(314159)
	game = Scene.instantiate()
	root.add_child(game)
	game.settings.auto = false
	await _wait(35)
	await _capture("title")
	game.ui.open("map")
	await _wait(5)
	await _capture("map")
	game.begin("new")
	await _wait(42)
	await _capture("pudong")
	game.teleport(game.place("bund"))
	game.yaw = -1.75
	game.pitch = -0.04
	game.climate.hour = 21.0
	await _wait(76)
	await _capture("bund-night")
	game.ui.open("phone")
	await _wait(5)
	await _capture("phone")
	game.queue_free()
	await _wait(3)
	quit()
