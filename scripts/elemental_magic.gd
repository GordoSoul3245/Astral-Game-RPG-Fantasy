extends RefCounted

static func cast(main: Node, spec: Dictionary) -> void:
	var origin: Vector2 = main.ground_to_tile(main.pos)
	var direction: Vector2 = (main.ground_to_tile(main.pos + main.aim_dir) - origin).normalized()
	var damage := roundi(float(spec.get("damage", 0)) * main.prog.magic_mult())
	match spec.type:
		"freeze":
			main.combat.play_at("ice", main.pos)
			for enemy in main.enemies + main.predators:
				if enemy.alive and enemy.is_visible_in_tree():
					_freeze(enemy, spec.duration)
		"ice_spike":
			var center: Vector2 = main.aim_cell
			var ground: Vector2 = main.tile_to_ground(center)
			if not main.floor_contains(ground):
				return
			_rise(main, preload("res://art/grimorio/ice_shard.png"), ground, -PI / 2, Vector2(2.5, 1.8))
			main.fx_ice(ground)
			var area := Rect2(center - Vector2.ONE, Vector2(2, 2))
			for enemy in main.targets():
				if enemy.alive and area.has_point(main.ground_to_tile(enemy.pos)):
					main.combat.hit(enemy, damage, "magic", ground)
		"stone_fist":
			var center := origin + direction * 1.25
			var ground: Vector2 = main.tile_to_ground(center)
			_rise(main, preload("res://art/grimorio/stone_fist.png"), ground, main.aim_dir.angle() + PI / 2, Vector2.ONE * 1.4)
			main.combat.ground_impact(ground, 0.7)
			for enemy in main.targets():
				if enemy.alive and center.distance_to(main.ground_to_tile(enemy.pos)) <= 1.35:
					main.combat.hit(enemy, damage, "magic", ground)
		"fissure":
			main.combat.ground_impact(main.pos, 1.2)
			main.shake(8)
			_crack(main, origin, direction)
			for enemy in main.targets():
				var offset: Vector2 = main.ground_to_tile(enemy.pos) - origin
				var along := offset.dot(direction)
				if enemy.alive and along >= 0 and along <= 8 and absf(offset.cross(direction)) <= 1:
					main.combat.hit(enemy, damage, "blast", main.pos)

static func _freeze(enemy: Node2D, duration: float) -> void:
	var timer := enemy.get_node_or_null("ElementalFreeze") as Timer
	if timer:
		timer.start(duration)
		return
	var previous_mode := enemy.process_mode
	var original_color := enemy.modulate
	timer = Timer.new()
	timer.name = "ElementalFreeze"
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.add_child(timer)
	enemy.modulate = original_color * Color("#97d8ff")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	timer.timeout.connect(func() -> void:
		enemy.process_mode = previous_mode
		enemy.modulate = original_color
		enemy.remove_child(timer)
		timer.queue_free())
	timer.start(duration)

static func _rise(main: Node, texture: Texture2D, ground: Vector2, angle: float, extent: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.rotation = angle
	sprite.position = ground * main.SCALE
	sprite.z_index = clampi(int(ground.y) + 4, -4096, 4096)
	main.add_child(sprite)
	sprite.scale = extent * main.SCALE * 0.25
	var tw := sprite.create_tween().set_parallel(true)
	tw.tween_property(sprite, "position:y", sprite.position.y - 24 * main.SCALE, 0.14)
	tw.tween_property(sprite, "scale", extent * main.SCALE, 0.14)
	tw.chain().tween_property(sprite, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(sprite.queue_free)

static func _crack(main: Node, origin: Vector2, direction: Vector2) -> void:
	var line := Line2D.new()
	line.default_color = Color("#674737")
	line.width = 9 * main.SCALE
	line.z_index = clampi(int(main.pos.y) + 1, -4096, 4096)
	main.add_child(line)
	var rim := Line2D.new()
	rim.width = 2 * main.SCALE
	rim.default_color = Color("#ce9a68")
	line.add_child(rim)
	for i in 17:
		var offset := direction.orthogonal() * (sin(i * 2.3) * 0.34 if i > 0 and i < 16 else 0.0)
		var point: Vector2 = main.tile_to_ground(origin + direction * i * 0.5 + offset) * main.SCALE
		line.add_point(point)
		rim.add_point(point - Vector2(0, main.SCALE))
	var tw := line.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(line, "modulate:a", 0.0, 0.45)
	tw.tween_callback(line.queue_free)
