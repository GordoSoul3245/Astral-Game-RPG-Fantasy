extends RefCounted
# Progresión del héroe: nivel, XP, puntos de estadística, monedas, materiales y equipo (data/equipment.json).

const STATS := ["strength", "magic", "mana", "endurance", "defense", "move_speed", "attack_speed"]
const STAT_NAMES := {"strength": "Fuerza", "magic": "Daño de magia", "mana": "Maná", "endurance": "Resistencia", "defense": "Defensa", "move_speed": "Vel. de movimiento", "attack_speed": "Vel. de ataque"}
const STAT_INFO := {
	"strength": "+6 % daño de espada",
	"magic": "+6 % daño de hechizos",
	"mana": "+10 maná máximo",
	"endurance": "+10 estamina máxima",
	"defense": "reduce el daño recibido",
	"move_speed": "+4 % al caminar y correr",
	"attack_speed": "+5 % ataques más rápidos",
}
const SLOTS := ["sword", "grimoire", "armor", "ring", "amulet", "pickaxe", "axe"]
const SLOT_NAMES := {"sword": "Espada", "grimoire": "Grimorio", "armor": "Armadura", "ring": "Anillo", "amulet": "Collar", "pickaxe": "Pico", "axe": "Hacha"}
const POINTS_PER_LEVEL := 5

var level := 1
var xp := 0
var points := 0
var spent := {}              # estadística -> puntos gastados
var coins := 0
var potions := 1
var materials := {}          # id -> cantidad
var owned: Array = []        # ids de equipo obtenido
var equipped := {}           # ranura -> id
var equipment := {}
var material_names := {}
var blueprints: Array = []   # planos de alquimia aprendidos (data/crafting.json)
var buffs: Array = []        # bonus temporales de comida y elixires: {stat, amount, t}
var quick := ""              # consumible de la tecla G

func _init(data: Dictionary) -> void:
	equipment = data["items"]
	material_names = data["materials"]
	for s in STATS:
		spent[s] = 0

func xp_needed() -> int:
	return 50 + 40 * (level - 1)

func add_xp(n: int) -> int:  # devuelve los niveles ganados
	xp += n
	var gained := 0
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		points += POINTS_PER_LEVEL
		gained += 1
	return gained

func bonus(stat: String) -> float:  # suma de lo que dan los objetos equipados
	var b := 0.0
	for slot: String in equipped:
		b += equipment[equipped[slot]]["mods"].get(stat, 0)
	for f: Dictionary in buffs:
		if f["stat"] == stat:
			b += f["amount"]
	return b

func add_buff(stat: String, amount: float, secs: float) -> void:  # un bonus de la misma estadística se renueva, no se suma
	for f: Dictionary in buffs:
		if f["stat"] == stat:
			f["amount"] = maxf(f["amount"], amount)
			f["t"] = maxf(f["t"], secs)
			return
	buffs.append({"stat": stat, "amount": amount, "t": secs})

func tick_buffs(delta: float) -> bool:  # true si alguno terminó (hay que recalcular estadísticas)
	var ended := false
	for f: Dictionary in buffs:
		f["t"] -= delta
		ended = ended or f["t"] <= 0.0
	if ended:
		buffs = buffs.filter(func(f: Dictionary) -> bool: return f["t"] > 0.0)
	return ended

func stat(s: String) -> float:
	return spent.get(s, 0) + bonus(s)

func spend(s: String) -> bool:
	if points <= 0:
		return false
	points -= 1
	spent[s] += 1
	return true

func max_hp(base: float) -> int:
	return roundi(base + 10.0 * (level - 1) + bonus("max_hp"))

func max_mana(base: float) -> float:
	return base + 10.0 * stat("mana")

func max_stamina(base: float) -> float:
	return base + 10.0 * stat("endurance")

func melee_mult() -> float:
	return 1.0 + 0.06 * stat("strength")

func magic_mult() -> float:
	return 1.0 + 0.06 * stat("magic")

func defense_mult() -> float:  # fracción del daño que sí se recibe
	return 20.0 / (20.0 + stat("defense"))

func move_mult() -> float:
	return 1.0 + 0.04 * stat("move_speed")

func attack_speed() -> float:
	return 1.0 + 0.05 * stat("attack_speed")

func equip(id: String) -> void:
	equipped[equipment[id]["slot"]] = id

func unequip(slot: String) -> void:
	equipped.erase(slot)

# guarda el objeto y lo equipa si la ranura está libre o es mejor; devuelve true si quedó equipado
func add_item(id: String) -> bool:
	if not owned.has(id):
		owned.append(id)
	var cur: String = equipped.get(equipment[id]["slot"], "")
	if cur == "" or equipment[id]["tier"] > equipment[cur]["tier"]:
		equip(id)
		return true
	return false
