extends SceneTree
# Opciones y música: las opciones se guardan/validan y gobiernan temblor, destellos y pausa de impacto;
# la síntesis de música produce bucles audibles, del mismo largo y sin saltos en el empalme.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	await process_frame
	var st: RefCounted = main.settings
	st.path = "user://test_settings.json"

	# guardado, carga y validación
	st.shake = 0.5
	st.flash = 0.0
	st.hitstop = false
	st.music = 0.2
	st.save()
	st.shake = 1.0
	st.flash = 1.0
	st.hitstop = true
	assert(st.load_file() and st.shake == 0.5 and st.flash == 0.0 and not st.hitstop and is_equal_approx(st.music, 0.2), "las opciones se conservan")
	var f := FileAccess.open(st.path, FileAccess.WRITE)
	f.store_string('{"shake": 9, "flash": -3, "master": "x", "music": 7}')
	f.close()
	assert(st.load_file() and st.shake == 1.0 and st.flash == 0.0 and st.music == 1.0, "los valores absurdos se limitan")
	f = FileAccess.open(st.path, FileAccess.WRITE)
	f.store_string("{no es json")
	f.close()
	assert(not st.load_file(), "un archivo corrupto se ignora")

	# efectos: temblor, destellos y pausa de impacto obedecen a las opciones
	st.shake = 0.0
	main.shake_amp = 0.0
	main.kick_v = Vector2.ZERO
	main.shake(9.0)
	main.kick(Vector2(8, 0))
	assert(main.shake_amp == 0.0 and main.kick_v == Vector2.ZERO, "sin temblor, la cámara no se mueve")
	st.shake = 1.0
	main.shake(9.0)
	assert(main.shake_amp == 9.0)
	var lights := main.find_children("*", "PointLight2D", true, false).size()
	st.flash = 0.0
	main.combat.flash(main.pos, Color.ORANGE, 1.0, 2.0, 0.2)
	assert(main.find_children("*", "PointLight2D", true, false).size() == lights, "sin destellos no se crea luz de impacto")
	st.flash = 1.0
	var e: Node2D = main.spawn_enemy("skeleton_archer", main.pos + Vector2(-120, 0))
	e.set_physics_process(false)
	st.hitstop = false
	main.combat.stop_until = 0
	main.combat.hit(e, 1, "heavy", main.pos)
	assert(main.hero.speed_scale == 1.0, "sin pausa de impacto, el héroe no se congela")
	st.hitstop = true

	# audio: buses y música sintetizada (comprobamos forma, largo y empalme)
	st.apply_audio()
	assert(AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Music") >= 0, "buses de efectos y música")
	var M := preload("res://scripts/music.gd")
	var loops := {"out_base": M.render_outdoor_base(), "dun_base": M.render_dungeon_base(), "out_combat": M.render_combat(false), "dun_amb": M.render_dungeon_ambience()}
	var n := int(M.RATE * M.LOOP)
	for k: String in loops:
		var b: PackedFloat32Array = loops[k]
		var peak := 0.0
		var rms := 0.0
		for v in b:
			peak = maxf(peak, absf(v))
			rms += v * v
		rms = sqrt(rms / b.size())
		print("%-10s muestras=%d pico=%.2f rms=%.3f" % [k, b.size(), peak, rms])
		assert(b.size() == n, "%s: todas las capas duran lo mismo (%d)" % [k, b.size()])
		assert(rms > 0.003, "%s: se oye algo" % k)
		assert(peak < 1.0, "%s: no satura (%.2f)" % [k, peak])
		assert(absf(b[0]) < 0.35 and absf(b[b.size() - 1]) < 0.35, "%s: el empalme del bucle no da un salto" % k)
	var w: AudioStreamWAV = M.to_wav(loops["out_base"])
	assert(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_end == n)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(st.path))
	print("PASS settings: opciones validadas, efectos obedecen y la música se sintetiza en bucle")
	quit()
