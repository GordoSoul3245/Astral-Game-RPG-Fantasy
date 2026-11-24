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
		var frozen_slot := -1
		var outside: Vector2 = main.pos
		match area:
			"bosque": main._enter_zone("bosque")
			"house": main._enter_interior(main.interiors_data.keys()[0])
			"mine":
				main._enter_mine()
				var enemy = main.enemies.back()
				frozen_slot = enemy.get_meta("spawn_slot")
				preload("res://scripts/elemental_magic.gd")._freeze(enemy, 2.5)
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
		main.regen_left = 12
		main.regen_rate = 1.5
		main.regen_acc = 0.25
		main.night_vision_t = 30
		main.burn_t = 7
		main.burn_mult = 2
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
		assert(main.regen_left == 12 and main.regen_acc == 0.25 and main.regen_rate == 1.5)
		assert(main.night_vision_t == 30 and main.burn_t == 7 and main.burn_mult == 2)
		assert(main.pos.is_equal_approx(location) and main.hero_hp == 17 and main.selected == 5 and main.prog.coins == 987)
		match area:
			"bosque": assert(main.region() == "bosque")
			"house": assert(main.in_interior and main.overworld.pos == outside)
			"mine":
				assert(main.in_mine and main.zone_id == "" and main.overworld.pos == outside)
				var frozen = main.enemies.filter(func(e): return e.get_meta("spawn_slot", -1) == frozen_slot)
				assert(frozen.size() == 1 and absf(frozen[0].get_node("ElementalFreeze").time_left - 2.5) < 0.1)
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
		main.hero_hp = 0
		main.dying = true
		assert(main.save_game())
		main.free()
		main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		main.save_path = SAVE
		assert(main.load_game(true))
		main._restore_player()
		assert(main.pos == main.start_pos and main.hero_hp == main.hero_max_hp and not main.dying)
		main.free()
	DirAccess.remove_absolute(SAVE)
	print("PASS resume and independent panels")
	quit()
