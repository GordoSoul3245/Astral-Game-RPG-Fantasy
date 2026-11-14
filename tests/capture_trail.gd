extends SceneTree
# Hojas de contacto de la estela del tajo a escala de juego: una fila por dirección y cuatro momentos
# (la cinta nace, barrido completo, se apaga a los 0,12 s y a los 0,3 s). Ligero y pesado, y la katana en llamas.
# Ejecutar sin --headless: guarda en production/qa/evidence/estelas/.

const DIR := "res://production/qa/evidence/estelas/"
const CROP := 400
const SLOW := 0.25
var main: Node

func _initialize() -> void:
	call_deferred("capture")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func _grab() -> Image:  # recorte de la pantalla centrado en el héroe
	await RenderingServer.frame_post_draw
	var c: Vector2 = main.hero.get_global_transform_with_canvas().origin + Vector2(192, 192)
	var out := Image.create(CROP, CROP, false, Image.FORMAT_RGBA8)
	out.blit_rect(root.get_texture().get_image(), Rect2i(Vector2i(c) - Vector2i(CROP / 2, CROP / 2), Vector2i(CROP, CROP)), Vector2i.ZERO)
	return out

func _run(mode: String, dir_i: int) -> Array:
	var shots: Array = []
	main.forced_aim = Vector2.from_angle(dir_i * PI / 4.0)
	for k in 30:
		main.cooldown = 0.0
		if main._attack(mode):
			break
		await _wait(0.1)
	Engine.time_scale = SLOW  # cámara lenta: así cada fotograma de la animación se ve en pantalla
	var first: int = main.current["trail_frame"]
	var last: int = main.current["trail_end"]
	var phase := 0
	var mark := 0.0
	var start := Time.get_ticks_msec()
	while phase < 4 and Time.get_ticks_msec() - start < 4000:
		await RenderingServer.frame_post_draw
		var f: int = main.hero.frame
		var now := Time.get_ticks_msec() / 1000.0
		if phase == 0 and main.attacking and f >= first + 1:
			shots.append(await _grab())
			phase = 1
		elif phase == 1 and f >= last:
			shots.append(await _grab())
			phase = 2
			mark = now
		elif phase == 2 and now - mark > 0.12 / SLOW:
			shots.append(await _grab())
			phase = 3
		elif phase == 3 and now - mark > 0.3 / SLOW:
			shots.append(await _grab())
			phase = 4
	Engine.time_scale = 1.0
	await _wait(1.0)
	return shots

func _sheet(name: String, rows: Array) -> void:
	var w := 4 * CROP
	var img := Image.create(w, rows.size() * CROP, false, Image.FORMAT_RGBA8)
	for r in rows.size():
		for c in mini(4, rows[r].size()):
			img.blit_rect(rows[r][c], Rect2i(0, 0, CROP, CROP), Vector2i(c * CROP, r * CROP))
	img.save_png(DIR + name + ".png")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://capture_trail_save.json"
	main.testing = true
	await _wait(0.8)
	main.clock.hour = 12.0
	main.clock.rain = false
	main.pos = main.tile_to_ground(Vector2(10, 30))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	main._select(main.hotbar.find("katana_ceniza"))
	await _wait(0.8)
	await _run("light", 0)  # calentamiento: la primera estela compila los shaders y se come unos fotogramas
	for mode in ["light", "heavy"]:
		var rows: Array = []
		for d in 8:
			rows.append(await _run(mode, d))
			if d == 3 or d == 7:
				_sheet("%s_%s" % [mode, "dirs_0_3" if d == 3 else "dirs_4_7"], rows)
				rows = []
	main.burn_t = 60.0  # katana en llamas: misma trayectoria, mismo aspecto de fuego
	for mode in ["light", "heavy"]:
		var rows: Array = []
		for d in [0, 1]:
			rows.append(await _run(mode, d))
		_sheet("fuego_%s" % mode, rows)
	quit()
