extends Node
# Piso de la dungeon: aparece sus monstruos (data/dungeon.json), bloquea la puerta del siguiente piso
# hasta matarlos a todos y, al completar el piso, aparece el cofre de recompensa.

var main: Node
var cfg := {}
var floor_no := 1
var cleared := false
var next_door: Node2D
var chest: Node2D
var chest_door: Node2D
var label: Label
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	cfg = main._read_json("res://data/dungeon.json")
	rng.randomize()
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = 12.0
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)

func start(n: int) -> void:
	floor_no = n
	main.dungeon_floor = n
	cleared = false
	for e in main.enemies.duplicate():
		if e != main.dragon:
			main.enemies.erase(e)
			e.queue_free()
	for node in [next_door, chest_door]:
		if is_instance_valid(node):
			main.doors.erase(node)
			node.queue_free()
	if is_instance_valid(chest):
		chest.queue_free()
	next_door = null
	chest_door = null
	chest = null
	var f: Dictionary = cfg["floors"][n - 1]
	var spawn: Vector2 = main.ground_to_tile(main._dungeon_spawn())
	var placed: Array[Vector2] = []
	for id: String in f["enemies"]:
		for i in int(f["enemies"][id]):
			var t := _free_tile(placed, spawn)
			placed.append(t)
			main.spawn_enemy(id, main.tile_to_ground(t))
	if n < cfg["floors"].size():
		next_door = main._add_door(Vector2(12.5, 24.75), "Bajar al piso %d" % (n + 1), next_floor)
		next_door.locked = true
	main.say(f["name"], 2.5)

func _free_tile(placed: Array[Vector2], spawn: Vector2) -> Vector2:  # casilla lejos de la entrada y de otros monstruos
	for attempt in 60:
		var t := Vector2(rng.randf_range(3.0, 22.0), rng.randf_range(7.0, 22.0))
		if t.distance_to(spawn) < 6.0:
			continue
		var ok := true
		for p in placed:
			if t.distance_to(p) < 3.0:
				ok = false
		if ok:
			return t
	return Vector2(12.5, 12.5)

func _process(_delta: float) -> void:
	if cleared:
		return
	var left := 0
	for e in main.enemies:
		if e != main.dragon and e.alive:
			left += 1
	label.text = "%s  ·  Enemigos: %d" % [cfg["floors"][floor_no - 1]["name"], left]
	if next_door:
		next_door.lock_text = "Derrota a todos los enemigos (%d)" % left
	if left == 0:
		_clear()

func _clear() -> void:
	cleared = true
	label.text = "%s  ·  ¡Completo!" % cfg["floors"][floor_no - 1]["name"]
	if next_door:
		next_door.locked = false
	var spot := Vector2(12.5, 12.5)
	chest = Node2D.new()
	chest.set_script(load("res://scripts/chest.gd"))
	chest.main = main
	chest.tile = spot
	main.add_child(chest)
	chest_door = main._add_door(spot, "Abrir cofre", open_chest, false)
	chest_door.reach = 1.6
	main.say("¡Piso completo! Abre el cofre", 3.0)

func next_floor() -> void:
	main._transition(func() -> void:
		start(floor_no + 1)
		main.pos = main._dungeon_spawn()
		main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE)

func open_chest() -> void:
	var c: Dictionary = cfg["floors"][floor_no - 1]["chest"]
	chest.open()
	main.doors.erase(chest_door)
	chest_door.queue_free()
	chest_door = null
	var coins := rng.randi_range(int(c["coins"][0]), int(c["coins"][1]))
	main.prog.coins += coins
	var lines: Array[String] = ["+%d monedas" % coins, "+%d XP" % int(c["xp"])]
	var fresh: Array = c["pool"].filter(func(i: String) -> bool: return not main.prog.owned.has(i))
	var rest: Array = c["pool"].filter(func(i: String) -> bool: return main.prog.owned.has(i))
	fresh.shuffle()
	rest.shuffle()
	var got: Array = (fresh + rest).slice(0, int(c["items"]))
	for id: String in got:
		lines.append(main.give_item(id))
	main.show_loot(got)
	main.gain_xp(int(c["xp"]))
	if c.get("final", false):
		lines.append("¡Dungeon completada!")
		label.text = "¡Dungeon completada!"
		main.dungeon_floor = 1  # la próxima visita empieza de nuevo
	main.say("\n".join(lines), 6.0)
