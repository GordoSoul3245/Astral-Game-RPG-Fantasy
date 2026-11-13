extends RefCounted
# Creación: crafteo a mano, forja, cocina, alquimia con planos y recolección (data/crafting.json).
# Lógica pura (sin nodos ni interfaz): la usan el menú, las estaciones y los tests headless.
# Todo lo apilable (materiales, comida, pociones) vive en prog.materials; las pociones de vida van a prog.potions (tecla H).

var prog: RefCounted
var cfg := {}
var rng := RandomNumberGenerator.new()

func _init(p: RefCounted, data: Dictionary) -> void:
	prog = p
	cfg = data
	rng.randomize()
	for id: String in cfg["materials"]:  # los nombres de lo nuevo se registran junto a los materiales de los monstruos
		prog.material_names[id] = cfg["materials"][id]["name"]
	for id: String in cfg["consumables"]:
		if id != "pocion_vida":
			prog.material_names[id] = cfg["consumables"][id]["name"]
	for id: String in cfg["blueprints"]:
		prog.material_names[id] = cfg["blueprints"][id]["name"]

# --- inventario unificado
func count(id: String) -> int:
	return prog.potions if id == "pocion_vida" else int(prog.materials.get(id, 0))

func add(id: String, n: int, star := 0) -> void:  # star: 0 normal, 1 plata, 2 oro (calidad de pesca y cocina)
	if id == "pocion_vida":
		prog.potions += n
	else:
		prog.materials[id] = int(prog.materials.get(id, 0)) + n
		if star > 0:
			var st: Array = prog.stars.get(id, [0, 0])
			st[star - 1] += n
			prog.stars[id] = st

func stars_of(id: String) -> Array:  # [unidades de plata, unidades de oro]; nunca más que las que hay
	var st: Array = prog.stars.get(id, [0, 0])
	var total := count(id)
	return [mini(int(st[0]), total), mini(int(st[1]), maxi(0, total - int(st[0])))]

func take(id: String, n: int, best_first := false) -> int:  # devuelve la mejor calidad entre las unidades gastadas
	if id == "pocion_vida":
		prog.potions = maxi(0, prog.potions - n)
		return 0
	var st := stars_of(id)
	var plain := count(id) - int(st[0]) - int(st[1])
	var order: Array = [[2, int(st[1])], [1, int(st[0])], [0, plain]] if best_first else [[0, plain], [1, int(st[0])], [2, int(st[1])]]
	var left_n := n
	var best := 0
	for o: Array in order:
		var k := mini(left_n, int(o[1]))
		if k > 0:
			left_n -= k
			best = maxi(best, int(o[0]))
			if int(o[0]) > 0:
				st[int(o[0]) - 1] -= k
	var left := int(prog.materials.get(id, 0)) - n
	if left > 0:
		prog.materials[id] = left
		prog.stars[id] = st
	else:
		prog.materials.erase(id)
		prog.stars.erase(id)
	return best

func item_name(id: String) -> String:
	if prog.equipment.has(id):
		return prog.equipment[id]["name"]
	if cfg["consumables"].has(id):
		return cfg["consumables"][id]["name"]
	if cfg["blueprints"].has(id):
		return cfg["blueprints"][id]["name"]
	return prog.material_names.get(id, id)

func item_desc(id: String) -> String:
	if cfg["materials"].has(id):
		return cfg["materials"][id]["desc"]
	if cfg["consumables"].has(id):
		return cfg["consumables"][id]["desc"]
	if prog.equipment.has(id):
		return prog.equipment[id]["desc"]
	if cfg["blueprints"].has(id):
		return "Plano de alquimia. Se usa en la mesa de alquimia."
	return ""

func icon(id: String) -> String:
	return "res://art/items/%s.png" % ("plano" if cfg["blueprints"].has(id) else id)

func is_blueprint(id: String) -> bool:
	return cfg["blueprints"].has(id)

# --- recetas (forja, cocina, manos)
func recipes_for(station: String) -> Array:
	var out: Array = []
	for rid: String in cfg["recipes"]:
		if cfg["recipes"][rid]["station"] == station:
			out.append(rid)
	return out

func output_of(rid: String) -> String:
	return cfg["recipes"][rid].get("output", rid)

func qty_of(rid: String) -> int:
	return int(cfg["recipes"][rid].get("qty", 1))

func inputs_of(rid: String) -> Dictionary:
	return cfg["recipes"][rid]["inputs"]

func missing(inputs: Dictionary) -> Dictionary:  # id -> cuántos faltan
	var out := {}
	for id: String in inputs:
		var lack := int(inputs[id]) - count(id)
		if lack > 0:
			out[id] = lack
	return out

func why_not(rid: String) -> String:  # "" = se puede fabricar
	var out := output_of(rid)
	if prog.equipment.has(out) and prog.owned.has(out):
		return "Ya la tienes."
	if not missing(inputs_of(rid)).is_empty():
		return "Faltan materiales."
	return ""

func craft(rid: String) -> Dictionary:  # {ok, id, qty, msg}
	var reason := why_not(rid)
	if reason != "":
		return {"ok": false, "id": "", "qty": 0, "msg": reason}
	var inp := inputs_of(rid)
	var q := 0
	for id: String in inp:
		q = maxi(q, take(id, int(inp[id]), true))  # un plato con pescado de calidad sale de calidad
	var out := output_of(rid)
	var n := qty_of(rid)
	if prog.equipment.has(out):
		prog.add_item(out)
		n = 1
	else:
		add(out, n, q if cfg["consumables"].has(out) else 0)
	return {"ok": true, "id": out, "qty": n, "msg": "%s%s" % [item_name(out), " ×%d" % n if n > 1 else ""]}

