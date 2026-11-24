extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	assert(not m.valid_save({}) and m.valid_save({"level": 1, "coins": 0}))
	for invalid in [{"xp": []}, {"materials": {"mena_hierro": []}}, {"player": {"effects": {"burn_t": []}}}]:
		var data := {"level": 1, "coins": 0}
		data.merge(invalid)
		assert(not m.valid_save(data))
	var here: Vector2 = m.ground_to_tile(m.pos)
	var far_door = m._add_door(here + Vector2.RIGHT, "lejos", func(): pass)
	var near_door = m._add_door(here, "cerca", func(): pass)
	assert(m._near_door() == near_door)
	m.doors.erase(far_door)
	m.doors.erase(near_door)
	var opened := [false]
	var door = m._add_door(Vector2.ONE, "prueba", func(): opened[0] = true)
	door.use()
	paused = true
	await create_timer(0.55).timeout
	assert(not opened[0] and door.open_t == 0)
	paused = false
	await create_timer(0.5).timeout
	assert(opened[0] and door.open_t == 1)
	var menu = preload("res://scripts/start_menu.gd").new()
	menu.main = m
	m.add_child(menu)
	m.save_path = "user://missing_astral_test_dir/save.json"
	assert(not m.save_game())
	menu._show(false)
	menu._quit()
	menu._return_to_title()
	assert(paused and menu.visible and menu.title.text.contains("Error"))
	menu._resume()
	var a = m.spawn_enemy("slime", m.pos)
	var b = m.spawn_enemy("slime", m.pos)
	m.enemies.erase(a)
	a.queue_free()
	var c = m.spawn_enemy("slime", m.pos)
	assert(b.get_meta("spawn_slot") != c.get_meta("spawn_slot"))
	m._select(1)
	m.gathering = true
	m.ult = m.hero_data.ult_max
	m._ultimate()
	assert(not m.aiming and m.ult == m.hero_data.ult_max)
	print("PASS save failures, validation, spawn identity and gathering")
	quit()
