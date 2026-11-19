extends Node2D
# El viejo gaucho de la fogata: junto al fuego, con su tronco al lado. Nadie sabe quién es; acompañará y guiará al héroe por la
# historia. Al hablarle canta en payada tranquila, tirando a lo filosófico. Sprite: art/gaucho/gaucho_idle_<DIR>.png (8 direcciones,
# origen en los pies como el héroe); mira hacia el héroe cuando se acerca y hacia el fuego si no. Notas que suben de vez en cuando.

var main: Node
var fire_tile := Vector2.ZERO
var seat_tile := Vector2.ZERO
var t := 0.0
var talks := 0
var door: Node2D
var fire: Sprite2D
var fire_frames: Array[Texture2D] = []
var man: Sprite2D
var facing := ""
var ground := Vector2.ZERO
var fire_g := Vector2.ZERO  # la fogata en suelo (fija: no depende de la región en la que esté el héroe)
var following := false   # tras la última copla anda al lado del héroe (shortcut: solo dentro de la zona; cruzar regiones pide un acompañante en main)

const FEET := Vector2(68, 113.7)   # los pies dentro del sprite de 128 px (misma cámara que el héroe)

const COPLAS := [
	["(Templa la guitarra sin apuro y te mira desde abajo del ala del sombrero)",
	"Buenas noches, caminante,\nque el fogón le dé reparo;\nno pregunte por mi nombre,\nque hace rato lo he olvidado.",
	"Yo soy viejo como el monte\ny callado como el río;\nlo que sé lo fui aprendiendo\nde la escarcha y del rocío.",
	"El camino que lo trajo\nno lo empieza ni termina:\nes la huella del que anda\ncon la duda por madrina."],
	["Si sigue la huella al norte,\nhay un pueblo con su gente;\nallí el pan se gana lento\ny el saludo es de frente.",
	"Y a la izquierda, mansamente,\nduerme un lago entre los pinos:\nquien le tira la carnada\nva aprendiendo de destinos.",
	"Que no es el pez lo que importa,\nes la espera y su paciencia;\nel que sabe quedarse quieto\nya camina con conciencia."],
	["Yo voy a andar a su lado\ncomo sombra de guitarra;\ncuando el miedo le haga noche,\nle prendo una copla clara.",
	"No me pregunte el porqué,\nni el dónde, ni el hasta cuándo:\nhay preguntas que se aprenden\nsolamente caminando."],
]

func _ready() -> void:
	var fg: Vector2 = main.tile_to_ground(fire_tile)
	fire_g = fg
	for k in 4:
		fire_frames.append(load("res://art/map/campfire_%d.png" % k))
	fire = Sprite2D.new()
	fire.texture = fire_frames[0]
	fire.scale = Vector2.ONE * main.SCALE
	fire.offset = Vector2(0, -fire.texture.get_height() * 0.36)
	fire.position = fg * main.SCALE
	fire.z_index = int(fg.y)
	add_child(fire)
	# humo: una columna alta que se ve desde el inicio de la partida y guía hasta la fogata (por encima de las copas)
	var smoke := CPUParticles2D.new()
	smoke.position = (fg - Vector2(0, 12)) * main.SCALE
	smoke.z_index = 3900
	smoke.amount = 40
	smoke.lifetime = 6.0
	smoke.preprocess = 6.0
	smoke.local_coords = false
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(6, 2)
	smoke.direction = Vector2(0, -1)
	smoke.spread = 8.0
	smoke.gravity = Vector2(Wind.DIR.x * 6.0, 0)  # la columna se inclina con el viento del mundo
	smoke.initial_velocity_min = 55.0
	smoke.initial_velocity_max = 75.0
	smoke.scale_amount_min = 18.0  # bocanadas cuadradas de humo, en la rejilla de 3 px
	smoke.scale_amount_max = 27.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(1, 1.8))
	smoke.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.75, 0.72, 0.68, 0.0))
	ramp.add_point(0.12, Color(0.72, 0.7, 0.66, 0.6))
	ramp.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	smoke.color_ramp = ramp
	add_child(smoke)
	var l: PointLight2D = main.combat.light(Color(1.0, 0.62, 0.3), 0.9, 2.6)
	l.position = (fg - Vector2(0, 10)) * main.SCALE
	add_child(l)
	ground = main.tile_to_ground(seat_tile)
	for lg: Vector2 in [ground, main.tile_to_ground(fire_tile + Vector2(-1.4, -0.4)), main.tile_to_ground(fire_tile + Vector2(0.2, 1.3))]:
		var log_sprite := Sprite2D.new()
		log_sprite.texture = preload("res://art/map/tronco_fogon.png")
		log_sprite.position = (lg - Vector2(0, 12)) * main.SCALE
		log_sprite.scale = Vector2.ONE * main.SCALE
		log_sprite.z_index = int(lg.y) - 1
		add_child(log_sprite)
	man = Sprite2D.new()
	man.centered = false
	man.scale = Vector2.ONE * main.SCALE
	man.position = (ground - FEET) * main.SCALE
	man.z_index = int(ground.y)
	add_child(man)
	_face(fg - ground)
	door = main._add_door(seat_tile + Vector2(0.6, 0.6), "Hablar con el viejo", _talk, false)
	door.reach = 1.8

func _face(dir: Vector2) -> void:  # una de las 8 direcciones del proyecto (E, SE, S, SW, W, NW, N, NE)
	var f: String = main.DIRS[posmod(roundi(dir.angle() / (PI / 4.0)), 8)]
	if not following:
		if facing != "sentado":
			facing = "sentado"
			man.texture = preload("res://art/gaucho/gaucho_sentado.png")
		return
	if f != facing:
		facing = f
		man.texture = load("res://art/gaucho/gaucho_idle_%s.png" % f)

func _exit_tree() -> void:
	if is_instance_valid(door):
		main.doors.erase(door)
		door.queue_free()

func _talk() -> void:
	main.dialogue.open("El viejo", COPLAS[mini(talks, COPLAS.size() - 1)])
	talks += 1
	following = following or talks >= COPLAS.size()

func _process(delta: float) -> void:
	t += delta
	fire.texture = fire_frames[int(t * 8.0) % 4]
	var to_hero: Vector2 = main.pos - ground
	if following and to_hero.length() > 45.0:  # camina detrás sin pisarle los talones
		ground += to_hero.normalized() * minf(70.0 * delta, to_hero.length() - 45.0)
		door.tile = main.ground_to_tile(ground)
		man.z_index = int(ground.y)
		_face(to_hero)
	else:
		_face(to_hero if to_hero.length() < 160.0 else fire_g - ground)
	# respiración: el sprite sube 1 px de arte (3 en pantalla) cada tanto, en la rejilla pixel art
	man.position = (ground - FEET - Vector2(0, 1.0 if fmod(t, 1.8) < 0.9 else 0.0)) * main.SCALE
	if fmod(t, 2.6) < delta:  # alguna nota de guitarra que sube
		var n := Label.new()
		n.text = "♪" if randf() < 0.5 else "♫"
		n.add_theme_font_size_override("font_size", 22)
		n.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		n.position = (ground - Vector2(10, 95)) * main.SCALE
		n.z_index = 4000
		add_child(n)
		var tw := n.create_tween().set_parallel(true)
		tw.tween_property(n, "position", n.position + Vector2(randf_range(-20, 20), -90), 2.0)
		tw.tween_property(n, "modulate:a", 0.0, 2.0)
		tw.chain().tween_callback(n.queue_free)
