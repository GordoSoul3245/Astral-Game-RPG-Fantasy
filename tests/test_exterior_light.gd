extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	await process_frame
	var clock = game.clock
	clock.rain = false
	var gate := get_first_node_in_group("gate") as PointLight2D
	assert(is_instance_valid(gate))
	game.pos = gate.global_position / game.SCALE + Vector2(65,45)
	game._place()
	game.cam.position = game.pos * game.SCALE
	game.cam.reset_smoothing()
	var material = game.contact_shadow.material
	for hour in [7,12,18,23]:
		clock.hour = hour
		clock._process(0)
		var sunlight: Vector2 = material.get_shader_parameter("sun")
		match hour:
			7: assert(sunlight.x < -0.5)
			12: assert(absf(sunlight.x) < 0.01)
			18: assert(sunlight.x > 0.5)
			23: assert(not clock.sunlight.enabled and sunlight == Vector2.ZERO)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_temp_dir()+"/astral_sol_%d.png" % hour)
	game._enter_zone("bosque")
	var fire := get_first_node_in_group("hearth") as PointLight2D
	assert(is_instance_valid(fire))
	clock._process(0)
	assert(material.get_shader_parameter("hearth").z > 0)
	for side in [-1,1]:
		game.pos = (fire.global_position + Vector2(side*85,22))/game.SCALE
		game._place()
		game.cam.position = game.pos * game.SCALE
		game.cam.reset_smoothing()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_temp_dir()+"/astral_fogon_%d.png" % side)
	clock.outdoors = false
	clock.hour = 12
	clock._process(0)
	assert(not clock.sunlight.enabled and material.get_shader_parameter("gate") == Vector3.ZERO)
	print("PASS solar direction, noon, night, portal and indoor isolation")
	quit()
