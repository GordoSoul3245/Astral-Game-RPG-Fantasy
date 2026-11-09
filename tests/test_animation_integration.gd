extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	for dir in main.DIRS:
		for kind in ["idle", "walk", "run", "hurt", "death"]:
			var frames: SpriteFrames = main.hero.sprite_frames
			var key: String = kind + "_" + dir
			assert(frames.get_frame_count(key) == (6 if kind == "hurt" else (12 if kind == "death" else 16)))
			for i in frames.get_frame_count(key):
				assert(frames.get_frame_texture(key, i) != null)
				if kind == "death":
					var picture: Image = frames.get_frame_texture(key, i).get_image()
					assert(picture.get_width() == 192)
					var bounds := picture.get_used_rect()
					assert(bounds.position.y > 0 and bounds.end.y < 192, "%s frame %d bounds %s" % [key, i, bounds])
		for kind in ["slash_light", "slash_heavy", "fslash_light", "fslash_heavy", "cast"]:
			var strike := 5 if kind.ends_with("heavy") else 3
			var key: String = kind + "_" + dir
			var before := 0.0
			var total := 0.0
			for i in main.hero.sprite_frames.get_frame_count(key):
				var duration: float = main.hero.sprite_frames.get_frame_duration(key, i)
				total += duration
				if i < strike:
					before += duration
			assert(is_equal_approx(before, float(strike)))
			assert(is_equal_approx(total, float(main.ANIMS[kind])))
		assert(main.dragon.sprite_frames.get_frame_count("death_" + dir) == 12)
	main.damage_hero(1)
	assert(main.hero.animation == "hurt_S")
	main.reaction_time = 0.0
	main.damage_hero(99999)
	assert(main.dying and main.hero.animation == "death_S")
	main._physics_process(1.01)
	assert(not main.dying and main.hero_hp == main.hero_max_hp)
	main.dragon.take_damage(9999)
	assert(not main.dragon.alive and main.dragon.animation.begins_with("death_"))
	var xp_after: int = main.prog.xp
	main.dragon.take_damage(9999)
	assert(main.prog.xp == xp_after)
	main.dragon.reset(main.dragon_start)
	await create_timer(2.4).timeout
	assert(main.dragon.alive and is_equal_approx(main.dragon.modulate.a, 1.0))
	assert(main.dragon.offset == Vector2.ZERO)
	print("PASS animation integration: assets, impact timing, hurt, respawn, death/reset")
	quit()
