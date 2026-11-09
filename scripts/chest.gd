extends Node2D
# Cofre de recompensa (dibujado por código, arte provisional). La puerta invisible de su casilla lo abre con [E].

var main: Node
var tile := Vector2.ZERO
var open_t := 0.0   # 0 cerrado .. 1 abierto
var t := 0.0
var frames: Array[Texture2D] = []
const FEET := Vector2(68, 113.7)

func _ready() -> void:
	var g: Vector2 = main.tile_to_ground(tile)
	position = g * main.SCALE
	z_index = int(g.y)

func open() -> void:
	create_tween().tween_property(self, "open_t", 1.0, 0.5)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * main.SCALE)
	if open_t < 1.0:  # resplandor dorado mientras está cerrado
		draw_circle(Vector2(0, -10), 26.0 + 3.0 * sin(t * 4.0), Color(1.0, 0.8, 0.3, 0.12 * (1.0 - open_t)))
	if frames.is_empty():
		for i in 6:
			frames.append(load("res://art/chest/chest_open_%02d.png" % i))
	draw_set_transform(-FEET * main.SCALE, 0.0, Vector2.ONE * main.SCALE)  # sprite de Blender girado con la cuadrícula
	draw_texture(frames[clampi(int(open_t * 5.999), 0, 5)], Vector2.ZERO)
