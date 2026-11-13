extends Node2D
# Feedback de combate e iluminación dinámica: sonido/chispa/empuje por tipo de golpe, marca de Ignis
# (el fuego del grimorio marca; el tajo pesado de la katana la consume y explota) y luces locales.
# Los PNG ya traen luz horneada: aquí solo hay ambiente por zona (CanvasModulate) y luces puntuales aditivas.

const KINDS := {  # tipo de golpe -> sonido (Hz, s, ruido), color de chispa, tamaño, empuje en px/s
	"light": {"hz": 900.0, "dur": 0.07, "noise": 0.55, "col": Color(0.65, 0.85, 1.0), "size": 0.9, "push": 60.0, "shake": 1.2, "kick": 3.0, "poise": 8.0},
	"heavy": {"hz": 180.0, "dur": 0.18, "noise": 0.7, "col": Color(1.0, 0.7, 0.3), "size": 1.6, "push": 170.0, "shake": 4.5, "kick": 9.0, "poise": 30.0},
	"magic": {"hz": 420.0, "dur": 0.14, "noise": 0.35, "col": Color(1.0, 0.5, 0.15), "size": 1.2, "push": 90.0, "shake": 0.0, "kick": 2.0, "poise": 12.0},
	"blast": {"hz": 90.0, "dur": 0.35, "noise": 0.9, "col": Color(1.0, 0.45, 0.1), "size": 2.4, "push": 200.0, "shake": 6.0, "kick": 6.0, "poise": 24.0},
}
const AMBIENT_OUT := Color(0.93, 0.92, 1.0)    # exterior: atardecer suave, casi neutro
const AMBIENT_DUNGEON := Color(0.58, 0.56, 0.72)  # dungeon: penumbra índigo; las luces locales recuperan el color

var main: Node
var glow: GradientTexture2D
var ambient: CanvasModulate
var lantern: PointLight2D          # luz tenue del héroe, solo en la dungeon
var marks := {}                    # enemigo -> segundos restantes de marca de Ignis
var mark_spec := {"duration": 4.0, "damage": 22, "radius": 40.0}
var sounds := {}
const HITSTOP := 0.04             # s; punto de partida del estudio (25–40 ms), solo golpes pesados
const HITSTOP_COOLDOWN_MS := 150
var stop_until := 0

func _ready() -> void:
	z_index = 3500
	var g := Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	glow = GradientTexture2D.new()
	glow.gradient = g
	glow.width = 128
	glow.height = 128
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 1.0)
	ambient = CanvasModulate.new()
	main.add_child.call_deferred(ambient)
	lantern = light(Color(1.0, 0.82, 0.6), 0.0, 3.2)
	main.add_child.call_deferred(lantern)
	for k: String in KINDS:
		sounds[k] = _synth(KINDS[k]["hz"], KINDS[k]["dur"], KINDS[k]["noise"])
	set_zone(false)

func set_zone(dungeon: bool) -> void:  # ambiente por mapa; las luces transitorias se liberan con su dueño
	if main.music:
		main.music.set_zone(dungeon)
	ambient.color = AMBIENT_DUNGEON if dungeon else AMBIENT_OUT
	main.clock.outdoors = not dungeon
	lantern.energy = 0.55 if dungeon else 0.0
	marks.clear()

const AMBIENT_INDOOR := Color(0.9, 0.78, 0.66)   # interior de una casa: luz cálida de fuego y ventanas

func set_indoors() -> void:  # tras set_zone(false): sala cálida, con la linterna del héroe apagada
	ambient.color = AMBIENT_INDOOR
	main.clock.outdoors = false
	lantern.energy = 0.0

func light(col: Color, energy: float, size: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = glow
	l.color = col
	l.energy = energy
	l.texture_scale = size
	return l

func flash(ground: Vector2, col: Color, energy: float, size: float, secs: float) -> void:  # destello que se apaga y se borra
	if main.settings.flash <= 0.0:
		return
	var l := light(col, energy * main.settings.flash, size)
	l.position = (ground - Vector2(0, 16)) * main.SCALE
	main.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, secs)
	tw.tween_callback(l.queue_free)

