extends Node2D
# Estela del tajo: un arco luminoso que barre de lado a lado, centrado en el ángulo de apuntado, y se desvanece.

const SEGMENTS := 16
const TAIL := 0.6     # fracción del arco que forma la cola

var center := Vector2.ZERO   # px de pantalla (mundo)
var aim := 0.0               # ángulo hacia donde apunta el tajo, cualquiera (no solo 8 direcciones)
var arc := deg_to_rad(110.0)
var radius := 150.0
var color := Color.WHITE
var duration := 0.16
var flip := 1.0              # sentido del barrido; alterna entre tajos ligeros
var t := 0.0
var anchor: Node2D
var heavy := false
var last_anchor := Vector2.ZERO

func _ready() -> void:
	if is_instance_valid(anchor):
		last_anchor = anchor.position
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # brillo aditivo

func _process(delta: float) -> void:
	if is_instance_valid(anchor) and t < duration:
		center += anchor.position - last_anchor
		last_anchor = anchor.position
	t += delta
	if t > duration * 2.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var half := arc / 2.0
	var head := half
	var tail: float
	var alpha := 1.0
	if t <= duration:
		var p := t / duration
		head = lerpf(-half, half, 1.0 - pow(1.0 - p, 2.0))  # arranca rápido, frena al final
		tail = maxf(-half, head - arc * TAIL)
	else:  # terminó el barrido: la cola alcanza a la cabeza mientras se apaga
		var q := (t - duration) / duration
		tail = lerpf(half - arc * TAIL, half, q)
		alpha = 1.0 - q
	if head - tail < 0.001:
		return
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var cols := PackedColorArray()
	for i in SEGMENTS + 1:
		var u := float(i) / SEGMENTS
		var a := aim + flip * lerpf(tail, head, u)
		var d := Vector2.from_angle(a)
		var w := radius * (0.19 if heavy else 0.1) * sin(u * PI * 0.9)
		outer.append(center + d * (radius + w * 0.35))
		inner.append(center + d * (radius - w * 0.65))
		var c := color.lerp(Color.WHITE, u * u * 0.45)  # la punta se aclara sin perder el color
		c.a = pow(u, 1.5) * alpha
		cols.append(c)
	for i in SEGMENTS:
		draw_polygon(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]),
			PackedColorArray([cols[i], cols[i + 1], cols[i + 1], cols[i]]))
	# destello en la punta de la hoja
	var tip := center + Vector2.from_angle(aim + flip * head) * radius
	var pixel_tip := tip.snapped(Vector2(3, 3))
	draw_rect(Rect2(pixel_tip - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, alpha))
