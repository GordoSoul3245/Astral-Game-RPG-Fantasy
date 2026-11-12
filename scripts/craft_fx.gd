extends Control
# Escenario animado de un oficio (se dibuja por código): forja (martillo, chispas y brillo), cocina (llamas, olla y vapor)
# y manos (piezas que convergen). Al terminar, el objeto salta con un anillo de luz. Lo usa craft_panel.gd.

var main: Node
var station := "hand"
var icon_tex: Texture2D
var t := 0.0          # segundos desde que empezó el oficio
var length := 1.0
var running := false
var done_age := -1.0  # >= 0 mientras suena el destello final
var idle_t := 0.0

func start(secs: float) -> void:
	running = true
	length = secs
	t = 0.0
	done_age = -1.0

func finish(ok: bool) -> void:
	running = false
	done_age = 0.0 if ok else -1.0

func _process(delta: float) -> void:
	idle_t += delta
	if done_age >= 0.0:
		done_age += delta
		if done_age > 1.2:
			done_age = -1.0
	queue_redraw()

func _rnd(a: float, b: float) -> float:  # ruido determinista en 0..1
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)

func _draw() -> void:
	var sz := size
	var c := Vector2(sz.x * 0.5, sz.y * 0.55)
	var tint: Color = {"forge": Color(0.28, 0.12, 0.05), "cook": Color(0.22, 0.12, 0.06), "hand": Color(0.1, 0.13, 0.22)}.get(station, Color(0.1, 0.1, 0.15))
	draw_rect(Rect2(Vector2.ZERO, sz), tint.darkened(0.3))
	draw_circle(c, sz.y * 0.55, Color(tint.r + 0.25, tint.g + 0.12, tint.b + 0.05, 0.25 + (0.15 * sin(idle_t * 4.0) if running else 0.0)))
	var p := clampf(t / length, 0.0, 1.0) if running else 0.0
	match station:
		"forge":
			_draw_forge(c, p)
		"cook":
			_draw_cook(c, p)
		_:
			_draw_hand(c, p)
	_draw_item(c, p)
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.5, 0.4, 0.2, 0.9), false, 2.0)

func _draw_item(c: Vector2, p: float) -> void:
	if icon_tex == null:
		return
	var s := 84.0
	var pos := c + Vector2(0, -34)
	var a := 1.0
	if running:
		var k := clampf((p - 0.55) / 0.45, 0.0, 1.0)  # el objeto aparece en el último tramo
		s *= lerpf(0.4, 1.0, k)
		a = k
	elif done_age >= 0.0:
		s *= 1.0 + 0.35 * sin(minf(done_age * 5.0, PI)) * (1.0 - done_age / 1.2)
		pos.y -= sin(minf(done_age * 4.0, PI)) * 14.0
	else:
		pos.y += sin(idle_t * 2.0) * 3.0
		a = 0.9
	draw_texture_rect(icon_tex, Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))
	if done_age >= 0.0:
		var k := done_age / 1.2
		draw_arc(pos, 20.0 + k * 90.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, 1.0 - k), 4.0)
		for i in 10:
			var ang := float(i) / 10.0 * TAU + _rnd(float(i), 3.0)
			var d := 20.0 + k * (60.0 + _rnd(float(i), 5.0) * 50.0)
			draw_rect(Rect2(pos + Vector2.from_angle(ang) * d - Vector2(3, 3), Vector2(6, 6)), Color(1.0, 0.9, 0.5, 1.0 - k))

