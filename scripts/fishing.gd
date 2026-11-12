extends Node2D
# Pesca (estilo Stardew Valley), con la caña equipada en la barra de objetos:
#   mantener el clic = cargar la fuerza del lanzamiento · soltar = lanzar al agua · esperar a que pique (aparece «!») ·
#   clic a tiempo = clavar el anzuelo · minijuego (fish_game.gd): mantener el clic sube la barra, soltar la deja caer.
# Lanzar lejos da acceso a peces más raros; las cañas mejores lanzan más lejos y dan una barra más larga. Datos en data/fishing.json.

const FishGame := preload("res://scripts/fish_game.gd")
const FLIGHT_TIME := 0.55

var main: Node
var cfg: Dictionary = {}
var active := false
var state := ""            # charge, throw, flight, wait, bite, fight, end
var t := 0.0
var power := 0.0
var rod_tier := 1
var aim := Vector2.DOWN
var bob_from := Vector2.ZERO
var bob_g := Vector2.ZERO  # donde cae el flotador (suelo)
var flight := 0.0
var wait_t := 0.0
var nibble_t := 0.0
var dip := 0.0              # el flotador se hunde al picar
var bite_t := 0.0
var ripple := 0.0
var hooked: Dictionary = {}  # {id, junk, qty, fish}
var game: RefCounted
var fish_icon: Texture2D
var overlay
var ui: CanvasLayer
var end_t := 0.0

func setup(m: Node) -> void:
	main = m
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/fishing.json"))
	z_index = 3500
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	overlay = _Overlay.new()
	overlay.fishing = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)

# --- elección del pez: por distancia del lanzamiento y nivel de la caña
func roll(dist_tiles: float, tier: int) -> Dictionary:
	var rng: RandomNumberGenerator = main.crafting.rng
	var pool: Array = []
	var total := 0.0
	for id: String in cfg["fish"]:
		var f: Dictionary = cfg["fish"][id]
		if dist_tiles >= float(f["min_tiles"]) and tier >= int(f["min_rod"]):
			pool.append(id)
			total += float(f["weight"])
	if pool.is_empty() or rng.randf() < float(cfg["junk_chance"]):
		var jid: String = (cfg["junk"] as Dictionary).keys()[0]
		var r: Array = cfg["junk"][jid]
		return {"id": jid, "junk": true, "qty": rng.randi_range(int(r[0]), int(r[1]))}
	var pick := rng.randf() * total
	for id: String in pool:
		pick -= float(cfg["fish"][id]["weight"])
		if pick <= 0.0:
			return {"id": id, "junk": false, "qty": 1}
	return {"id": pool[-1], "junk": false, "qty": 1}

# --- ciclo
func start(rod_id: String) -> void:
	active = true
	state = "charge"
	t = 0.0
	power = 0.0
	rod_tier = int(main.prog.equipment[rod_id]["tool"]["tier"])
	main.move_vel = Vector2.ZERO
	aim = main._chest_aim()
	main.facing = main.DIRS[posmod(roundi(aim.angle() / (PI / 4.0)), 8)]
	main.hero.play("fish_cast_" + main.facing)
	main.hero.frame = 1  # en guardia, con la caña atrás
	main.hero.pause()

func cancel(msg := "") -> void:
	if not active:
		return
	if msg != "":
		main.say(msg, 1.6)
	_close()

func _close() -> void:
	active = false
	state = ""
	game = null
	overlay.queue_redraw()
	queue_redraw()
	main.hero.play("idle_" + main.facing)
	main.cooldown = 0.35

func press() -> void:  # clic (pulsación) durante la pesca
	match state:
		"wait":
			cancel("Recoges el sedal.")
		"bite":
			_hook()

func tick(delta: float) -> void:
	if not active:
		return
	t += delta
	match state:
		"charge":
			power = clampf(t / float(cfg["cast"]["charge_time"]), 0.0, 1.0)
			if not main._mb(MOUSE_BUTTON_LEFT) and t > 0.08:
				_release()
		"throw":
			if main.hero.frame >= 3 or t > 0.4:
				_launch()
		"flight":
			flight += delta / FLIGHT_TIME
			if flight >= 1.0:
				_land()
		"wait":
			ripple += delta
			dip = maxf(0.0, dip - delta * 4.0)
			nibble_t -= delta
			if nibble_t <= 0.0:  # tirones suaves que no son el pique
				nibble_t = main.crafting.rng.randf_range(0.8, 2.0)
				dip = 0.35
			wait_t -= delta
			if wait_t <= 0.0:
				_bite()
		"bite":
			dip = 1.0
			bite_t -= delta
			if bite_t <= 0.0:
				_end("Se escapó…", false)
		"fight":
			game.step(delta, main._mb(MOUSE_BUTTON_LEFT))
			if game.done:
				_end("", game.won)
		"end":
			end_t -= delta
			if end_t <= 0.0:
				_close()
	queue_redraw()
	overlay.queue_redraw()

