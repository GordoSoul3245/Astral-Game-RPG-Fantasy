extends RefCounted
# Sprites de Blender (art/fauna) para conejo, zorro y civil: <prefijo><DIR>_<tipo>_<NN>.png en 8 direcciones.
# Si un PNG aún no fue importado por el editor, se carga directo del disco (el editor lo importará al abrirse).

const FEET := Vector2(68.0, 113.7)  # mismo cuadro de 128 px que el héroe y el slime

static func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null

# kinds: tipo -> fotogramas (1 = pose fija). Devuelve el sprite ya colgado de `owner`, o null si falta el arte.
static func build(owner: Node2D, main: Node, prefix: String, kinds: Dictionary) -> AnimatedSprite2D:
	if not FileAccess.file_exists(ProjectSettings.globalize_path("%sS_idle_00.png" % prefix)):
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir: String in main.DIRS:
		for kind: String in kinds:
			var key := "%s_%s" % [kind, dir]
			frames.add_animation(key)
			frames.set_animation_speed(key, 10.0)
			frames.set_animation_loop(key, true)
			for i in kinds[kind]:
				frames.add_frame(key, _tex("%s%s_%s_%02d.png" % [prefix, dir, kind, i]))
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.centered = false
	spr.scale = Vector2.ONE * main.SCALE
	spr.position = -FEET * main.SCALE
	owner.add_child(spr)
	return spr

static func hitbox(main: Node, prefix: String) -> Dictionary:  # hitbox corporal medida de los 8 reposos (hitbox.gd)
	var HB := preload("res://scripts/hitbox.gd")
	return HB.measure(main.DIRS, prefix + "%s_idle_00.png", FEET)

static func show(spr: AnimatedSprite2D, main: Node, kind: String, look: Vector2, speed := 1.0) -> void:
	var dir: String = main.DIRS[posmod(roundi(look.angle() / (PI / 4.0)), 8)]
	var key := "%s_%s" % [kind, dir]
	spr.speed_scale = speed
	if spr.animation != key or not spr.is_playing():
		spr.play(key)
