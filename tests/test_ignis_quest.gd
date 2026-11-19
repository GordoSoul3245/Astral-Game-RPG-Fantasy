extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._start_fresh()
	assert(main.dialogue.name_label.text == "Jugador" and main.dialogue.cast.get_child_count() == 0)
	main.dialogue.close()
	var camp = main.doors.filter(func(d): return d.label == "Hablar con el viejo").front()
	await camp.use()
	assert(main.quests.met_gaucho and main.dialogue.is_open())
	main.dialogue.close()
	var q = main.quests
	assert(q.talk(main).contains("Ignis") and q.status == "active")
	assert(not q.notify("floor", "1") and not q.notify("floor", "1") and q.progress == 1)
	q.from_dict(JSON.parse_string(JSON.stringify(q.to_dict())))
	assert(not q.notify("floor", "2") and q.progress == 2)
	assert(q.notify("floor", "3") and not q.notify("floor", "4"))
	var coins: int = main.prog.coins
	var payout: String = q.talk(main)
	assert(payout.contains("+1000 XP") and main.prog.coins == coins + 600 and q.current().is_empty())
	var level: int = main.prog.level
	var xp: int = main.prog.xp
	q.from_dict(JSON.parse_string(JSON.stringify(q.to_dict())))
	q.talk(main)
	assert(main.prog.coins == coins + 600 and main.prog.level == level and main.prog.xp == xp)
	print("PASS despertar, payada, encargo, tres pisos distintos, guardado y recompensa única")
	quit()

