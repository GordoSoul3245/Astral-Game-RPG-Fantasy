extends RefCounted

static var volume: ShaderMaterial

static func light_sprite(sprite: CanvasItem) -> void:
	if volume == null:
		volume = ShaderMaterial.new()
		volume.shader = preload("res://shaders/sprite_volume.gdshader")
	if sprite.material == null:
		sprite.material = volume

static var material: ShaderMaterial

static func add(parent: Node2D, foot: Vector2, width: float, height: float) -> Polygon2D:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = preload("res://shaders/projected_shadow.gdshader")
	var p := Polygon2D.new()
	p.position = foot
	p.z_as_relative = false
	p.z_index = -3900
	p.polygon = PackedVector2Array([Vector2(-width,-height), Vector2(width,-height), Vector2(width,height*0.12), Vector2(-width,height*0.12)])
	p.uv = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	p.material = material
	parent.add_child(p)
	return p

static func update(clock: Node) -> void:
	if material == null:
		return
	var daylight: float = 1.0 - clock.dark() if clock.outdoors else 0.0
	var shadow: Dictionary = clock.shadow()
	material.set_shader_parameter("sun", Vector2(float(shadow.dx), 0.35) * daylight)
	material.set_shader_parameter("daylight", daylight)
	for group: String in ["hearth", "gate"]:
		var source := Vector3.ZERO
		for lamp: PointLight2D in clock.get_tree().get_nodes_in_group(group):
			if clock.outdoors and lamp.is_visible_in_tree() and lamp.enabled:
				source = Vector3(lamp.global_position.x, lamp.global_position.y, lamp.texture.get_width()*lamp.texture_scale*0.5)
				break
		material.set_shader_parameter(group, source)
