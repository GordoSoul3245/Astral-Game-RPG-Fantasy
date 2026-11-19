extends SceneTree

const SAVE := "user://test_resume_session.json"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for area in ["bosque", "house", "mine", "dungeon"]:
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		main.save_path = SAVE
		await process_frame
		var outside: Vector2 = main.pos
		match area:
			"bosque": main._enter_zone("bosque")
			"house": main._enter_interior(main.interiors_data.keys()[0])
			"mine": main._enter_mine()
			"dungeon":
				main._enter_dungeon()
				main.floors.start(3)
				for enemy in main.enemies.duplicate():
					if enemy != main.dragon:
						main.enemies.erase(enemy)
						enemy.queue_free()
				main.floors._clear()
				main.floors.open_chest()
		main.pos += Vector2(5, 9)
		var location: Vector2 = main.pos
		main.hero_hp = 17
		main.prog.coins = 987
		main._select(5)
		main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		main.free()
		main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		main.save_path = SAVE
		await process_frame
		assert(main.load_game(true))
		main._restore_player()
		assert(main.pos.is_equal_approx(location) and main.hero_hp == 17 and main.selected == 5 and main.prog.coins == 987)
		match area:
			"bosque": assert(main.region() == "bosque")
			"house": assert(main.in_interior and main.overworld.pos == outside)
			"mine": assert(main.in_mine and main.zone_id == "" and main.overworld.pos == outside)
			"dungeon": assert(main.floors.floor_no == 3 and main.floors.cleared and main.floors.chest_door == null)
		for tab in ["fish", "stats", "magic"]:
			main.menu.open_tab(tab)
			assert(main.menu.panel.is_visible_in_tree() and not main.menu.book.visible and not main.menu.bar_row.is_visible_in_tree())
			main.menu._close_panel()
		var pause_menu = preload("res://scripts/start_menu.gd").new()
		pause_menu.main = main
		main.add_child(pause_menu)
		pause_menu._show(false)
		pause_menu._options()
		assert(paused and main.menu.tab == "opt" and not pause_menu.visible)
		main.menu._close_panel()
		assert(paused and pause_menu.visible)
		pause_menu._resume()
		main.free()
	DirAccess.remove_absolute(SAVE)
	print("PASS resume and independent panels")
	quit()
