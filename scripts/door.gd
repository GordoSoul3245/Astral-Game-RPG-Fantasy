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
var design := "standard"
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
	await get_tree().create_timer(0.4, false).timeout
	busy = false
	on_open.call()

func _process(_delta: float) -> void:
	if draw_door:
		queue_redraw()

func _draw() -> void:
	if not draw_door:
		return
	if design == "house":
		_draw_house()
		return
	if frames.is_empty():
		for i in 6:
			frames.append(load("res://art/door/%s_open_%02d.png" % ["dungeon" if design == "dungeon" else "door",i]))
	var s: float = main.SCALE
	draw_set_transform(-FEET * s, 0.0, Vector2.ONE * s)  # sprite de Blender girado para que su borde inferior siga el borde del suelo
	draw_texture(frames[clampi(int(open_t * 5.999), 0, 5)], Vector2.ZERO)
	if locked:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * s)
		draw_circle(Vector2(0, -122), 4.0, Color("#c0392b"))  # luz roja sobre el dintel

func _draw_house() -> void:
	# La horizontal del marco va sobre la pared j=0. Los postes siguen verticales.
	var along: Vector2 = main.E1 / main.TILES
	var s: float = main.SCALE
	draw_set_transform_matrix(Transform2D(along*s/32.0,Vector2.DOWN*s,Vector2.ZERO))
	draw_rect(Rect2(-32,-70,64,71),Color("#503627"))
	draw_rect(Rect2(-27,-64,54,64),Color("#221d26"))
	var width := 52.0*(1.0-open_t*0.92)
	draw_rect(Rect2(-26,-63,width,62),Color("#995e38"))
	for i in range(1,5):
		var x := -26+width*i/5.0
		draw_line(Vector2(x,-60),Vector2(x,-2),Color("#734629"),1.4)
	for y in [-52,-14]:
		draw_rect(Rect2(-26,y,width*0.44,3),Color("#53453b"))
	draw_circle(Vector2(-26+width*0.83,-31),2.8,Color("#e5bd73"))
	draw_rect(Rect2(-34,-73,68,5),Color("#c0915e"))
	draw_rect(Rect2(-33,-2,66,3),Color("#bd986e"))
