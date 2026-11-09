extends Node2D
# Zona de peligro: avisa en el suelo y, al terminar `delay`, golpea (onda del cíclope o rayo del jefe).

var main: Node
var center := Vector2.ZERO   # px de suelo
var radius := 40.0
var delay := 0.8
var damage := 20
var bolt := false            # true = rayo desde el cielo; false = onda de choque
var color := Color(1.0, 0.3, 0.2)
var t := 0.0
var fired := false

func _ready() -> void:
	position = center * main.SCALE
	z_index = int(center.y) + 1

func _process(delta: float) -> void:
	t += delta
	if not fired and t >= delay:
		fired = true
		var d: Vector2 = main.pos - center
		if Vector2(d.x, d.y / 0.6).length() < radius + main.HERO_RADIUS:  # el suelo está aplastado en Y por la vista isométrica
			main.damage_hero(damage)
		main.shake(10.0 if bolt else 8.0)
	if fired and t >= delay + 0.3:
		queue_free()
	queue_redraw()

func _ellipse(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(Vector2(cos(i * TAU / 32.0) * r, sin(i * TAU / 32.0) * r * 0.6))
	return pts

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * main.SCALE)
	if not fired:
		var p := clampf(t / delay, 0.0, 1.0)
		draw_colored_polygon(_ellipse(radius * p), Color(color, 0.25))  # se llena hasta el golpe
		draw_polyline(_ellipse(radius), Color(color, 0.9), 1.5)
		return
	var k := 1.0 - (t - delay) / 0.3
	draw_colored_polygon(_ellipse(radius), Color(color.lightened(0.5), 0.6 * k))
	if bolt:
		var pts := PackedVector2Array([Vector2(0, -420)])
		var rng := RandomNumberGenerator.new()
		rng.seed = int(t * 60.0)
		for i in range(1, 8):
			pts.append(Vector2(rng.randf_range(-14, 14), -420.0 + i * 60.0))
		pts.append(Vector2.ZERO)
		draw_polyline(pts, Color(0.75, 0.95, 1.0, k), 7.0)
		draw_polyline(pts, Color(1, 1, 1, k), 2.5)