func _release() -> void:
	aim = main._chest_aim()
	main.facing = main.DIRS[posmod(roundi(aim.angle() / (PI / 4.0)), 8)]
	var key: String = "fish_cast_" + main.facing
	if main.hero.animation != key:
		main.hero.play(key)
	main.hero.frame = 2
	main.hero.play()
	state = "throw"
	t = 0.0

func tip() -> Vector2:  # punta de la caña, en suelo
	return main.pos + aim * 22.0 + Vector2(0, -46)

func _launch() -> void:
	var c: Dictionary = cfg["cast"]
	var tiles := lerpf(float(c["min_tiles"]), float(c["max_tiles"]), power) + float(c["rod_bonus"]) * rod_tier
	bob_from = tip()
	bob_g = main.pos + aim * tiles / main._tiles_per_px(aim)
	flight = 0.0
	state = "flight"

func _land() -> void:
	var tile: Vector2 = main.ground_to_tile(bob_g)
	if not (main.world.has_method("is_water") and main.world.is_water(tile)):
		main.say("Apunta al agua; mantén el clic más tiempo para lanzar lejos.", 2.2)
		_close()
		return
	var wait: Array = cfg["bite_wait"]
	wait_t = maxf(1.5, main.crafting.rng.randf_range(float(wait[0]), float(wait[1])) - 0.3 * rod_tier)
	nibble_t = 1.0
	ripple = 0.0
	state = "wait"
	main.hero.play("fish_wait_" + main.facing)
	main.shake(1.0)

func _bite() -> void:
	var dist: float = main.ground_to_tile(bob_g).distance_to(main.ground_to_tile(main.pos))
	hooked = roll(dist, rod_tier)
	var diff := 20.0 if hooked["junk"] else float(cfg["fish"][hooked["id"]]["diff"])
	bite_t = maxf(0.5, float(cfg["bite_window"]) - diff * 0.003)
	state = "bite"
	main.shake(2.0)

func _hook() -> void:
	if hooked["junk"]:
		_end("", true)
		return
	var f: Dictionary = cfg["fish"][hooked["id"]]
	game = FishGame.new()
	game.setup(str(f["move"]), float(f["diff"]), float(cfg["bar_size"]["base"]) + float(cfg["bar_size"]["per_rod"]) * rod_tier)
	fish_icon = load(main.crafting.icon(hooked["id"]))
	state = "fight"
	main.hero.play("fish_reel_" + main.facing)

func _end(msg: String, won: bool) -> void:
	state = "end"
	end_t = 0.9
	if not won:
		main.popup(main.pos, msg if msg != "" else "¡Se escapó!", Color(1.0, 0.5, 0.45))
		main.hero.play("fish_wait_" + main.facing)
		return
	var id: String = hooked["id"]
	var qty: int = int(hooked["qty"])
	var line: String = main.crafting.item_name(id)
	if not hooked["junk"]:
		var s: Array = cfg["fish"][id]["size"]
		var cm: int = main.crafting.rng.randi_range(int(s[0]), int(s[1]))
		if game != null and game.perfect:
			qty += 1  # pesca perfecta: sale otro
			line += " ×%d  ·  %d cm  ¡Perfecto!" % [qty, cm]
		else:
			line += "  ·  %d cm" % cm
	elif qty > 1:
		line += " ×%d" % qty
	main.crafting.add(id, qty)
	main.quest_event("loot", id)
	main.show_loot([id])
	main.popup(main.pos, line, Color(0.6, 0.95, 1.0))
	main.shake(3.0)

# --- dibujo en el mundo: fuerza, sedal, flotador, ondas y el «!» del pique
func _screen(g: Vector2, h := 0.0) -> Vector2:
	return (g - Vector2(0, h)) * main.SCALE

