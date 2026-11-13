extends Node
# Reloj del mundo: un día dura DAY_SECONDS reales, con noche y lluvia aleatoria por día.
# Lo leen la pesca (peces nocturnos/de lluvia), el acuario y las nasas (producción por hora) y combat.gd (tinte del ambiente exterior).

const DAY_SECONDS := 480.0
const START_HOUR := 9.0
const RAIN_CHANCE := 0.25
# hora -> color del ambiente exterior (se interpola entre claves)
const KEYS := [[0.0, Color(0.38, 0.42, 0.7)], [5.0, Color(0.42, 0.45, 0.72)], [7.0, Color(1.0, 0.82, 0.7)], [9.0, Color(0.93, 0.92, 1.0)],
	[17.0, Color(0.93, 0.92, 1.0)], [19.0, Color(1.0, 0.68, 0.5)], [21.0, Color(0.4, 0.42, 0.7)], [24.0, Color(0.38, 0.42, 0.7)]]

var hour := START_HOUR
var day := 1
var rain := false
var outdoors := true       # false en casas, mina y dungeon: no llueve ni oscurece
var total := 0.0           # horas de juego acumuladas (nasas y acuario)
var rng := RandomNumberGenerator.new()
var overlay: Control
var drops: Array = []      # [x, y, velocidad] en 0..1

signal new_day

func _ready() -> void:
	rng.randomize()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	overlay = _Rain.new()
	overlay.clock = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	for i in 140:
		drops.append([rng.randf(), rng.randf(), rng.randf_range(0.8, 1.4)])

func _process(delta: float) -> void:
	advance(delta)
	if rain and outdoors:
		for d: Array in drops:
			d[1] += delta * 1.6 * d[2]
			d[0] -= delta * 0.18 * d[2]
			if d[1] > 1.0:
				d[1] = 0.0
				d[0] = rng.randf() + 0.15
		overlay.queue_redraw()
	elif overlay.visible:
		overlay.queue_redraw()

func advance(seconds: float) -> void:
	var h := seconds / DAY_SECONDS * 24.0
	total += h
	hour += h
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		rain = rng.randf() < RAIN_CHANCE
		new_day.emit()

func sleep_until(h: float) -> void:  # dormir: salta hasta la hora h (del mismo día o del siguiente)
	advance(fposmod(h - hour, 24.0) / 24.0 * DAY_SECONDS)

func dark() -> float:  # 0 de día, 1 de noche cerrada; con rampas al atardecer y al amanecer. La lluvia oscurece un poco
	var d := 0.0
	if hour >= 20.5 or hour < 5.0:
		d = 1.0
	elif hour >= 18.0:
		d = (hour - 18.0) / 2.5
	elif hour < 7.0:
		d = 1.0 - (hour - 5.0) / 2.0
	return maxf(d, 0.4 if rain else 0.0)

func shadow() -> Dictionary:  # sombra del héroe: el sol la alarga y la inclina al amanecer y al atardecer; la luna la deja corta y tenue
	var a := (clampf(hour, 6.0, 18.0) - 6.0) / 12.0 * PI
	var d := dark()
	return {"dx": lerpf(-cos(a) * 0.9, 0.35, d), "len": lerpf(1.0 + absf(cos(a)) * 1.3, 1.1, d), "alpha": lerpf(1.0, 0.4, d)}

func is_night() -> bool:
	return hour < 6.0 or hour >= 20.0

func text() -> String:
	return "Día %d  %02d:%02d%s" % [day, int(hour), int(fmod(hour, 1.0) * 60.0), "  · lluvia" if rain else ""]

func tint() -> Color:  # color de ambiente exterior a esta hora; la lluvia lo apaga un poco
	var c: Color = KEYS[-1][1]
	for i in range(1, KEYS.size()):
		if hour <= float(KEYS[i][0]):
			var a: Array = KEYS[i - 1]
			var b: Array = KEYS[i]
			c = (a[1] as Color).lerp(b[1], (hour - float(a[0])) / (float(b[0]) - float(a[0])))
			break
	return c.lerp(Color(0.55, 0.58, 0.68), 0.35) if rain else c

func to_dict() -> Dictionary:
	return {"hour": hour, "day": day, "rain": rain, "total": total}

func from_dict(d: Dictionary) -> void:  # validado: datos de disco
	hour = clampf(float(d.get("hour", START_HOUR)), 0.0, 23.99)
	day = maxi(1, int(d.get("day", 1)))
	rain = bool(d.get("rain", false))
	total = maxf(0.0, float(d.get("total", 0.0)))

class _Rain extends Control:
	var clock: Node

	func _draw() -> void:
		if clock == null or not clock.rain or not clock.outdoors:
			return
		var s := get_viewport_rect().size
		for d: Array in clock.drops:
			var p := Vector2(d[0] * s.x, d[1] * s.y)
			draw_line(p, p + Vector2(-5, 16), Color(0.75, 0.85, 1.0, 0.45), 1.5)
