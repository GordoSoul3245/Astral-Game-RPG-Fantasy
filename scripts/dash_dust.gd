extends Node2D
# Polvo en píxeles con caída y frenado, situado en el contacto con el suelo.
var direction := Vector2.RIGHT
var tint := Color("#b7a38a")
var age := 0.0
var motes: Array[Dictionary] = []

func _ready() -> void:
	for i in 9:
		var velocity := direction.rotated(randf_range(-0.9, 0.9)) * randf_range(25.0, 65.0)
		motes.append({"velocity": velocity, "lift": randf_range(12.0, 28.0), "life": randf_range(0.23, 0.4), "size": 3.0 if i % 3 else 6.0})

func _process(delta: float) -> void:
	age += delta
	if age > 0.4:
		queue_free()
	queue_redraw()

func _draw() -> void:
	for mote in motes:
		var progress: float = age / mote.life
		if progress >= 1.0:
			continue
		var offset: Vector2 = mote.velocity * age * (1.0 - progress * 0.45)
		offset.y -= sin(progress * PI) * mote.lift
		offset = offset.snapped(Vector2(3, 3))
		var shade := tint
		shade.a = 1.0 - progress
		draw_rect(Rect2(offset, Vector2.ONE * mote.size), shade)
