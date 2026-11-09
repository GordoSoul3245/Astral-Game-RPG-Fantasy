extends Node2D
# Puerta interactuable: [E] cerca de ella la usa. Si está bloqueada muestra `lock_text` y no hace nada
# (la dungeon la bloqueará hasta matar a todos los monstruos del piso).
# Con draw_door = false solo es una zona de uso (la puerta ya está dibujada en un sprite, p. ej. el castillo).

var main: Node
var tile := Vector2.ZERO        # casilla donde está la puerta
var reach := 1.8                # distancia máxima del héroe en casillas
var label := "Abrir puerta"
var locked := false
var lock_text := "Bloqueada"
var draw_door := true
var on_open: Callable
var open_t := 0.0               # 0 cerrada .. 1 abierta (anima el dibujo)
var frames: Array[Texture2D] = []
const FEET := Vector2(116, 161.7)   # centro del marco a ras de suelo dentro del sprite de 224 px
var busy := false

func _ready() -> void:
	var g: Vector2 = main.tile_to_ground(tile)
	position = g * main.SCALE
	z_index = int(g.y)

func use() -> void:
	if busy:
		return
	if locked:
		main.say(lock_text)
		return
	busy = true
	if draw_door:
		create_tween().tween_property(self, "open_t", 1.0, 0.4)
	await get_tree().create_timer(0.4).timeout
	busy = false
	on_open.call()

func _process(_delta: float) -> void:
	if draw_door:
		queue_redraw()

func _draw() -> void:
	if not draw_door:
		return
	if frames.is_empty():
		for i in 6:
			frames.append(load("res://art/door/door_open_%02d.png" % i))
	var s: float = main.SCALE
	draw_set_transform(-FEET * s, 0.0, Vector2.ONE * s)  # sprite de Blender girado para que su borde inferior siga el borde del suelo
	draw_texture(frames[clampi(int(open_t * 5.999), 0, 5)], Vector2.ZERO)
	if locked:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * s)
		draw_circle(Vector2(0, -122), 4.0, Color("#c0392b"))  # luz roja sobre el dintel
