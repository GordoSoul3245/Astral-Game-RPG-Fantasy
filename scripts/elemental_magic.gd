extends RefCounted

static func cast(main: Node, spec: Dictionary) -> void:
	var origin: Vector2 = main.ground_to_tile(main.pos)
	var direction: Vector2 = (main.ground_to_tile(main.pos + main.aim_dir) - origin).normalized()
	var damage := roundi(float(spec.get("damage", 0)) * main.prog.magic_mult())
	match spec.type:
		"freeze":
			main.combat.play_at("ice", main.pos)
			for enemy in main.enemies + ([] if main.in_dungeon else main.predators):
				if enemy.alive:
					_freeze(enemy, spec.duration)
		"ice_spike":
			var center: Vector2 = main.aim_cell
			var ground: Vector2 = main.tile_to_ground(center)
			if main.world.blocked(center, 0.05):
				return
			_rise(main, preload("res://art/grimorio/ice_shard.png"), ground, -PI / 2, Vector2(2.5, 1.8))
			main.fx_ice(ground)
			var width := float(spec.get("area_size",2))
			var area := Rect2(center - Vector2.ONE * width/2, Vector2.ONE * width)
			_patch(main, area.position, Vector2.RIGHT * width, Vector2.DOWN * width, Color("#99dfff88"))
			for enemy in main.targets():
				if enemy.alive and area.has_point(main.ground_to_tile(enemy.pos)):
					main.combat.hit(enemy, damage, "magic", ground, true, spec.get("weapon_id", ""))
		"stone_fist":
			var center := origin + direction * 1.25
			var ground: Vector2 = main.tile_to_ground(center)
			_rise(main, preload("res://art/grimorio/stone_fist.png"), ground, main.aim_dir.angle() + PI / 2, Vector2.ONE * 1.4)
			main.combat.ground_impact(ground, 0.7)
			for enemy in main.targets():
				if enemy.alive and center.distance_to(main.ground_to_tile(enemy.pos)) <= float(spec.get("fist_radius", 1.35)):
					main.combat.hit(enemy, damage, "magic", ground, true, spec.get("weapon_id", ""))
		"fissure":
			var length := fissure_length(main, origin, direction)
			var side := direction.orthogonal()
			if length == 0:
				main.ult = main.hero_data.ult_max
				return
			main.combat.ground_impact(main.pos, 1.2)
			main.shake(8)
			_patch(main, origin - side, direction * length, side * 2, Color("#ba895970"))
			_crack(main, origin, direction, length)
			for enemy in main.targets():
				var offset: Vector2 = main.ground_to_tile(enemy.pos) - origin
				var along := offset.dot(direction)
				if enemy.alive and along >= 0 and along <= length and absf(offset.cross(direction)) <= 1:
					main.combat.hit(enemy, damage, "blast", main.pos, true, spec.get("weapon_id", ""))

static func fissure_length(main: Node, origin: Vector2, direction: Vector2) -> float:
	var length := 0.0
	var side := direction.orthogonal()
	for i in range(1, 33):
		var tip := origin + direction * i * 0.25
		var blocked := false
		for j in range(-4, 5):
			if main.world.blocked(tip + side * j * 0.25, 0.05):
				blocked = true
				break
		if blocked:
			break
		length = i * 0.25
	return length

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

static func _crack(main: Node, origin: Vector2, direction: Vector2, length: float) -> void:
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
		var point: Vector2 = main.tile_to_ground(origin + direction * length * i / 16.0 + offset) * main.SCALE
		line.add_point(point)
		rim.add_point(point - Vector2(0, main.SCALE))
	var tw := line.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(line, "modulate:a", 0.0, 0.45)
	tw.tween_callback(line.queue_free)

static func _patch(main: Node, start: Vector2, u: Vector2, v: Vector2, color: Color) -> void:
	var patch := Polygon2D.new()
	var corners := PackedVector2Array()
	for tile: Vector2 in [start, start + u, start + u + v, start + v]:
		corners.append(main.tile_to_ground(tile) * main.SCALE)
	patch.polygon = corners
	patch.color = color
	patch.z_index = -2800
	main.add_child(patch)
	var fade := patch.create_tween()
	fade.tween_interval(0.24)
	fade.tween_property(patch, "modulate:a", 0.0, 0.35)
	fade.tween_callback(patch.queue_free)
