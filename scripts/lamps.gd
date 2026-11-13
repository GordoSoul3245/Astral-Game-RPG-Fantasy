extends Node2D
# Farolas del pueblo (puertas de las casas y comerciantes): se encienden al anochecer o con lluvia y se apagan de día.
# Las posiciones (suelo) las pasa main._build_lamps; la luz es un PointLight2D aditivo de combat.light().
# Cada poste es su propio nodo con z = su y, para ordenarse en profundidad con el héroe y los edificios.

var main: Node
var points: Array = []
var lights: Array = []
var posts: Array = []

func _ready() -> void:
	for g: Vector2 in points:
		var post := _Post.new()
		post.main = main
		post.position = g * main.SCALE
		post.z_index = int(g.y)
		add_child(post)
		posts.append(post)
		var l: PointLight2D = main.combat.light(Color(1.0, 0.78, 0.45), 0.0, 3.0)
		l.position = (g - Vector2(0, 38)) * main.SCALE
		add_child(l)
		lights.append(l)

func _process(_delta: float) -> void:
	visible = main.clock.outdoors and not main.in_dungeon
	if not visible:
		return
	var k: float = main.clock.dark()
	var flick := 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.011)
	for l: PointLight2D in lights:
		l.energy = k * flick
	for p: Node2D in posts:
		p.k = k
		p.queue_redraw()

class _Post extends Node2D:  # poste de madera con farol; el brillo del cristal crece con la oscuridad
	var main: Node
	var k := 0.0

	func _draw() -> void:
		var sc: float = main.SCALE
		draw_line(Vector2.ZERO, Vector2(0, -34 * sc), Color(0.28, 0.18, 0.1), 2.5 * sc)
		var lamp := Rect2(Vector2(-4, -44) * sc, Vector2(8, 10) * sc)
		draw_rect(lamp, Color(0.18, 0.12, 0.08))
		draw_rect(lamp.grow(-1.5 * sc), Color(0.35, 0.3, 0.2).lerp(Color(1.0, 0.85, 0.45), k))
		if k > 0.0:
			draw_circle(Vector2(0, -39 * sc), 14 * sc, Color(1.0, 0.8, 0.4, 0.18 * k))