# único punto de daño del héroe a enemigos: aplica daño, empuje, sonido, chispa y luz según el tipo de golpe
func hit(e: Node, dmg: int, kind: String, from: Vector2, charge := true) -> void:
	if not e.alive:
		return
	var k: Dictionary = KINDS[kind]
	e.take_damage(dmg, charge)
	if charge and (kind == "light" or kind == "heavy"):
		main.mana_on_hit(kind)  # la espada alimenta la magia
	if e.alive and e.has_method("add_poise"):
		e.add_poise(k["poise"])  # postura: los élites se abren si los castigas
	if e.alive and e.has_method("knock"):  # el dragón no tiene empuje
		e.knock((e.pos - from).normalized() * k["push"], kind == "heavy" or kind == "blast")
	play(kind)
	_spark(e.pos, k["col"], k["size"])
	if e.alive and e.has_method("knock"):
		_squash(e, kind == "heavy" or kind == "blast")
	if kind == "heavy" or kind == "blast":
		ground_impact(e.pos, 1.0 if kind == "heavy" else 1.6)
	_splatter(e, (e.pos - from).normalized(), {"light": 5, "heavy": 10, "magic": 4, "blast": 12}[kind])
	flash(e.pos, k["col"], 0.35 * k["size"], 0.8 * k["size"], 0.18)
	if k["shake"] > 0.0:
		main.shake(k["shake"])
	main.kick((e.pos - from).normalized() * k["kick"])  # la cámara se empuja hacia donde va el golpe
	if kind == "heavy" and main.settings.hitstop:
		_hitstop(e)
	main.noise(e.pos, 240.0 if kind == "heavy" or kind == "blast" else 150.0)  # el combate asusta a la fauna y a los civiles

# señales de intención (gruñido, chillido, grito, alerta): suenan más bajo cuanto más lejos del héroe
const CUES := {  # nombre -> (Hz, s, ruido)
	"growl": [95.0, 0.55, 0.65], "squeak": [1700.0, 0.09, 0.1], "shout": [320.0, 0.28, 0.25], "alert": [760.0, 0.12, 0.2],
	"cast": [260.0, 0.28, 0.9], "splash": [150.0, 0.32, 0.85], "bite": [1250.0, 0.16, 0.08], "hook": [520.0, 0.12, 0.45],
	"catch": [980.0, 0.3, 0.1], "chest": [1500.0, 0.4, 0.04], "sleep": [200.0, 0.6, 0.3],
}

func play_at(cue: String, ground: Vector2) -> void:
	var d: float = ground.distance_to(main.pos)
	if d > 420.0:
		return
	if not sounds.has(cue):
		var c: Array = CUES[cue]
		sounds[cue] = _synth(c[0], c[1], c[2])
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = sounds[cue]
	p.volume_db = -10.0 - d / 25.0
	p.pitch_scale = randf_range(0.9, 1.1)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# pausa de impacto: solo presentación (animaciones); el reloj lógico —cooldowns, proyectiles, zonas— sigue corriendo
func _hitstop(e: Node) -> void:
	var now := Time.get_ticks_msec()
	if now < stop_until:  # un tajo que golpea a varios no acumula pausas
		return
	stop_until = now + HITSTOP_COOLDOWN_MS
	var sprites: Array = [main.hero]
	var s: Variant = e.get("spr")
	if s:
		sprites.append(s)
	for a: AnimatedSprite2D in sprites:
		a.speed_scale = 0.0
	await get_tree().create_timer(HITSTOP, true, false, true).timeout
	for a: AnimatedSprite2D in sprites:
		if is_instance_valid(a):
			a.speed_scale = 1.0

func play(kind: String) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = sounds[kind]
	p.volume_db = -8.0
	p.pitch_scale = randf_range(0.92, 1.08)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# reacción del cuerpo: se aplasta y rebota con sobreimpulso (el nodo del enemigo tiene el origen en los pies)
