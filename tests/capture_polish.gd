extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/previews")
	var sheet := Image.create(1024, 1280, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#242c40"))
	var rows := [["idle", [0, 4, 8, 12]], ["walk", [0, 4, 8, 12]], ["run", [0, 4, 8, 12]], ["slash_heavy", [0, 2, 5, 7]], ["death", [0, 4, 8, 11]]]
	for row in rows.size():
		for col in 4:
			var picture: Image = load("res://art/hechicero/polished/%s_S_%02d.png" % [rows[row][0], rows[row][1][col]]).get_image()
			picture.resize(256, 256, Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(picture, Rect2i(0, 0, 256, 256), Vector2i(col*256, row*256))
	sheet.save_png("res://docs/previews/hero_poses.png")
	var dragon_sheet := Image.create(1280, 320, false, Image.FORMAT_RGBA8)
	dragon_sheet.fill(Color("#242c40"))
	for col in 4:
		var picture: Image = load("res://art/dragon/dragon_S_death_%02d.png" % [col*3 if col < 3 else 11]).get_image()
		picture.resize(320, 320, Image.INTERPOLATE_NEAREST)
		dragon_sheet.blend_rect(picture, Rect2i(0, 0, 320, 320), Vector2i(col*320, 0))
	dragon_sheet.save_png("res://docs/previews/dragon_death.png")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/game_polished.png")
	main._enter_dungeon()
	for enemy in main.enemies:
		enemy.set_physics_process(false)
	main._place()
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/dungeon_polished.png")
	main._begin(main.items["grimorio_ignis"]["light"], "light")
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/magic_light.png")
	print("PASS captures saved")
	quit()
