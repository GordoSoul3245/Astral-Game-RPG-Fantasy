extends CanvasLayer
# Controles táctiles (solo Android/iOS): joystick flotante a la izquierda y botones a la derecha.
# main.gd lee `stick`, `sprint`, `held` y `locked`; aquí no se toca la lógica del juego.
#
# Ayuda de apuntado:
#  - Tocar un enemigo lo fija como objetivo (aro rojo). Tocar el suelo vacío lo suelta.
#  - Sin objetivo fijado, apunta solo al enemigo más cómodo (cerca y con poca vida; aro amarillo).
#  - Apuntando el meteoro, tocar el suelo coloca el marcador ahí.

var main: Node
var stick := Vector2.ZERO          # dirección de movimiento, longitud 0..1
var sprint := false                # correr: se activa/desactiva con un toque y se apaga al soltar el joystick
var held := {MOUSE_BUTTON_LEFT: false, MOUSE_BUTTON_RIGHT: false}  # equivale a mantener clic izq./der.
var aim_point := Vector2.ZERO      # punto de apuntado del meteoro, relativo al pecho (px de suelo)
var locked: Node = null            # enemigo fijado con un toque
var interact_held := false        # USAR mantenido: sigue recolectando

const STICK_R := 130.0
const AIM_SPEED := 160.0
const AIM_MAX := 420.0
const TAP_MAX_MOVE := 26.0
const TAP_MAX_MS := 280

var _draw_node: Control
var _marker: Node2D
var _marker_target: Node = null
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _btn_touch := {}               # id de dedo -> nombre de botón
var _taps := {}                    # id de dedo -> [posición inicial, ms de inicio]
var _was_aiming := false
var _sprint_idle := 0.0
var _u := 1.0                      # escala de la interfaz según el alto de pantalla
var _buttons := {}                 # nombre -> {c: Vector2, r: float, label: String}

func _ready() -> void:
	layer = 55  # sobre el HUD, bajo el inventario (60)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = Control.new()
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)
	_marker = Node2D.new()
	_marker.z_index = 4000
	_marker.draw.connect(_on_marker_draw)
	main.add_child(_marker)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	_u = clampf(s.y / 1080.0, 0.7, 1.3)
	var u := _u
	# Pulgar derecho: ATQ grande abajo a la derecha y el resto en arco a su alrededor.
	_buttons = {
		"light": {"c": Vector2(s.x - 170 * u, s.y - 180 * u), "r": 100.0 * u, "label": "ATQ"},
		"heavy": {"c": Vector2(s.x - 370 * u, s.y - 120 * u), "r": 76.0 * u, "label": "FUERTE"},
		"dash": {"c": Vector2(s.x - 385 * u, s.y - 290 * u), "r": 72.0 * u, "label": "ESQ"},
		"ult": {"c": Vector2(s.x - 190 * u, s.y - 395 * u), "r": 68.0 * u, "label": "ULT"},
		"sprint": {"c": Vector2(s.x - 560 * u, s.y - 140 * u), "r": 54.0 * u, "label": "CORRER"},
		"interact": {"c": Vector2(s.x - 560 * u, s.y - 270 * u), "r": 58.0 * u, "label": "USAR"},
	}
	_buttons["potion"] = {"c": Vector2(s.x - 330 * u, s.y - 460 * u), "r": 52.0 * u, "label": "POCIÓN"}
	# Arriba a la derecha, fuera de la zona de los pulgares: inventario y cambio de arma.
	_buttons["inv"] = {"c": Vector2(s.x - 80 * u, 70 * u), "r": 48.0 * u, "label": "INV"}
	_buttons["next"] = {"c": Vector2(s.x - 210 * u, 70 * u), "r": 48.0 * u, "label": "ARMA"}
	_buttons["menu"] = {"c": Vector2(s.x - 470 * u, 70 * u), "r": 48.0 * u, "label": "MENÚ"}
	_buttons["bait"] = {"c": Vector2(s.x - 340 * u, 70 * u), "r": 48.0 * u, "label": "CEBO"}
	_draw_node.queue_redraw()

func _button_at(p: Vector2) -> String:
	for k in _buttons:
		var b: Dictionary = _buttons[k]
		if p.distance_to(b["c"]) <= b["r"] + 12.0:
			return k
	return ""

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			var b := _button_at(t.position)
			if b != "":
				_btn_touch[t.index] = b
				_press(b)
			else:
				_taps[t.index] = [t.position, Time.get_ticks_msec()]
				if _stick_id == -1 and t.position.x < get_viewport().get_visible_rect().size.x * 0.45 \
						and not get_tree().paused:
					_stick_id = t.index
					_stick_origin = t.position
					_stick_pos = t.position
					stick = Vector2.ZERO
		else:
			if _btn_touch.has(t.index):
				_release(_btn_touch[t.index])
				_btn_touch.erase(t.index)
			if _taps.has(t.index):
				var info: Array = _taps[t.index]
				_taps.erase(t.index)
				if Time.get_ticks_msec() - int(info[1]) <= TAP_MAX_MS and t.position.distance_to(info[0]) <= TAP_MAX_MOVE:
					_tap(t.position)
			if t.index == _stick_id:
				_stick_id = -1
				stick = Vector2.ZERO
		_draw_node.queue_redraw()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if _taps.has(d.index) and d.position.distance_to(_taps[d.index][0]) > TAP_MAX_MOVE:
			_taps.erase(d.index)
		if d.index == _stick_id:
			var v: Vector2 = d.position - _stick_origin
			if v.length() > STICK_R:  # el centro sigue al dedo para no quedarse sin recorrido
				_stick_origin = d.position - v.normalized() * STICK_R
				v = v.normalized() * STICK_R
			_stick_pos = d.position
			var n := v / STICK_R
			stick = n if n.length() > 0.15 else Vector2.ZERO  # zona muerta
			_draw_node.queue_redraw()

