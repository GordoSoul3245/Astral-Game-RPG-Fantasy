extends RefCounted
# Misiones en cadena del pueblo (data/quests.json): una a la vez. Elda la ofrece, el mundo avisa de eventos
# (muertes, pisos completados) y al volver con ella se cobra la recompensa y llega la siguiente.

var giver := "Elda"
var list: Array = []
var idx := 0
var status := "none"     # none (por ofrecer), active, ready (cumplida, falta entregar)
var progress := 0
var met_gaucho := false
var floors_done: Array[int] = []
var awakening: Array
var payada: Array

func _init(data: Dictionary) -> void:
	giver = data["giver"]
	list = data["quests"]
	awakening = data["awakening"]
	payada = data["payada"]

func current() -> Dictionary:
	return list[idx] if idx < list.size() else {}

func notify(event: String, target: String) -> bool:  # true si con esto quedó cumplida
	var q := current()
	if status != "active" or q.is_empty() or q["event"] != event:
		return false
	var floor_no := target.to_int()
	if floor_no < 1 or floors_done.has(floor_no):
		return false
	floors_done.append(floor_no)
	progress = floors_done.size()
	if progress >= int(q["count"]):
		status = "ready"
		return true
	return false

func talk(main: Node) -> String:  # lo que dice Elda; acepta o entrega según el estado
	var q := current()
	if q.is_empty():
		return "%s: Ya no tengo más encargos. ¡Gracias por todo, viajero!" % giver
	if not met_gaucho:
		return "Elda: Venís del bosque, ¿verdad? Antes de seguir, hablá con el viejo del fogón. Anoche se quedó ahí cuidando de alguien."
	match status:
		"none":
			status = "active"
			progress = 0
			return q["offer"]
		"active":
			return "%s: %s (%d/%d)" % [giver, q["goal"], progress, int(q["count"])]
	var r: Dictionary = q["reward"]
	var lines: Array[String] = [str(q["turn_in"])]
	if r.has("coins"):
		main.prog.coins += int(r["coins"])
		lines.append("+%d monedas" % int(r["coins"]))
	if r.has("potions"):
		main.prog.potions += int(r["potions"])
		lines.append("+%d poción" % int(r["potions"]))
	if r.has("xp"):
		main.gain_xp(int(r["xp"]))
		lines.append("+%d XP" % int(r["xp"]))
	idx += 1
	status = "none"
	progress = 0
	return "\n".join(lines)

func marker() -> String:  # sobre Elda: "!" hay misión nueva, "?" hay que entregar
	if status == "ready":
		return "?"
	return "!" if met_gaucho and status == "none" and idx < list.size() else ""

func tracker() -> String:  # texto de la HUD
	var q := current()
	if q.is_empty():
		return ""
	if status == "none":
		return "Hablá con Elda en el centro de Ignis" if met_gaucho else "Hablá con el viejo junto al fogón"
	if status == "ready":
		return "Misión: %s\nVuelve con %s" % [q["name"], giver]
	var n := int(q["count"])
	return "Misión: %s\n%s%s" % [q["name"], q["goal"], " (%d/%d)" % [progress, n] if n > 1 else ""]

func to_dict() -> Dictionary:
	return {"campaign": "ignis", "idx": idx, "status": status, "gaucho": met_gaucho, "floors": floors_done.duplicate()}

func from_dict(d: Dictionary) -> void:
	floors_done.clear()
	progress = 0
	if d.get("campaign") != "ignis":
		# Las partidas anteriores pueden tomar el nuevo encargo directamente en el pueblo.
		met_gaucho = true
		idx = 0
		status = "none"
		return
	met_gaucho = d.get("gaucho") == true
	idx = clampi(int(d.get("idx", 0)), 0, list.size())
	if d.get("floors") is Array:
		for n in d.floors:
			if (n is float or n is int) and int(n) > 0 and not floors_done.has(int(n)):
				floors_done.append(int(n))
	progress = floors_done.size()
	status = "none"
	if not current().is_empty() and d.get("status") in ["active", "ready"]:
		status = "ready" if progress >= int(current().count) else "active"
