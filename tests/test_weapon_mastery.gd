extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var m = preload("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.save_path = "user://test_armory.json"
	m.set_physics_process(false)
	assert(m.active_hand() == "katana_ceniza" and not m.hotbar.has("katana_ceniza"))
	m.menu.open_weapon("katana_ceniza")
	m.menu._set_tab("weapon_tree")
	m.menu._close_panel()
	assert(m.wield("grimorio_ignis"))
	m.spawn_projectile("hero", m.pos, Vector2.RIGHT, m.weapon_attack("light"))
	var shot = m.get_child(-1)
	assert(m.wield("katana_ceniza"))
	var enemy = m.spawn_enemy("slime",m.pos+Vector2(60,0))
	enemy.hp = 1
	m.prog.training("grimorio_ignis").kills = 9
	shot._burn(enemy)
	assert(m.prog.training("grimorio_ignis").orbs==1 and m.prog.training("katana_ceniza").kills==0)
	m.menu.open_weapon("grimorio_ignis")
	m.menu._set_tab("weapon_tree")
	m.menu._learn_talent()
	assert(m.prog.training("grimorio_ignis").orbs==0 and m.prog.training("grimorio_ignis").nodes.has("discipline"))
	m.menu._close_panel()
	m._enter_interior("forge")
	m.pos = m.tile_to_ground(Vector2(3.1,4))
	m.prog.coins = 60
	m.crafting.add("mena_hierro",1)
	m.menu.open_weapon("grimorio_ignis")
	m.menu._forge_weapon()
	assert(m.prog.training("grimorio_ignis").level==2 and m.prog.coins==0)
	m.menu._close_panel()
	assert(m.wield("grimorio_ignis"))
	assert(m.weapon_attack("light").damage == 11 and m.weapon_attack("light").mana < 6)
	assert(m.save_game())
	m.prog.mastery.clear()
	assert(m.load_game() and m.prog.weapon=="grimorio_ignis" and m.prog.training("grimorio_ignis").nodes.has("discipline"))
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(m.save_path))
	legacy.version = 2
	legacy.erase("weapon")
	legacy.erase("mastery")
	legacy.slots = ["katana_ceniza","grimorio_ignis","pocion_vida","","",""]
	legacy.player.selected = 1
	var f := FileAccess.open(m.save_path,FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f.close()
	assert(m.load_game() and m.prog.weapon == "grimorio_ignis" and m.hotbar[1] == "" and m.hotbar[2] == "pocion_vida")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.save_path))
	print("PASS weapon slot, delayed kill credit, forging, tree, HUD and save")
	quit()
