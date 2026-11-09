extends SceneTree

func _initialize() -> void:
	call_deferred("check_gait")

func check_gait() -> void:
	var main = load("res://scripts/main.gd").new()
	main.hero = AnimatedSprite2D.new()
	main.hero.sprite_frames = SpriteFrames.new()
	for key in ["walk_S", "walk_E", "run_E", "idle_E"]:
		main.hero.sprite_frames.add_animation(key)
		for i in 16:
			main.hero.sprite_frames.add_frame(key, null)
	var walk_cycle := 0.96 / 0.62 * 128.0 / 2.75
	main._update_gait(walk_cycle * 0.25, false)
	assert(is_equal_approx(main.gait_phase, 0.25))
	main.facing = "E"
	main._update_gait(walk_cycle * 0.25, false)
	assert(main.hero.frame == 8)
	main._update_gait(0.0, false)
	assert(is_equal_approx(main.gait_phase, 0.5))
	assert(main.hero.animation == "idle_E")
	main._update_gait(1.12 / 0.52 * 128.0 / 2.75 * 0.25, true)
	assert(is_equal_approx(main.gait_phase, 0.75))
	main.hero.free()
	main.free()
	print("PASS gait: distance, direction, wall, sprint")
	quit()
