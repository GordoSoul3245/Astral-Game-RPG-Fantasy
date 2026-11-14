extends SceneTree
# Comprobación de la calibración: por cada fotograma del tajo dibuja sobre el sprite del héroe, a escala de juego,
# la base (rojo) y la punta (verde) del filo según data/blade_points.json. Deben caer sobre la hoja que se ve.
# Ejecutar sin --headless: guarda en production/qa/evidence/estelas/puntos_<anim>_<dir>.png (4 columnas por fila).

const DIR := "res://production/qa/evidence/estelas/"
const CROP := 400
const SLOW := 0.25
const NAMES := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
var main: Node
var table: Dictionary

class Marks extends Node2D:
	var main: Node
	var table: Dictionary
	var anim := ""
	var dir := ""
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var f: int = main.hero.frame
		var p: Array = table[anim][dir][f * int(table["_sub"])]
		var o: Vector2 = main.hero.position + main.hero.offset * main.SCALE
		draw_circle(o + Vector2(p[0], p[1]) * main.SCALE, 7.0, Color(1, 0.1, 0.1))
		draw_circle(o + Vector2(p[2], p[3]) * main.SCALE, 7.0, Color(0.1, 1, 0.1))

func _initialize() -> void:
	call_deferred("capture")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var c: Vector2 = main.hero.get_global_transform_with_canvas().origin + Vector2(192, 192)
	var out := Image.create(CROP, CROP, false, Image.FORMAT_RGBA8)
	out.blit_rect(root.get_texture().get_image(), Rect2i(Vector2i(c) - Vector2i(CROP / 2, CROP / 2), Vector2i(CROP, CROP)), Vector2i.ZERO)
	return out

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	table = JSON.parse_string(FileAccess.get_file_as_string("res://data/blade_points.json"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://capture_trail_points_save.json"
	main.testing = true
	await _wait(0.8)
	main.clock.hour = 12.0
	main.pos = main.tile_to_ground(Vector2(10, 30))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	main._select(main.hotbar.find("katana_ceniza"))
	await _wait(0.8)
	var marks := Marks.new()
	marks.main = main
	marks.table = table
	marks.z_index = 4000
	main.add_child(marks)
	for mode in ["light", "heavy"]:
		for d in [0, 1, 3]:
			marks.anim = "slash_" + mode
			marks.dir = NAMES[d]
			main.forced_aim = Vector2.from_angle(d * PI / 4.0)
			for k in 30:
				main.cooldown = 0.0
				if main._attack(mode):
					break
				await _wait(0.1)
			Engine.time_scale = SLOW
			var shots: Array = []
			var last := -1
			var start := Time.get_ticks_msec()
			while main.attacking and Time.get_ticks_msec() - start < 6000:
				await RenderingServer.frame_post_draw
				if main.hero.frame != last and main.attacking:
					last = main.hero.frame
					shots.append(await _grab())
			Engine.time_scale = 1.0
			var img := Image.create(4 * CROP, 2 * CROP, false, Image.FORMAT_RGBA8)
			for i in mini(8, shots.size()):
				img.blit_rect(shots[i], Rect2i(0, 0, CROP, CROP), Vector2i((i % 4) * CROP, (i / 4) * CROP))
			img.save_png(DIR + "puntos_%s_%s.png" % [marks.anim, marks.dir])
			await _wait(1.0)
	quit()
