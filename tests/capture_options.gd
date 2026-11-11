extends SceneTree
# Captura real (sin --headless): pestaña Opciones del menú y comprobación de que la música sintetizada arranca.

var main: Node

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.force_music = true
	root.add_child(main)
	main.save_path = "user://capture_save.json"
	main.settings.path = "user://capture_settings.json"
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	var waited := 0.0
	while not main.music.started and waited < 60.0:  # la síntesis corre en un hilo
		await create_timer(0.5).timeout
		waited += 0.5
	print("MUSICA lista tras %.1f s, capas: %s" % [waited, main.music.players.keys()])
	assert(main.music.started and main.music.players.size() == 6, "la música arranca con sus 6 capas")
	await create_timer(1.5).timeout
	var vols := {}
	for k: String in main.music.players:
		vols[k] = snappedf(main.music.players[k].volume_db, 0.1)
	print("volúmenes (dB) en el exterior: ", vols)
	assert(main.music.players["out_base"].volume_db > -20.0 and main.music.players["dun_base"].volume_db < -40.0, "suena el tema del exterior, no el de la dungeon")
	main._enter_dungeon()
	await create_timer(1.6).timeout
	assert(main.music.players["dun_base"].volume_db > -20.0 and main.music.players["out_base"].volume_db < -40.0, "al entrar suena el tema de la dungeon")
	main._exit_dungeon()
	main.menu.visible = true
	main.menu.tab = "opt"
	main.menu.refresh()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/options_menu.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.settings.path))
	print("PASS options capture saved")
	quit()
