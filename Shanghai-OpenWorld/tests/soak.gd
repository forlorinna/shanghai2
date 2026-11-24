extends SceneTree

const Scene = preload("res://game/main.tscn")
var game

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(6502)
	game = Scene.instantiate()
	root.add_child(game)
	await physics_frame
	game.begin("free")
	game.settings.auto = false
	game.settings.quality = 1
	game.apply_settings()
	var max_chunks := 0
	var memory_start := 0.0
	var max_memory := 0.0
	var stops := ["green", "bund", "century", "nanjing", "swfc", "bridge", "mall", "promenade"]
	for cycle in 24:
		var key: String = stops[cycle % stops.size()]
		var target: Vector3 = game.place(key)
		game.teleport(target)
		game.climate.weather = cycle % 7
		for tick in 1500:
			await physics_frame
			if tick % 60 == 0:
				max_chunks = maxi(max_chunks, game.world.loaded.size())
				var memory := Performance.get_monitor(Performance.MEMORY_STATIC)
				max_memory = maxf(max_memory, memory)
				if cycle == 1 and tick == 0:
					memory_start = memory
		if not game.player.is_on_floor() or not game.world.in_bounds(game.focus()):
			printerr("FAIL  Soak player fell at ", key)
			quit(1)
			return
	print("PASS  36,000 simulation ticks, 24 district changes, all seven weather states, %s maximum resident chunks" % max_chunks)
	print("INFO  Engine static memory after warm-up %.2f MiB, maximum %.2f MiB" % [memory_start / 1048576, max_memory / 1048576])
	game.queue_free()
	await process_frame
	quit()
