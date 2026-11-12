extends Control
# Mesa de alquimia animada (se dibuja por código): un frasco sobre un quemador, los ingredientes colocados esperando sobre la mesa;
# al preparar vuelan al frasco uno a uno, el líquido sube y burbujea, y al final la poción resultante se eleva con un destello.

var main: Node
var color := Color("#e04a4a")
var placed_tex: Array[Texture2D] = []   # ingredientes sobre la mesa (en el orden en que vuelan al frasco)
var catalyst_tex: Texture2D
var catalyst_on := false
var result_tex: Texture2D
var t := 0.0
var length := 3.2
var running := false
var done_age := -1.0
var idle_t := 0.0

func start(secs: float) -> void:
	running = true
	length = secs
	t = 0.0
	done_age = -1.0

func finish() -> void:
	running = false
	done_age = 0.0

func _process(delta: float) -> void:
	idle_t += delta
	if running:
		t += delta
	if done_age >= 0.0:
		done_age += delta
		if done_age > 1.6:
			done_age = -1.0
	queue_redraw()

func _rnd(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)

func _draw() -> void:
	var sz := size
	# tablero de madera
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.2, 0.12, 0.07))
	for i in 6:
		draw_line(Vector2(0, sz.y * (0.12 + i * 0.16)), Vector2(sz.x, sz.y * (0.12 + i * 0.16)), Color(0.14, 0.08, 0.04), 2.0)
	var top := sz.y * 0.74
	draw_rect(Rect2(0, top, sz.x, sz.y - top), Color(0.3, 0.19, 0.1))
	draw_line(Vector2(0, top), Vector2(sz.x, top), Color(0.55, 0.38, 0.2), 3.0)
	var p := clampf(t / length, 0.0, 1.0) if running else (1.0 if done_age >= 0.0 else 0.0)
	var base := Vector2(sz.x * 0.5, top - 6.0)
	# quemador con llama
	draw_rect(Rect2(base + Vector2(-34, -6), Vector2(68, 10)), Color(0.18, 0.18, 0.22))
	var fh := 16.0 + (14.0 if running else 4.0) + 6.0 * sin(idle_t * 11.0)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -6), base + Vector2(0, -6 - fh), base + Vector2(16, -6)]), Color(1.0, 0.5, 0.12, 0.9))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-8, -6), base + Vector2(0, -6 - fh * 0.6), base + Vector2(8, -6)]), Color(1.0, 0.9, 0.4, 0.9))
	# frasco: panza + cuello; el líquido sube con el progreso
	var fc := base + Vector2(0, -84)
	var r := 46.0
	var fl := PackedVector2Array()
	for i in 25:
		var a := PI * 0.5 + 0.5 + (TAU - 1.0) * float(i) / 24.0
		fl.append(fc + Vector2(cos(a), sin(a)) * r)
	fl.append(fc + Vector2(14, -r * 0.8))
	fl.append(fc + Vector2(14, -r * 1.35))
	fl.append(fc + Vector2(-14, -r * 1.35))
	fl.append(fc + Vector2(-14, -r * 0.8))
	var level := lerpf(0.12, 0.92, p) if (running or done_age >= 0.0) else 0.12
	var surf := fc.y + (r - 3.0) * (1.0 - 2.0 * level)  # y de la superficie
	var liq2 := PackedVector2Array()
	for i in 41:
		var a := float(i) / 40.0 * TAU
		var pt := fc + Vector2(cos(a), sin(a)) * (r - 3.0)
		if pt.y >= surf:
			liq2.append(pt)
	if liq2.size() > 2:
		var lc := color
		lc.a = 0.85
		var wob := sin(idle_t * 7.0) * (1.5 + (3.0 if running else 0.0))
		liq2.append(Vector2(fc.x - r + 3.0, surf + wob))
		draw_colored_polygon(liq2, lc)
	draw_polyline(fl + PackedVector2Array([fl[0]]), Color(0.85, 0.95, 1.0, 0.9), 3.0)
	draw_line(fc + Vector2(-18, -r * 1.35), fc + Vector2(18, -r * 1.35), Color(0.85, 0.95, 1.0), 4.0)
	draw_arc(fc + Vector2(-r * 0.5, -r * 0.1), r * 0.55, PI * 1.15, PI * 1.6, 8, Color(1, 1, 1, 0.5), 3.0)
	# burbujas y vapor mientras se prepara
	if running:
		for i in 9:
			var ph := fposmod(t * 1.1 + _rnd(float(i), 1.0), 1.0)
			draw_circle(Vector2(fc.x + (_rnd(float(i), 2.0) - 0.5) * r * 1.3, fc.y + r * 0.6 - ph * r * 1.6), 3.0 + _rnd(float(i), 3.0) * 4.0, Color(1, 1, 1, 0.5 * (1.0 - ph)))
		for i in 4:
			var ph2 := fposmod(t * 0.7 + float(i) * 0.25, 1.0)
			draw_circle(Vector2(fc.x + sin(ph2 * 8.0 + i) * 10.0, fc.y - r * 1.4 - ph2 * 60.0), 6.0 + ph2 * 14.0, Color(color.r, color.g, color.b, 0.25 * (1.0 - ph2)))
	# ingredientes: esperan sobre la mesa y vuelan al frasco durante la preparación
	var all: Array[Texture2D] = placed_tex.duplicate()
	if catalyst_on and catalyst_tex:
		all.append(catalyst_tex)
	for i in all.size():
		var rest := Vector2(sz.x * (0.14 + 0.72 * (float(i) + 0.5) / maxf(1.0, all.size())), top + 26.0)
		var pos := rest
		var a := 1.0
		if running or done_age >= 0.0:
			var start_t := 0.12 + 0.5 * float(i) / maxf(1.0, all.size())
			var k := clampf((p - start_t) / 0.25, 0.0, 1.0)
			var ease_k := k * k * (3.0 - 2.0 * k)
			var mid := (rest + fc) * 0.5 + Vector2(0, -70)
			pos = rest.lerp(mid, ease_k).lerp(fc + Vector2(0, -r * 1.0), ease_k * ease_k)
			a = 1.0 - clampf((k - 0.85) / 0.15, 0.0, 1.0)
			if k >= 1.0:
				a = 0.0
		draw_texture_rect(all[i], Rect2(pos - Vector2(20, 20), Vector2(40, 40)), false, Color(1, 1, 1, a))
	# resultado: la poción asciende con destello
	if done_age >= 0.0 and result_tex:
		var k := done_age / 1.6
		var rp := fc + Vector2(0, -r * 0.6 - sin(minf(done_age * 2.5, PI * 0.5)) * 50.0)
		var s := 64.0 * (1.0 + 0.3 * sin(minf(done_age * 5.0, PI)))
		draw_arc(rp, 24.0 + k * 100.0, 0.0, TAU, 40, Color(color.r, color.g, color.b, 1.0 - k), 5.0)
		draw_texture_rect(result_tex, Rect2(rp - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 1.0 - clampf((k - 0.8) / 0.2, 0.0, 1.0)))
		for i in 14:
			var ang := float(i) / 14.0 * TAU + _rnd(float(i), 5.0)
			var d := 20.0 + k * (50.0 + _rnd(float(i), 7.0) * 80.0)
			draw_rect(Rect2(rp + Vector2.from_angle(ang) * d - Vector2(3, 3), Vector2(6, 6)), Color(1.0, 0.95, 0.6, 1.0 - k))
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.55, 0.38, 0.2), false, 3.0)