func _draw() -> void:
	if not active:
		return
	var sc: float = main.SCALE
	var head := _screen(main.pos, 78.0)
	if state == "charge":  # barra de fuerza bajo los pies
		var o := _screen(main.pos + Vector2(-18, 8))
		draw_rect(Rect2(o - Vector2(2, 2), Vector2(36 * sc + 4, 8 * sc + 4)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(o, Vector2(36 * sc * power, 8 * sc)), Color(0.4, 0.9, 0.4).lerp(Color(1.0, 0.45, 0.2), power))
	var bob := Vector2.ZERO
	var has_bob := false
	if state == "flight":
		var g := bob_from.lerp(bob_g, flight)
		bob = _screen(g, sin(flight * PI) * 46.0)
		has_bob = true
	elif state in ["wait", "bite", "fight"]:
		bob = _screen(bob_g, -1.5 * dip if state != "fight" else 0.0)
		has_bob = true
		_ripples(_screen(bob_g))
	if has_bob:
		_line(_screen(tip()), bob, 0.0 if state == "fight" else 22.0 * (1.0 - flight if state == "flight" else 1.0))
		draw_circle(bob + Vector2(0, 2), 3.2 * sc, Color(1, 1, 1))
		var top := PackedVector2Array()
		for i in 13:
			var a := PI + float(i) / 12.0 * PI
			top.append(bob + Vector2(2, 2) + Vector2(cos(a), sin(a)) * 3.2 * sc)
		draw_colored_polygon(top, Color(0.9, 0.12, 0.12))
	if state == "bite":
		var f: Font = ThemeDB.fallback_font
		var pulse := 1.0 + 0.15 * sin(t * 30.0)
		draw_string_outline(f, head + Vector2(-14, 0), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, int(72 * pulse), 10, Color.BLACK)
		draw_string(f, head + Vector2(-14, 0), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, int(72 * pulse), Color(1.0, 0.85, 0.2))

func _line(a: Vector2, b: Vector2, sag: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var k := float(i) / 12.0
		pts.append(a.lerp(b, k) + Vector2(0, sin(k * PI) * sag * main.SCALE))
	draw_polyline(pts, Color(1, 1, 1, 0.85), 1.5)

func _ripples(c: Vector2) -> void:
	for i in 3:
		var k := fmod(ripple * 0.7 + float(i) / 3.0, 1.0)
		draw_set_transform(c, 0.0, Vector2(1, 0.45))
		draw_arc(Vector2.ZERO, (6.0 + k * 22.0) * main.SCALE * 0.5, 0.0, TAU, 28, Color(0.85, 0.95, 1.0, 0.7 * (1.0 - k)), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- minijuego: pista vertical a la derecha del héroe
class _Overlay extends Control:
	var fishing: Node2D

	func _draw() -> void:
		if fishing == null or not fishing.active or fishing.state != "fight" or fishing.game == null:
			return
		var g: RefCounted = fishing.game
		var vp := get_viewport_rect().size
		var track := Rect2(vp.x * 0.5 + 300.0, vp.y * 0.5 - 230.0, 54.0, 420.0)
		draw_rect(Rect2(track.position - Vector2(8, 8), track.size + Vector2(46, 16)), Color(0.05, 0.07, 0.12, 0.88))
		draw_rect(track, Color(0.12, 0.2, 0.32, 0.9))
		var bar_h: float = g.size * track.size.y
		var bar_y: float = track.end.y - (g.bar * track.size.y) - bar_h
		var good: bool = g.inside()
		draw_rect(Rect2(track.position.x, bar_y, track.size.x, bar_h), Color(0.3, 0.85, 0.4, 0.62 if good else 0.4))
		draw_rect(Rect2(track.position.x, bar_y, track.size.x, bar_h), Color(0.6, 1.0, 0.65), false, 3.0)
		var icon_c := Vector2(track.position.x + track.size.x * 0.5, track.end.y - g.fish * track.size.y)
		if fishing.fish_icon:
			draw_texture_rect(fishing.fish_icon, Rect2(icon_c - Vector2(24, 24), Vector2(48, 48)), false)
		var meter := Rect2(track.end.x + 8, track.position.y, 14, track.size.y)
		draw_rect(meter, Color(0.1, 0.12, 0.18))
		var fill: float = g.progress * meter.size.y
		draw_rect(Rect2(meter.position.x, meter.end.y - fill, meter.size.x, fill), Color(0.9, 0.3, 0.2).lerp(Color(0.3, 0.9, 0.35), g.progress))
		draw_rect(meter, Color(0.7, 0.75, 0.85), false, 2.0)
		var f: Font = ThemeDB.fallback_font
		draw_string(f, track.position + Vector2(-8, track.size.y + 34), "Mantén el clic: sube", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.85, 0.95))
