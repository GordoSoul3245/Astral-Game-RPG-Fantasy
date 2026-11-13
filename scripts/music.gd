extends Node
# Música y ambiente generados por código (sin archivos): un tema por zona (exterior, dungeon), una capa de combate
# que entra cuando hay enemigos cerca y un ambiente (viento y pájaros / goteo y rumor). Los bucles se sintetizan
# en un hilo al arrancar; todas las capas de una zona duran lo mismo y empiezan juntas, así que siempre van a compás.
# Escala A menor pentatónica; 60 bpm; 4 compases de 4 s (16 s).

const RATE := 16000
const LOOP := 16.0
const A := 110.0  # La2

var main: Node
var ready_loops := {}        # nombre -> AudioStreamWAV
var players := {}            # nombre -> AudioStreamPlayer
var dungeon := false
var combat := false
var thread: Thread
var started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	thread = Thread.new()
	thread.start(_build_all)

func _exit_tree() -> void:
	if thread and thread.is_started():
		thread.wait_to_finish()

func _process(_delta: float) -> void:
	if not started and thread and thread.is_started() and not thread.is_alive():
		thread.wait_to_finish()
		_start()

# --- control
func set_theme(pitch: float) -> void:  # cada región suena un poco distinta: más grave en la marisma, más aguda en el desierto
	for p: AudioStreamPlayer in players.values():
		p.pitch_scale = pitch
	theme_pitch = pitch

var theme_pitch := 1.0

func set_zone(is_dungeon: bool) -> void:
	dungeon = is_dungeon
	_mix()

func set_combat(on: bool) -> void:
	if on != combat:
		combat = on
		_mix()

func _mix() -> void:  # volumen objetivo de cada capa (se acerca con un tween suave)
	if not started:
		return
	var targets := {
		"out_base": 0.0 if dungeon else 1.0, "out_ambience": 0.0 if dungeon else 1.0, "out_combat": 1.0 if (combat and not dungeon) else 0.0,
		"dun_base": 1.0 if dungeon else 0.0, "dun_ambience": 1.0 if dungeon else 0.0, "dun_combat": 1.0 if (combat and dungeon) else 0.0,
	}
	for k: String in targets:
		var p: AudioStreamPlayer = players[k]
		create_tween().tween_property(p, "volume_db", linear_to_db(maxf(targets[k] * float(LEVEL[k]), 0.0001)), 1.2)

const LEVEL := {"out_base": 0.8, "out_ambience": 0.5, "out_combat": 0.55, "dun_base": 0.8, "dun_ambience": 0.55, "dun_combat": 0.6}

func _start() -> void:
	started = true
	for k: String in ready_loops:
		var p := AudioStreamPlayer.new()
		p.stream = ready_loops[k]
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		players[k] = p
	for p: AudioStreamPlayer in players.values():  # todas a la vez: quedan sincronizadas
		p.pitch_scale = theme_pitch
		p.play()
	_mix()

# --- síntesis (se ejecuta en un hilo)
func _build_all() -> void:
	var loops := {
		"out_base": render_outdoor_base(), "out_ambience": render_outdoor_ambience(), "out_combat": render_combat(false),
		"dun_base": render_dungeon_base(), "dun_ambience": render_dungeon_ambience(), "dun_combat": render_combat(true),
	}
	for k: String in loops:
		ready_loops[k] = to_wav(loops[k])

static func to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:  # 16 bits mono con bucle
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w

static func _buffer() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(RATE * LOOP))
	return b

# suma una nota que se envuelve al principio del bucle (la cola de la última nota suena al comienzo: sin cortes)
static func _note(buf: PackedFloat32Array, t0: float, dur: float, freq: float, amp: float, kind: String) -> void:
	var n := int(dur * RATE)
	var start := int(t0 * RATE)
	var size := buf.size()
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := 0.0
		var s := 0.0
		match kind:
			"pad":  # ataque y caída lentos, dos osciladores desafinados
				env = minf(t / 1.2, 1.0) * minf((dur - t) / 1.5, 1.0)
				s = sin(TAU * freq * t) + 0.6 * sin(TAU * freq * 1.003 * t) + 0.25 * sin(TAU * freq * 2.0 * t)
			"pluck":  # triángulo con armónicos que decae rápido
				env = exp(-t * 3.2)
				s = sin(TAU * freq * t) + 0.45 * sin(TAU * freq * 2.0 * t) * exp(-t * 6.0) + 0.2 * sin(TAU * freq * 3.0 * t) * exp(-t * 9.0)
			"bell":  # parciales inarmónicos, cola larga
				env = exp(-t * 1.1)
				s = sin(TAU * freq * t) + 0.5 * sin(TAU * freq * 2.76 * t) + 0.3 * sin(TAU * freq * 5.4 * t)
			"bass":
				env = minf(t / 0.05, 1.0) * exp(-t * 1.4)
				s = sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t)
			"kick":  # seno que cae en tono
				env = exp(-t * 9.0)
				ph += TAU * (45.0 + 90.0 * exp(-t * 28.0)) / RATE
				s = sin(ph)
			"hat":
				env = exp(-t * 45.0)
				s = randf_range(-1.0, 1.0)
			"drip":
				env = exp(-t * 18.0)
				s = sin(TAU * (freq + 500.0 * exp(-t * 40.0)) * t)
			_:
				env = 1.0
		buf[(start + i) % size] += s * env * amp