func _tap(p: Vector2) -> void:
	if get_tree().paused or main.dying:
		return
	var world: Vector2 = main.get_canvas_transform().affine_inverse() * p
	if main.aiming:  # meteoro: el toque coloca el marcador
		aim_point = (world / main.SCALE - (main.pos - Vector2(0, 40))).limit_length(AIM_MAX)
		_buzz(10)
		return
	var best: Node = null
	var best_d := INF
	for e in main._targets():
		if not is_instance_valid(e) or not e.alive:
			continue
		var center: Vector2 = (e.pos - Vector2(0, 30)) * main.SCALE
		var reach: float = (maxf(e.radius, 14.0) + 34.0) * main.SCALE
		var dist := world.distance_to(center)
		if dist <= reach and dist < best_d:
			best_d = dist
			best = e
	if best != null:
		locked = best
		_buzz(25)
	else:
		locked = null

func _buzz(ms: int) -> void:
	Input.vibrate_handheld(ms)

func _can_act() -> bool:
	return not get_tree().paused and not main.dying and main.reaction_time <= 0.0

func _press(b: String) -> void:
	_buzz(12)
	if b == "inv":
		_send_key(KEY_I)
		return
	if b == "menu":
		_send_key(KEY_ESCAPE)  # pausa / cancelar (en el móvil no hay tecla Esc)
		return
	if not _can_act():
		return
	match b:
		"light":
			if main.aiming:
				if main.aim_valid:
					main._confirm_meteor()
			elif main._fishing():
				main.fishing.press()  # durante la pesca el toque es el clic del sedal
			else:
				held[MOUSE_BUTTON_LEFT] = true
				main._press("light")
		"heavy":
			if main.aiming:
				main._cancel_aim()
			elif main._fishing():
				main.fishing.cancel()  # recoge el sedal
			else:
				held[MOUSE_BUTTON_RIGHT] = true
				main._press("heavy")
		"dash": main._press("dash")
		"ult": main._ultimate()
		"interact":
			interact_held = true
			main._interact()
		"bait": main.cycle_bait()
		"potion": main._use_potion()
		"sprint":
			sprint = not sprint
			_sprint_idle = 0.0
		"next":
			if not main.attacking:
				main._select((main.selected + 1) % main.hotbar.size())

func _release(b: String) -> void:
	match b:
		"interact": interact_held = false
		"light": held[MOUSE_BUTTON_LEFT] = false
		"heavy": held[MOUSE_BUTTON_RIGHT] = false

func _send_key(k: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		ev.keycode = k as Key
		ev.pressed = pressed
		Input.parse_input_event(ev)

func _process(delta: float) -> void:
	if get_tree().paused:
		stick = Vector2.ZERO
	if sprint:  # correr se apaga solo si dejás de moverte
		_sprint_idle = _sprint_idle + delta if stick == Vector2.ZERO else 0.0
		if _sprint_idle > 0.5:
			sprint = false
	if main.aiming:
		if not _was_aiming:
			aim_point = main.touch_default_aim()
		aim_point = (aim_point + stick * AIM_SPEED * delta).limit_length(AIM_MAX)
	_was_aiming = main.aiming
	_marker_target = null if (main.aiming or main.dying) else main.touch_target()
	if _marker_target != null:
		_marker.position = _marker_target.pos * main.SCALE
	_marker.queue_redraw()
	_draw_node.queue_redraw()

func _on_marker_draw() -> void:
	if _marker_target == null:
		return
	var is_lock: bool = _marker_target == locked
	var col := Color(1.0, 0.25, 0.2, 0.9) if is_lock else Color(1.0, 0.85, 0.3, 0.7)
	var r: float = (maxf(_marker_target.radius, 14.0) + 6.0) * main.SCALE
	_marker.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	_marker.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, col, 5.0 if is_lock else 3.0)
	if is_lock:
		_marker.draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 40, Color(col, 0.5), 3.0)

func _on_draw() -> void:
	var ci := _draw_node
	if _stick_id != -1:
		ci.draw_circle(_stick_origin, STICK_R, Color(1, 1, 1, 0.08))
		ci.draw_arc(_stick_origin, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.3), 3.0)
		var off := _stick_pos - _stick_origin
		var knob := _stick_origin + (off.normalized() * STICK_R if off.length() > STICK_R else off)
		ci.draw_circle(knob, 52.0, Color(1, 1, 1, 0.32))
	else:
		var s := get_viewport().get_visible_rect().size
		ci.draw_arc(Vector2(200 * _u, s.y - 210 * _u), STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.14), 3.0)
	var font := ThemeDB.fallback_font
	var down := _btn_touch.values()
	for k in _buttons:
		var b: Dictionary = _buttons[k]
		var on: bool = (k in down) or (k == "sprint" and sprint)
		var fill := Color(1, 0.8, 0.3, 0.30) if (k == "sprint" and sprint) else Color(1, 1, 1, 0.30 if on else 0.12)
		ci.draw_circle(b["c"], b["r"], fill)
		ci.draw_arc(b["c"], b["r"], 0, TAU, 40, Color(1, 1, 1, 0.45), 3.0)
		var fs := 24 if b["r"] >= 60.0 else 18
		var w := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, b["c"] + Vector2(-w / 2.0, fs * 0.35), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
