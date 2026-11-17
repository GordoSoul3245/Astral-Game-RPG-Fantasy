class_name GrassManager
extends Node
# Pasa al shader las posiciones de los personajes (grupo "grass_char", hasta 64) para que el pasto se aparte.
# Como los shaders de Godot no admiten arreglos de tamaño variable, el arreglo es fijo (64 x vec4: x, y, radio, 0)
# y las posiciones libres quedan en cero (radio 0 = sin efecto).
# Se actualiza a pocos ticks por segundo (un poco más que el viento) para el movimiento "dibujado a mano".
# Un personaje se añade con add_to_group("grass_char") y, si quiere otro radio, set_meta("grass_radius", px).

@export var tick_rate := 12.0
var _acc := 0.0

func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0 / tick_rate:
		return
	_acc = 0.0
	push_now()

func push_now() -> void:
	var arr := PackedVector4Array()
	arr.resize(64)
	var i := 0
	for n: Node in get_tree().get_nodes_in_group("grass_char"):
		if i >= 64:
			break
		var p: Vector2 = (n as Node2D).global_position
		arr[i] = Vector4(p.x, p.y, float(n.get_meta("grass_radius", 90.0)), 0.0)
		i += 1
	GrassTile.material().set_shader_parameter("chars", arr)
	GrassTile.material().set_shader_parameter("char_count", i)