static func render_outdoor_base() -> PackedFloat32Array:
	var buf := _buffer()
	var chords := [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]]  # Am, F, C, G (semitonos sobre La)
	var pent := [0, 3, 5, 7, 10, 12, 15, 17]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for bar in 4:
		var t0 := bar * 4.0
		for st: int in chords[bar]:
			_note(buf, t0, 4.6, A * 2.0 * pow(2.0, st / 12.0), 0.07, "pad")
		_note(buf, t0, 2.0, A * pow(2.0, chords[bar][0] / 12.0), 0.16, "bass")
		_note(buf, t0 + 2.0, 2.0, A * pow(2.0, chords[bar][0] / 12.0), 0.1, "bass")
		for step in 8:  # corcheas: arpegio suave sobre la pentatónica
			if rng.randf() < 0.72:
				var deg: int = pent[rng.randi_range(0, pent.size() - 1)]
				_note(buf, t0 + step * 0.5, 1.4, A * 2.0 * pow(2.0, deg / 12.0), 0.07, "pluck")
	return buf

static func render_outdoor_ambience() -> PackedFloat32Array:  # viento (ruido filtrado) y algún pájaro
	var buf := _buffer()
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in buf.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		buf[i] = lp * (0.35 + 0.25 * sin(TAU * t / LOOP * 2.0)) * 0.5
	for k in 5:
		var t0 := rng.randf_range(0.5, LOOP - 1.0)
		var f := rng.randf_range(2200.0, 3400.0)
		for c in 2:
			_note(buf, t0 + c * 0.13, 0.12, f * (1.0 + 0.15 * c), 0.04, "drip")
	return buf

static func render_dungeon_base() -> PackedFloat32Array:
	var buf := _buffer()
	for f: float in [A * 0.5, A * 0.75, A * 1.0]:  # zumbido grave (La, Mi, La)
		for k in 4:
			_note(buf, k * 4.0, 4.6, f, 0.09, "pad")
	_note(buf, 0.0, 4.6, A * 2.0 * pow(2.0, 1.0 / 12.0), 0.025, "pad")  # sib: tensión
	_note(buf, 8.0, 4.6, A * 2.0 * pow(2.0, 1.0 / 12.0), 0.025, "pad")
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for k in 5:  # campanas lejanas, escasas
		var deg: int = [0, 3, 7, 10, 12][rng.randi_range(0, 4)]
		_note(buf, rng.randf_range(0.5, LOOP - 3.0), 3.5, A * 4.0 * pow(2.0, deg / 12.0), 0.05, "bell")
	return buf

static func render_dungeon_ambience() -> PackedFloat32Array:  # rumor de roca y goteo
	var buf := _buffer()
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in buf.size():
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.006
		buf[i] = lp * 0.6
	for k in 7:
		_note(buf, rng.randf_range(0.5, LOOP - 1.0), 0.3, rng.randf_range(900.0, 1500.0), 0.12, "drip")
	return buf

static func render_combat(heavy: bool) -> PackedFloat32Array:  # capa de percusión: sola no suena a música, se suma a la base
	var buf := _buffer()
	var beats := int(LOOP * 2.0)  # corcheas a 60 bpm... una cada 0.5 s
	for b in beats:
		var t := b * 0.5
		if b % 2 == 0:
			_note(buf, t, 0.35, 0.0, 0.5 if heavy else 0.35, "kick")
		if heavy and b % 4 == 2:
			_note(buf, t, 0.35, 0.0, 0.3, "kick")
		_note(buf, t + 0.25, 0.08, 0.0, 0.05 if heavy else 0.035, "hat")
	return buf
