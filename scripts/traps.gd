extends Node2D
# Nasas (en el agua, de pesca) y trampas de caza (en tierra): se colocan desde la barra de objetos, trabajan con las horas del
# reloj (clock.total) y se recogen solas al pasar cerca. El estado vive en angler.traps (se guarda con la partida).

var main: Node

func _ready() -> void:
	z_index = 400

func _cfg() -> Dictionary:
	return main.angler.cfg["traps"]

func _outside() -> bool:
	return not (main.in_dungeon or main.in_interior)

func rebuild() -> void:
	queue_redraw()

func place(id: String, kind: String) -> String:  # devuelve el aviso para el jugador
	if not _outside():
		return "Colócala en el exterior."
	var tr: Array = main.angler.traps
	if tr.size() >= int(_cfg()["max"]):
		return "Ya tienes %d colocadas; recoge alguna." % int(_cfg()["max"])
	var aim: Vector2 = main._chest_aim()
	var spot := Vector2.ZERO
	var found := false
	var steps := int(float(_cfg()["range"]) * 2.0)
	for i in range(1, steps + 1):  # sigue la mirada medio tile cada vez hasta dar con el sitio adecuado
		var g: Vector2 = main.pos + aim * float(i) * 0.5 / main._tiles_per_px(aim)
		var water: bool = main.world.is_water(main.ground_to_tile(g))
		if (kind == "water" and water) or (kind == "land" and not water and i >= 2):
			spot = g
			found = true
			break
	if not found:
		return "Apunta al agua de la orilla." if kind == "water" else "Aquí no se puede colocar."
	for t: Dictionary in tr:  # no se apilan
		if Vector2(t["pos"][0], t["pos"][1]).distance_to(spot) < 20.0:
			return "Ya hay una trampa aquí."
	var hours: float = float(_cfg()["hours"]) if kind == "water" else float(_cfg()["land_hours"])
	tr.append({"kind": kind, "pos": [spot.x, spot.y], "ready": main.clock.total + hours})
	main.crafting.take(id, 1)
	queue_redraw()
	main.combat.play_at("splash", spot)
	return "Colocada. Vuelve en unas horas de juego."

func _process(_delta: float) -> void:
	visible = _outside()
	if not visible:
		return
	queue_redraw()
	var tr: Array = main.angler.traps
	var here: Vector2 = main.ground_to_tile(main.pos)
	for i in range(tr.size() - 1, -1, -1):
		var t: Dictionary = tr[i]
		if main.clock.total >= float(t["ready"]) and here.distance_to(main.ground_to_tile(Vector2(t["pos"][0], t["pos"][1]))) <= float(_cfg()["reach"]):
			_collect(i)

func _collect(i: int) -> void:
	var t: Dictionary = main.angler.traps[i]
	main.angler.traps.remove_at(i)
	var rng: RandomNumberGenerator = main.crafting.rng
	var got: Dictionary = {}
	if t["kind"] == "water":
		var roll: Dictionary = main.fishing_node().roll(3.0, 1)
		got[roll["id"]] = int(roll["qty"])
	else:
		for id: String in _cfg()["land_loot"]:
			var r: Array = _cfg()["land_loot"][id]
			got[id] = rng.randi_range(int(r[0]), int(r[1]))
	var parts: Array[String] = []
	for id: String in got:
		main.crafting.add(id, int(got[id]))
		parts.append("%s ×%d" % [main.crafting.item_name(id), int(got[id])])
		main.quest_event("loot", id)
	main.combat.play_at("catch", main.pos)
	main.show_loot(got.keys())
	main.popup(main.pos, "Recoges la trampa: " + ", ".join(parts), Color(0.8, 0.95, 0.7))
	main.save_game()

var tex := {"water": preload("res://art/items/nasa.png"), "land": preload("res://art/items/trampa.png")}

func _draw() -> void:
	if main == null or not _outside():
		return
	var sc: float = main.SCALE
	var t_ms := Time.get_ticks_msec()
	for t: Dictionary in main.angler.traps:
		var g := Vector2(t["pos"][0], t["pos"][1]) * sc
		var bob := sin(t_ms * 0.004 + g.x) * 2.0 * sc * 0.5 if t["kind"] == "water" else 0.0
		var size := Vector2(44, 44) * sc
		draw_texture_rect(tex[t["kind"]], Rect2(g - Vector2(size.x * 0.5, size.y * 0.8 - bob), size), false)
		if main.clock.total >= float(t["ready"]):  # lista: destello que sube y baja
			draw_circle(g + Vector2(0, -44 * sc + sin(t_ms * 0.006) * 4.0), 5.0 * sc * 0.5, Color(1.0, 0.9, 0.3))