func _draw_forge(c: Vector2, p: float) -> void:
	var base := c + Vector2(0, 52)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-70, 0), base + Vector2(70, 0), base + Vector2(54, -16), base + Vector2(30, -20),
		base + Vector2(30, -36), base + Vector2(-60, -36), base + Vector2(-78, -28), base + Vector2(-40, -20), base + Vector2(-30, -16)]), Color(0.22, 0.23, 0.28))
	draw_rect(Rect2(base + Vector2(-26, -40), Vector2(70, 6)), Color(0.4, 0.42, 0.5))   # cara de golpe
	var hit_at := base + Vector2(0, -42)
	if running:
		var cycle := 0.4
		var ph := fposmod(t, cycle) / cycle
		var ang: float = -1.2 * (1.0 - pow(ph / 0.7, 2.0)) if ph < 0.7 else 0.0  # el martillo sube lento y cae rápido
		var hand := hit_at + Vector2(46, -34)
		var head := hit_at + Vector2(10, -6) + Vector2.from_angle(ang - 1.2) * 38.0
		draw_line(hand + Vector2(30, 6), head, Color(0.5, 0.3, 0.12), 6.0)       # mango
		draw_rect(Rect2(head - Vector2(14, 9), Vector2(28, 18)), Color(0.5, 0.52, 0.6))  # cabeza del martillo
		var k0 := int(t / cycle)
		for k in [k0, k0 - 1]:
			if k < 0:
				continue
			var age: float = t - (float(k) * cycle + cycle * 0.7)
			if age < 0.0 or age > 0.5:
				continue
			for i in 12:
				var a2 := -PI * (0.1 + 0.8 * _rnd(float(k), float(i)))
				var v := Vector2.from_angle(a2) * (90.0 + 140.0 * _rnd(float(i), float(k)))
				var sp := hit_at + v * age + Vector2(0, 420.0 * age * age)
				draw_rect(Rect2(sp - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.75 - age, 0.2, 1.0 - age * 2.0))
		draw_circle(hit_at, 16.0 + 8.0 * sin(t * 30.0), Color(1.0, 0.5, 0.1, 0.25))
	else:
		draw_line(hit_at + Vector2(46, -30), hit_at + Vector2(14, -8), Color(0.5, 0.3, 0.12), 6.0)
		draw_rect(Rect2(hit_at + Vector2(0, -16), Vector2(28, 18)), Color(0.5, 0.52, 0.6))

func _draw_cook(c: Vector2, p: float) -> void:
	var base := c + Vector2(0, 54)
	for i in 5:  # llamas bajo la olla
		var x := -52.0 + i * 26.0
		var h := 22.0 + 12.0 * sin(idle_t * 9.0 + i * 1.7) + (10.0 if running else 0.0)
		draw_colored_polygon(PackedVector2Array([base + Vector2(x - 11, 0), base + Vector2(x, -h), base + Vector2(x + 11, 0)]), Color(1.0, 0.45 + 0.1 * float(i % 3), 0.1, 0.9))
		draw_colored_polygon(PackedVector2Array([base + Vector2(x - 5, 0), base + Vector2(x, -h * 0.6), base + Vector2(x + 5, 0)]), Color(1.0, 0.85, 0.3, 0.9))
	var pot := base + Vector2(0, -38)
	draw_rect(Rect2(pot + Vector2(-56, -16), Vector2(112, 44)), Color(0.18, 0.18, 0.22))
	draw_rect(Rect2(pot + Vector2(-62, -20), Vector2(124, 8)), Color(0.28, 0.28, 0.34))
	draw_rect(Rect2(pot + Vector2(-50, -12), Vector2(100, 10)), Color(0.7, 0.35, 0.12) if running else Color(0.35, 0.2, 0.1))  # caldo
	if running:
		for i in 7:  # vapor y burbujas que suben
			var ph := fposmod(t * 0.9 + _rnd(float(i), 1.0), 1.0)
			var x2 := pot.x + (_rnd(float(i), 2.0) - 0.5) * 80.0 + sin(ph * 6.0 + i) * 6.0
			draw_circle(Vector2(x2, pot.y - 20.0 - ph * 70.0), 4.0 + ph * 8.0, Color(1, 1, 1, 0.35 * (1.0 - ph)))

func _draw_hand(c: Vector2, p: float) -> void:
	if not running:
		return
	for i in 8:  # piezas que convergen en el centro
		var ang := float(i) / 8.0 * TAU + _rnd(float(i), 1.0)
		var d := (1.0 - p) * (110.0 + 40.0 * _rnd(float(i), 4.0))
		var pos := c + Vector2(0, -34) + Vector2.from_angle(ang + p * 3.0) * d
		draw_rect(Rect2(pos - Vector2(5, 5), Vector2(10, 10)), Color(0.8, 0.85, 1.0, 0.4 + 0.5 * p))