func _squash(e: Node2D, heavy: bool) -> void:
	var tw: Tween = e.get_meta("squash_tw") if e.has_meta("squash_tw") else null
	if tw and tw.is_valid():
		tw.kill()
	var amt := 0.28 if heavy else 0.15
	e.scale = Vector2(1.0 + amt, 1.0 - amt)
	tw = e.create_tween()
	tw.tween_property(e, "scale", Vector2.ONE, 0.22 if heavy else 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	e.set_meta("squash_tw", tw)

func _splatter(e: Node, dir: Vector2, count: int) -> void:  # gotas del color de la criatura (data "blood")
	var d: Variant = e.get("data")
	var s := preload("res://scripts/splatter.gd").new()
	s.tint = Color(d.get("blood", "#9b1c24")) if d is Dictionary else Color("#9b1c24")
	s.dir = dir if dir != Vector2.ZERO else Vector2.RIGHT
	s.count = count
	s.position = e.pos * main.SCALE
	s.z_index = int(e.pos.y) + 2
	main.add_child(s)

func ground_impact(ground: Vector2, size: float) -> void:  # onda y grietas en el suelo bajo un golpe fuerte
	var g := preload("res://scripts/ground_impact.gd").new()
	g.position = ground * main.SCALE
	g.size = size
	g.tint = Color("#c4c3dc") if main.in_dungeon else Color("#f2e6c8")
	g.z_index = -2999  # sobre el suelo, bajo entidades
	main.add_child(g)

func _spark(ground: Vector2, col: Color, size: float) -> void:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = main.fx_frames
	s.scale = Vector2.ONE * main.SCALE * size
	s.modulate = col
	s.position = (ground - Vector2(0, 22)) * main.SCALE
	s.z_index = int(ground.y) + 8
	s.z_as_relative = false
	main.add_child(s)
	s.play("impact")
	s.animation_finished.connect(s.queue_free)

# --- marca de Ignis
func mark(e: Node) -> void:
	if e.alive:
		marks[e] = mark_spec["duration"] + main.prog.skill_sum("mark_time")  # marcar de nuevo solo refresca

func consume(e: Node) -> bool:
	return marks.erase(e)

func detonate(ground: Vector2) -> void:  # la explosión no marca ni consume marcas: no puede encadenarse
	detonate_at(ground, mark_spec["radius"], roundi(float(mark_spec["damage"]) * (1.0 + main.prog.skill_sum("mark_dmg_pct"))))

func detonate_at(ground: Vector2, radius: float, damage: int) -> void:  # también la usa el frasco de Ignis (alquimia)
	play("blast")
	flash(ground, Color(1.0, 0.5, 0.15), 1.4, 3.5, 0.45)
	ground_impact(ground, 1.8)
	_spark(ground, KINDS["blast"]["col"], KINDS["blast"]["size"])
	main.shake(KINDS["blast"]["shake"])
	for e in main.targets():
		if e.alive and preload("res://scripts/hitbox.gd").foot_dist(e, ground) < radius:
			hit(e, roundi(damage * main.prog.magic_mult()), "blast", ground, false)

func _process(delta: float) -> void:
	if main.clock.outdoors:  # el exterior sigue la hora del día; el resto de zonas tiene su ambiente fijo
		ambient.color = main.clock.tint().lerp(Color.WHITE, main.clock.dark() * 0.75 if main.night_vision_t > 0.0 else 0.0)  # el elixir de visión nocturna aclara la noche
	for e in marks.keys():
		marks[e] -= delta
		if marks[e] <= 0.0 or not is_instance_valid(e) or not e.alive:
			marks.erase(e)
	lantern.position = (main.pos - Vector2(0, 30)) * main.SCALE
	queue_redraw()

func _ellipse_pts(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(c + Vector2(cos(i * TAU / 32.0) * rx, sin(i * TAU / 32.0) * ry))
	return pts

func _draw_hitboxes(S: float) -> void:  # F2: cuerpo (verde) y huella (azul) de cada blanco y del héroe
	var HB := preload("res://scripts/hitbox.gd")
	var list: Array = main.targets() + [main]
	if not main.in_dungeon:
		list += main.villagers + main.merchants
	for e in list:
		if e != main and not e.alive if e.get("alive") != null else false:
			continue
		var b: Dictionary = HB.of(e)
		draw_polyline(_ellipse_pts((e.pos + b["c"]) * S, b["rx"] * S, b["ry"] * S), Color(0.2, 1.0, 0.3, 0.9), 2.0)
		draw_polyline(_ellipse_pts(e.pos * S, b["rx"] * S, b["rx"] * HB.SQUASH * S), Color(0.3, 0.6, 1.0, 0.9), 2.0)

func _draw() -> void:  # anillo de brasas parpadeante bajo cada enemigo marcado
	var S: float = main.SCALE
	if main.debug_hitboxes:
		_draw_hitboxes(S)
	for e in marks:
		var a := 0.55 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		var c: Vector2 = e.pos * S
		var pts := PackedVector2Array()
		for i in 25:
			var ang := i * TAU / 24.0
			pts.append(c + Vector2(cos(ang), sin(ang) * 0.6) * (preload("res://scripts/hitbox.gd").of(e)["rx"] + 4.0) * S)
		draw_polyline(pts, Color(1.0, 0.45, 0.1, a), 4.0)
		draw_circle(c - Vector2(0, 8 * S), 2.5 * S, Color(1.0, 0.7, 0.2, a))

func _synth(hz: float, dur: float, noise: float) -> AudioStreamWAV:  # golpe sintetizado: tono descendente + ruido con caída
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var x := float(i) / n
		ph += TAU * hz * (1.0 - 0.6 * x) / rate
		var v := (sin(ph) * (1.0 - noise) + randf_range(-1, 1) * noise) * pow(1.0 - x, 2.0)
		data.encode_s16(i * 2, int(clampf(v, -1, 1) * 26000))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
