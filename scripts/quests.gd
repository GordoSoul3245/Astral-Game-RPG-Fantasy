extends RefCounted
# Misiones en cadena del pueblo (data/quests.json): una a la vez. Elda la ofrece, el mundo avisa de eventos
# (muertes, pisos completados) y al volver con ella se cobra la recompensa y llega la siguiente.

var giver := "Elda"
var list: Array = []
var idx := 0
var status := "none"     # none (por ofrecer), active, ready (cumplida, falta entregar)
var progress := 0

func _init(data: Dictionary) -> void:
	giver = data["giver"]
	list = data["quests"]

func current() -> Dictionary:
	return list[idx] if idx < list.size() else {}

func notify(event: String, target: String) -> bool:  # true si con esto quedó cumplida
	var q := current()
	if status != "active" or q.is_empty() or q["event"] != event or q["target"] != target:
		return false
	progress += 1
	if progress >= int(q["count"]):
		status = "ready"
		return true
	return false

func talk(main: Node) -> String:  # lo que dice Elda; acepta o entrega según el estado
	var q := current()
	if q.is_empty():
		return "%s: Ya no tengo más encargos. ¡Gracias por todo, viajero!" % giver
	match status:
		"none":
			status = "active"
			progress = 0
			return "%s: %s\nNueva misión: %s" % [giver, q["offer"], q["name"]]
		"active":
			return "%s: %s (%d/%d)" % [giver, q["goal"], progress, int(q["count"])]
	var r: Dictionary = q["reward"]
	var lines: Array[String] = ["%s: ¡Lo lograste! Toma esto." % giver]
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
	return "!" if status == "none" and idx < list.size() else ""

func tracker() -> String:  # texto de la HUD
	var q := current()
	if q.is_empty() or status == "none":
		return ""
	if status == "ready":
		return "Misión: %s\nVuelve con %s" % [q["name"], giver]
	var n := int(q["count"])
	return "Misión: %s\n%s%s" % [q["name"], q["goal"], " (%d/%d)" % [progress, n] if n > 1 else ""]

func to_dict() -> Dictionary:
	return {"idx": idx, "status": status, "progress": progress}

func from_dict(d: Dictionary) -> void:  # validado: datos de disco
	idx = clampi(int(d.get("idx", 0)), 0, list.size())
	status = d.get("status", "none") if d.get("status") in ["none", "active", "ready"] else "none"
	progress = maxi(0, int(d.get("progress", 0)))