# --- alquimia: los planos se aprenden y no se gastan; los ingredientes y el catalizador sí
func knows(plano: String) -> bool:
	return prog.blueprints.has(plano)

func learn(plano: String) -> bool:  # false si ya lo conocías
	if prog.blueprints.has(plano) or not cfg["blueprints"].has(plano):
		return false
	prog.blueprints.append(plano)
	return true

func brew(plano: String, catalyst := false) -> Dictionary:
	if not knows(plano):
		return {"ok": false, "id": "", "qty": 0, "msg": "No conoces ese plano."}
	var bp: Dictionary = cfg["blueprints"][plano]
	if not missing(bp["inputs"]).is_empty():
		return {"ok": false, "id": "", "qty": 0, "msg": "Faltan ingredientes."}
	var cat: String = cfg["alchemy_catalyst"]["id"]
	if catalyst and count(cat) < 1:
		return {"ok": false, "id": "", "qty": 0, "msg": "No tienes catalizador."}
	for id: String in bp["inputs"]:
		take(id, int(bp["inputs"][id]))
	var n := int(bp["qty"])
	if catalyst:
		take(cat, 1)
		n *= 2
	add(bp["output"], n)
	return {"ok": true, "id": bp["output"], "qty": n, "msg": "%s ×%d" % [item_name(bp["output"]), n]}

# --- consumibles: comida, pociones y bombas
func is_consumable(id: String) -> bool:
	return cfg["consumables"].has(id)

func consumables_owned() -> Array:  # ids con existencias, en el orden del archivo
	var out: Array = []
	for id: String in cfg["consumables"]:
		if count(id) > 0:
			out.append(id)
	return out

func use(main: Node, id: String) -> String:
	if not is_consumable(id) or count(id) <= 0:
		return ""
	var c: Dictionary = cfg["consumables"][id]
	if c.has("heal") and not c.has("buff") and main.hero_hp >= main.hero_max_hp:
		return "Ya tienes la vida completa."
	var q := take(id, 1, true)
	var fav := id == favorite_dish(main.clock.day)
	var k: float = [1.0, 1.25, 1.5][q] * (float(cfg["favorite"]["mult"]) if fav else 1.0)  # calidad y plato favorito del día
	var parts: Array[String] = []
	if fav:
		parts.append("¡plato favorito del día!")
	if q > 0:
		parts.append("calidad " + "★".repeat(q))
	if c.has("heal"):
		var heal := roundi(float(c["heal"]) * k)
		main.hero_hp = mini(main.hero_max_hp, main.hero_hp + heal)
		parts.append("+%d vida" % heal)
	if c.has("regen"):
		main.regen_left += float(c["regen"]["amount"]) * k
		main.regen_rate = float(c["regen"]["amount"]) * k / float(c["regen"]["time"])
		parts.append("regenera %d" % roundi(float(c["regen"]["amount"]) * k))
	if c.has("mana"):
		main.mana = minf(main.hero_data["mana"], main.mana + float(c["mana"]))
		parts.append("+%d maná" % int(c["mana"]))
	if c.has("stamina"):
		main.stamina = main.hero_data["stamina"]
		parts.append("estamina llena")
	for key in ["buff", "buff2"]:
		if c.has(key):
			var amount := float(c[key]["amount"]) * (1.5 if fav else 1.0)
			prog.add_buff(c[key]["stat"], amount, float(c[key]["time"]) * (2.0 if fav else 1.0))
			parts.append("+%d %s" % [roundi(amount), prog.STAT_NAMES[c[key]["stat"]]])
	if c.has("night_vision"):
		main.night_vision_t = float(c["night_vision"])
		parts.append("visión nocturna")
	if c.has("fish_luck"):
		main.fish_luck_t = float(c["fish_luck"])
		parts.append("suerte de pescador")
	if c.has("bomb"):
		main.combat.detonate_at(main.pos, float(c["bomb"]["radius"]), int(c["bomb"]["damage"]))
		parts.append("¡explosión!")
	main._apply_stats()
	return "%s: %s" % [item_name(id), ", ".join(parts)]

func favorite_dish(day: int) -> String:  # el plato que hoy le gusta al héroe: sus efectos mejoran
	var dishes: Array = []
	for rid: String in recipes_for("cook"):
		dishes.append(output_of(rid))
	return dishes[(day * 5 + 2) % dishes.size()] if not dishes.is_empty() else ""

# --- recolección
func tool_tier(kind: String) -> int:  # 0 = manos
	var id: String = prog.equipped.get(kind, "")
	return int(prog.equipment[id]["tool"]["tier"]) if id != "" and prog.equipment[id].has("tool") else 0

func swing_power(kind: String) -> int:  # daño por golpe al recurso; las manos valen 1
	if kind == "":
		return 1
	return int(cfg["tool_power"][str(tool_tier(kind))])

func can_gather(node_kind: String) -> String:  # "" = puedes; si no, qué te falta
	var g: Dictionary = cfg["gather"][node_kind]
	if g["tool"] != "" and tool_tier(g["tool"]) < int(g["need"]):
		return "Necesitas un %s mejor." % ("pico" if g["tool"] == "pickaxe" else "hacha")
	return ""

func roll_drops(node_kind: String) -> Dictionary:  # id -> cantidad; un +1 con herramienta de nivel 2 o más
	var g: Dictionary = cfg["gather"][node_kind]
	var out := {}
	for id: String in g["drops"]:
		var r: Array = g["drops"][id]
		var n := rng.randi_range(int(r[0]), int(r[1]))
		if g["tool"] != "" and tool_tier(g["tool"]) >= 2:
			n += 1
		out[id] = n
	return out
