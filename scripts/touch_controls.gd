extends CanvasLayer
# Controles táctiles (solo Android/iOS): joystick flotante a la izquierda y botones a la derecha.
# main.gd lee `stick`, `sprint` y `held` y llama a sus acciones; aquí no se toca la lógica del juego.

var main: Node
var stick := Vector2.ZERO          # dirección de movimiento, longitud 0..1
var sprint := false
var held := {MOUSE_BUTTON_LEFT: false, MOUSE_BUTTON_RIGHT: false}  # equivale a mantener clic izq./der.
var aim_point := Vector2.ZERO      # punto de apuntado del meteoro, relativo al pecho (px de suelo)

const STICK_R := 120.0
const AIM_SPEED := 160.0
const AIM_MAX := 420.0

var _draw_node: Control
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _btn_touch := {}               # id de dedo -> nombre de botón
var _was_aiming := false
var _buttons := {}                 # nombre -> {c: Vector2, r: float, label: String}

func _ready() -> void:
	layer = 55  # sobre el HUD, bajo el inventario (60)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = Control.new()
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	_buttons = {
		"light": {"c": Vector2(s.x - 190, s.y - 200), "r": 95.0, "label": "ATQ"},
		"heavy": {"c": Vector2(s.x - 390, s.y - 140), "r": 75.0, "label": "FUERTE"},
		"dash": {"c": Vector2(s.x - 400, s.y - 320), "r": 72.0, "label": "ESQ"},
		"ult": {"c": Vector2(s.x - 200, s.y - 410), "r": 70.0, "label": "ULT"},
		"interact": {"c": Vector2(s.x - 570, s.y - 200), "r": 62.0, "label": "USAR"},
		"sprint": {"c": Vector2(s.x - 570, s.y - 330), "r": 55.0, "label": "CORRER"},
		"potion": {"c": Vector2(s.x - 330, s.y - 470), "r": 52.0, "label": "POCIÓN"},
	}
	# botones superiores (inventario y cambio de arma), fuera de la zona de los pulgares
	_buttons.erase("spell")
	_buttons["inv"] = {"c": Vector2(s.x - 100, 70), "r": 50.0, "label": "INV"}
	_buttons["next"] = {"c": Vector2(s.x - 240, 70), "r": 50.0, "label": "ARMA"}
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
			elif _stick_id == -1 and t.position.x < get_viewport().get_visible_rect().size.x * 0.45 \
					and not get_tree().paused:
				_stick_id = t.index
				_stick_origin = t.position
				_stick_pos = t.position
				stick = Vector2.ZERO
		else:
			if _btn_touch.has(t.index):
				_release(_btn_touch[t.index])
				_btn_touch.erase(t.index)
			if t.index == _stick_id:
				_stick_id = -1
				stick = Vector2.ZERO
		_draw_node.queue_redraw()
	elif event is InputEventScreenDrag and event.index == _stick_id:
		var d: Vector2 = event.position - _stick_origin
		if d.length() > STICK_R:  # el centro sigue al dedo para no quedarse sin recorrido
			_stick_origin = event.position - d.normalized() * STICK_R
			d = d.normalized() * STICK_R
		_stick_pos = event.position
		var v := d / STICK_R
		stick = v if v.length() > 0.18 else Vector2.ZERO  # zona muerta
		_draw_node.queue_redraw()

func _can_act() -> bool:
	return not get_tree().paused and not main.dying and main.reaction_time <= 0.0

func _press(b: String) -> void:
	if b == "inv":
		_send_key(KEY_I)
		return
	if not _can_act():
		return
	match b:
		"light":
			if main.aiming:
				if main.aim_valid:
					main._confirm_meteor()
			else:
				held[MOUSE_BUTTON_LEFT] = true
				main._attack("light")
		"heavy":
			if main.aiming:
				main._cancel_aim()
			else:
				held[MOUSE_BUTTON_RIGHT] = true
				main._attack("heavy")
		"dash": main._dash()
		"ult": main._ultimate()
		"interact": main._interact()
		"potion": main._use_potion()
		"sprint": sprint = true
		"next":
			if not main.attacking:
				main._select((main.selected + 1) % main.hotbar.size())

func _release(b: String) -> void:
	match b:
		"light": held[MOUSE_BUTTON_LEFT] = false
		"heavy": held[MOUSE_BUTTON_RIGHT] = false
		"sprint": sprint = false

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
	if main.aiming:
		if not _was_aiming:
			aim_point = main.touch_default_aim()
		aim_point = (aim_point + stick * AIM_SPEED * delta).limit_length(AIM_MAX)
	_was_aiming = main.aiming
	_draw_node.queue_redraw()

func _on_draw() -> void:
	var ci := _draw_node
	if _stick_id != -1:
		ci.draw_circle(_stick_origin, STICK_R, Color(1, 1, 1, 0.10))
		ci.draw_arc(_stick_origin, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		ci.draw_circle(_stick_pos if (_stick_pos - _stick_origin).length() <= STICK_R else _stick_origin + (_stick_pos - _stick_origin).normalized() * STICK_R, 48.0, Color(1, 1, 1, 0.35))
	else:
		var s := get_viewport().get_visible_rect().size
		ci.draw_arc(Vector2(190, s.y - 200), STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.18), 3.0)
	var font := ThemeDB.fallback_font
	var down := _btn_touch.values()
	for k in _buttons:
		var b: Dictionary = _buttons[k]
		var on: bool = k in down
		ci.draw_circle(b["c"], b["r"], Color(1, 1, 1, 0.32 if on else 0.14))
		ci.draw_arc(b["c"], b["r"], 0, TAU, 40, Color(1, 1, 1, 0.5), 3.0)
		var fs := 24 if b["r"] >= 60.0 else 18
		var w := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, b["c"] + Vector2(-w / 2.0, fs * 0.35), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
