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

func add(id: String, n: int) -> void:
	if id == "pocion_vida":
		prog.potions += n
	else:
		prog.materials[id] = int(prog.materials.get(id, 0)) + n

func take(id: String, n: int) -> void:
	if id == "pocion_vida":
		prog.potions = maxi(0, prog.potions - n)
		return
	var left := int(prog.materials.get(id, 0)) - n
	if left > 0:
		prog.materials[id] = left
	else:
		prog.materials.erase(id)

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
	for id: String in inp:
		take(id, int(inp[id]))
	var out := output_of(rid)
	var n := qty_of(rid)
	if prog.equipment.has(out):
		prog.add_item(out)
		n = 1
	else:
		add(out, n)
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
	take(id, 1)
	var parts: Array[String] = []
	if c.has("heal"):
		main.hero_hp = mini(main.hero_max_hp, main.hero_hp + int(c["heal"]))
		parts.append("+%d vida" % int(c["heal"]))
	if c.has("mana"):
		main.mana = minf(main.hero_data["mana"], main.mana + float(c["mana"]))
		parts.append("+%d maná" % int(c["mana"]))
	if c.has("stamina"):
		main.stamina = main.hero_data["stamina"]
		parts.append("estamina llena")
	for key in ["buff", "buff2"]:
		if c.has(key):
			prog.add_buff(c[key]["stat"], float(c[key]["amount"]), float(c[key]["time"]))
			parts.append("+%d %s" % [int(c[key]["amount"]), prog.STAT_NAMES[c[key]["stat"]]])
	if c.has("bomb"):
		main.combat.detonate_at(main.pos, float(c["bomb"]["radius"]), int(c["bomb"]["damage"]))
		parts.append("¡explosión!")
	main._apply_stats()
	return "%s: %s" % [item_name(id), ", ".join(parts)]

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
