extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.set_physics_process(false)
	m.prog.coins = 400
	for id in ["grimorio_escarcha", "grimorio_tierra"]:
		assert(m.shop.price_of(id) == 200)
		assert(m.shop.buy(id).begins_with("¡") and m.menu._backpack().has(id))
		assert(m.hotbar_drop(id, 3) and m.hotbar[3] == id)
	assert(m.prog.coins == 0)
	m._enter_dungeon()
	var origin := Vector2(12, 12)
	m.pos = m.tile_to_ground(origin)
	m.aim_dir = (m.tile_to_ground(origin + Vector2.RIGHT) - m.pos).normalized()
	var near = m.spawn_enemy("slime", m.tile_to_ground(origin + Vector2(1, 0)))
	var far = m.spawn_enemy("slime", m.tile_to_ground(origin + Vector2(7.5, 0.9)))
	var outside = m.spawn_enemy("slime", m.tile_to_ground(origin + Vector2(7.5, 1.3)))
	for enemy in [near, far, outside]:
		enemy.hp = 1000
		enemy.set_physics_process(false)
	var ice: Dictionary = m.items.grimorio_escarcha
	var earth: Dictionary = m.items.grimorio_tierra
	m.current = earth.light
	m._strike()
	assert(near.hp < 1000 and far.hp == 1000)
	m.aim_cell = origin + Vector2.RIGHT
	var before: int = near.hp
	m.current = ice.heavy
	m._strike()
	assert(near.hp < before and far.hp == 1000)
	m.current = earth.ultimate
	m._strike()
	assert(far.hp < 1000 and outside.hp == 1000)
	for spec in [ice.light, earth.heavy]:
		m.spawn_projectile("hero", near.pos, Vector2.RIGHT, spec)
		var shot = m.get_child(-1)
		assert(shot.elemental_sprite.visible)
		before = near.hp
		shot._explode()
		if spec == earth.heavy:
			assert(near.hp < before)
	m.current = ice.ultimate
	m._strike()
	assert(near.process_mode == Node.PROCESS_MODE_DISABLED and outside.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(is_equal_approx(near.get_node("ElementalFreeze").wait_time, 5))
	await create_timer(5.1).timeout
	assert(near.process_mode != Node.PROCESS_MODE_DISABLED and not near.has_node("ElementalFreeze"))
	print("PASS elemental shop, hotbar, spell areas, projectiles and five-second freeze")
	quit()
