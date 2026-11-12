extends RefCounted
# Todo lo que recuerda el pescador (lógica pura, sin nodos): libro de capturas con récords y recompensas,
# acuario (peces vivos que producen con los días), encargos diarios de Bram y Tomás, y las nasas/trampas colocadas.
# Datos en data/fishing.json; el guardado va en save.json (to_dict/from_dict).

var main: Node
var cfg: Dictionary
var book := {}          # id -> {count, best_cm, best_star}
var claimed: Array = [] # hitos del libro ya cobrados (índices)
var tank: Array = []    # ids de peces vivos en el acuario
var bin := {}           # lo que el acuario ya produjo y no se ha recogido
var done := {}          # giver -> último día cuyo encargo se entregó
var traps: Array = []   # {kind: "water"|"land", pos: [x, y] en suelo, ready: hora de juego en que está lista}

func _init(m: Node, data: Dictionary) -> void:
	main = m
	cfg = data
	m.clock.new_day.connect(_on_new_day)

# --- libro de capturas
func record(id: String, cm: int, star: int) -> String:  # devuelve el aviso de récord/hito, "" si no hay
	var e: Dictionary = book.get(id, {"count": 0, "best_cm": 0, "best_star": 0})
	var msgs: Array[String] = []
	if int(e["count"]) == 0:
		msgs.append("¡Nueva especie en el libro!")
	if cm > int(e["best_cm"]) and int(e["count"]) > 0:
		msgs.append("¡Récord: %d cm!" % cm)
	e["count"] = int(e["count"]) + 1
	e["best_cm"] = maxi(int(e["best_cm"]), cm)
	e["best_star"] = maxi(int(e["best_star"]), star)
	book[id] = e
	var ms: Array = cfg["book"]
	for i in ms.size():
		if not claimed.has(i) and book.size() >= int(ms[i]["species"]):
			claimed.append(i)
			var parts: Array[String] = []
			if ms[i].has("coins"):
				main.prog.coins += int(ms[i]["coins"])
				parts.append("%d monedas" % int(ms[i]["coins"]))
			if ms[i].has("item"):
				main.crafting.add(str(ms[i]["item"]), int(ms[i].get("qty", 1)))
				parts.append("%s ×%d" % [main.crafting.item_name(str(ms[i]["item"])), int(ms[i].get("qty", 1))])
			msgs.append("Libro: %d especies → %s" % [int(ms[i]["species"]), ", ".join(parts)])
	return "  ".join(msgs)

func species_total() -> int:
	return (cfg["fish"] as Dictionary).size()

# --- acuario
func slots() -> int:
	return int(cfg["aquarium"]["slots"])

func deposit(id: String) -> String:
	if not (cfg["aquarium"]["yield"] as Dictionary).has(id) or main.crafting.count(id) <= 0:
		return "No tienes ese pez."
	if tank.size() >= slots():
		return "El acuario está lleno."
	main.crafting.take(id, 1, true)
	tank.append(id)
	return "%s al acuario." % main.crafting.item_name(id)

func release(i: int) -> String:  # saca un pez vivo del acuario de vuelta a la mochila
	if i < 0 or i >= tank.size():
		return ""
	var id: String = tank[i]
	tank.remove_at(i)
	main.crafting.add(id, 1)
	return "%s vuelve a tu mochila." % main.crafting.item_name(id)

func _on_new_day() -> void:  # cada día amanece una producción por pez
	var y: Dictionary = cfg["aquarium"]["yield"]
	for id: String in tank:
		for item: String in y[id]:
			bin[item] = int(bin.get(item, 0)) + int(y[id][item])

func collect() -> String:
	if bin.is_empty():
		return "Aún no ha producido nada."
	var parts: Array[String] = []
	for item: String in bin:
		var n: int = bin[item]
		if item == "coins":
			main.prog.coins += n
			parts.append("%d monedas" % n)
		else:
			main.crafting.add(item, n)
			parts.append("%s ×%d" % [main.crafting.item_name(item), n])
	bin.clear()
	return "Recoges: " + ", ".join(parts)

# --- encargos de Bram ("smith") y Tomás ("merchant"): uno por día y comerciante, rota con los días
func order(giver: String) -> Dictionary:
	var list: Array = cfg["orders"].get(giver, [])
	return list[(int(main.clock.day) - 1) % list.size()] if not list.is_empty() else {}

func order_done(giver: String) -> bool:
	return int(done.get(giver, 0)) == int(main.clock.day)

func deliver(giver: String) -> String:
	var o := order(giver)
	if o.is_empty() or order_done(giver):
		return "Hoy no hay más encargos."
	var id: String = o["item"]
	if main.crafting.count(id) < int(o["qty"]):
		return "Te faltan %d × %s." % [int(o["qty"]) - main.crafting.count(id), main.crafting.item_name(id)]
	main.crafting.take(id, int(o["qty"]), true)
	main.prog.coins += int(o["coins"])
	done[giver] = int(main.clock.day)
	return "Entregaste el encargo: +%d monedas." % int(o["coins"])

# --- guardado
func to_dict() -> Dictionary:
	return {"book": book, "claimed": claimed, "tank": tank, "bin": bin, "done": done, "traps": traps}

func from_dict(d: Dictionary) -> void:  # validado: datos de disco
	var fish: Dictionary = cfg["fish"]
	book.clear()
	if d.get("book") is Dictionary:
		for id: String in d["book"]:
			var e: Variant = d["book"][id]
			if fish.has(id) and e is Dictionary:
				book[id] = {"count": maxi(1, int(e.get("count", 1))), "best_cm": maxi(0, int(e.get("best_cm", 0))), "best_star": clampi(int(e.get("best_star", 0)), 0, 2)}
	claimed = (d.get("claimed", []) as Array).map(func(i: Variant) -> int: return int(i)) if d.get("claimed") is Array else []
	tank = (d["tank"] as Array).map(func(i: Variant) -> String: return str(i)).filter(func(i: String) -> bool: return cfg["aquarium"]["yield"].has(i)) if d.get("tank") is Array else []
	tank = tank.slice(0, slots())
	bin.clear()
	if d.get("bin") is Dictionary:
		for k: String in d["bin"]:
			if k == "coins" or main.crafting.cfg["materials"].has(k):
				bin[k] = maxi(0, int(d["bin"][k]))
	done.clear()
	if d.get("done") is Dictionary:
		for g: String in d["done"]:
			done[g] = int(d["done"][g])
	traps.clear()
	if d.get("traps") is Array:
		for t: Variant in d["traps"]:
			if t is Dictionary and t.get("kind") in ["water", "land"] and t.get("pos") is Array and (t["pos"] as Array).size() == 2:
				traps.append({"kind": t["kind"], "pos": [float(t["pos"][0]), float(t["pos"][1])], "ready": float(t.get("ready", 0.0))})
