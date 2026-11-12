extends Node2D
# Salpicadura de un golpe: gotas lanzadas en la dirección del tajo que suben, caen por gravedad y,
# al tocar el suelo, quedan como manchas aplastadas (2:1 isométrico) que se desvanecen.
# Coordenadas de main (pos * SCALE); `origin_h` = altura del impacto sobre el suelo.
const GRAVITY := 1400.0
const STAIN_LIFE := 1.4
var tint := Color("#9b1c24")
var dir := Vector2.RIGHT
var count := 6
var origin_h := 90.0
var drops: Array[Dictionary] = []
var age := 0.0

func _ready() -> void:
	for i in count:
		var v := dir.rotated(randf_range(-0.7, 0.7)) * randf_range(120.0, 320.0)
		drops.append({"p": Vector2.ZERO, "h": origin_h, "v": v * Vector2(1, 0.5), "vh": randf_range(80.0, 320.0),
			"size": 6.0 if i % 3 else 9.0, "landed": -1.0})

func _process(delta: float) -> void:
	age += delta
	var alive := false
	for d in drops:
		if d.landed < 0.0:
			d.p += d.v * delta
			d.vh -= GRAVITY * delta
			d.h += d.vh * delta
			if d.h <= 0.0:
				d.h = 0.0
				d.landed = age
		if d.landed < 0.0 or age - d.landed < STAIN_LIFE:
			alive = true
	if not alive:
		queue_free()
	queue_redraw()

func _draw() -> void:
	for d in drops:
		var c := tint
		if d.landed < 0.0:  # en el aire: gota estirada en su trayectoria
			var at: Vector2 = (d.p - Vector2(0, d.h)).snapped(Vector2(3, 3))
			draw_rect(Rect2(at - Vector2(d.size, d.size) * 0.5, Vector2(d.size, d.size)), c)
		else:  # en el suelo: mancha que se aplasta y se apaga
			c.a = clampf(1.0 - (age - d.landed) / STAIN_LIFE, 0.0, 1.0) * 0.85
			var s: float = d.size * 1.6
			draw_rect(Rect2(d.p.snapped(Vector2(3, 3)) - Vector2(s, s * 0.5) * 0.5, Vector2(s, s * 0.5)), c)
