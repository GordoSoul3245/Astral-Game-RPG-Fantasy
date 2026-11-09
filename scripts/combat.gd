extends Node2D
# Feedback de combate e iluminación dinámica: sonido/chispa/empuje por tipo de golpe, marca de Ignis
# (el fuego del grimorio marca; el tajo pesado de la katana la consume y explota) y luces locales.
# Los PNG ya traen luz horneada: aquí solo hay ambiente por zona (CanvasModulate) y luces puntuales aditivas.

const KINDS := {  # tipo de golpe -> sonido (Hz, s, ruido), color de chispa, tamaño, empuje en px/s
	"light": {"hz": 900.0, "dur": 0.07, "noise": 0.55, "col": Color(0.65, 0.85, 1.0), "size": 0.9, "push": 60.0, "shake": 0.0},
	"heavy": {"hz": 180.0, "dur": 0.18, "noise": 0.7, "col": Color(1.0, 0.7, 0.3), "size": 1.6, "push": 170.0, "shake": 3.5},
	"magic": {"hz": 420.0, "dur": 0.14, "noise": 0.35, "col": Color(1.0, 0.5, 0.15), "size": 1.2, "push": 90.0, "shake": 0.0},
	"blast": {"hz": 90.0, "dur": 0.35, "noise": 0.9, "col": Color(1.0, 0.45, 0.1), "size": 2.4, "push": 200.0, "shake": 6.0},
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
	ambient.color = AMBIENT_DUNGEON if dungeon else AMBIENT_OUT
	lantern.energy = 0.55 if dungeon else 0.0
	marks.clear()

func light(col: Color, energy: float, size: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = glow
	l.color = col
	l.energy = energy
	l.texture_scale = size
	return l

func flash(ground: Vector2, col: Color, energy: float, size: float, secs: float) -> void:  # destello que se apaga y se borra
	var l := light(col, energy, size)
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
	if e.alive and e.has_method("knock"):  # el dragón no tiene empuje
		e.knock((e.pos - from).normalized() * k["push"], kind == "heavy" or kind == "blast")
	play(kind)
	_spark(e.pos, k["col"], k["size"])
	flash(e.pos, k["col"], 0.35 * k["size"], 0.8 * k["size"], 0.18)
	if k["shake"] > 0.0:
		main.shake(k["shake"])

func play(kind: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sounds[kind]
	p.volume_db = -8.0
	p.pitch_scale = randf_range(0.92, 1.08)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

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
		marks[e] = mark_spec["duration"]  # marcar de nuevo solo refresca

func consume(e: Node) -> bool:
	return marks.erase(e)

func detonate(ground: Vector2) -> void:  # la explosión no marca ni consume marcas: no puede encadenarse
	play("blast")
	flash(ground, Color(1.0, 0.5, 0.15), 1.4, 3.5, 0.45)
	_spark(ground, KINDS["blast"]["col"], KINDS["blast"]["size"])
	main.shake(KINDS["blast"]["shake"])
	for e in main.enemies.duplicate():
		if e.alive and ground.distance_to(e.pos) < mark_spec["radius"] + e.radius:
			hit(e, roundi(mark_spec["damage"] * main.prog.magic_mult()), "blast", ground, false)

func _process(delta: float) -> void:
	for e in marks.keys():
		marks[e] -= delta
		if marks[e] <= 0.0 or not is_instance_valid(e) or not e.alive:
			marks.erase(e)
	lantern.position = (main.pos - Vector2(0, 30)) * main.SCALE
	queue_redraw()

func _draw() -> void:  # anillo de brasas parpadeante bajo cada enemigo marcado
	var S: float = main.SCALE
	for e in marks:
		var a := 0.55 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		var c: Vector2 = e.pos * S
		var pts := PackedVector2Array()
		for i in 25:
			var ang := i * TAU / 24.0
			pts.append(c + Vector2(cos(ang), sin(ang) * 0.6) * (e.radius + 6.0) * S)
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
