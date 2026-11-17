extends SceneTree
# Medición de rendimiento: carga el juego, quita el vsync y el límite de FPS, y mide 8 s en el valle
# (héroe quieto 4 s y desplazándose 4 s). Ejecutar sin --headless. Imprime FPS medio, ms por fotograma y tiempo de proceso.

var main: Node

func _initialize() -> void:
	call_deferred("run")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://bench_save.json"
	main.testing = true
	await _wait(2.0)
	main.clock.hour = 12.0
	var start: Vector2 = main.pos
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var gpu := 0.0
	var rcpu := 0.0
	var frames := 0
	var proc := 0.0
	var t0 := Time.get_ticks_usec()
	var t_end := t0 + 8_000_000
	while Time.get_ticks_usec() < t_end:
		var el := (Time.get_ticks_usec() - t0) / 1_000_000.0
		if el > 4.0:  # se desplaza: la cámara recorre el valle
			main.pos = start + Vector2((el - 4.0) * 60.0, (el - 4.0) * 20.0)
			main._place()
		await process_frame
		frames += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	var secs := (Time.get_ticks_usec() - t0) / 1_000_000.0
	print("BENCH fps=%.1f ms=%.2f gpu_ms=%.2f render_cpu_ms=%.2f draw_calls=%d nodes=%d" % [frames / secs, secs * 1000.0 / frames, gpu / frames, rcpu / frames,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	quit()
