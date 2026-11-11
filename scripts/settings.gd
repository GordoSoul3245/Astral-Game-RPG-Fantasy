extends RefCounted
# Opciones del jugador (menú [I] → Opciones), en user://settings.json: accesibilidad de efectos y volúmenes.
# Independientes de la partida guardada. Todo valor de disco se valida y se limita a su rango.

var path := "user://settings.json"
var shake := 1.0        # 0 = sin temblor ni empujón de cámara
var flash := 1.0        # 0 = sin destellos blancos ni luces de impacto; 1 = normal
var hitstop := true     # pausa de impacto de los golpes pesados
var master := 1.0
var sfx := 1.0
var music := 0.6

func load_file() -> bool:
	if not FileAccess.file_exists(path):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		return false
	shake = clampf(float(d.get("shake", 1.0)), 0.0, 1.0)
	flash = clampf(float(d.get("flash", 1.0)), 0.0, 1.0)
	hitstop = bool(d.get("hitstop", true))
	master = clampf(float(d.get("master", 1.0)), 0.0, 1.0)
	sfx = clampf(float(d.get("sfx", 1.0)), 0.0, 1.0)
	music = clampf(float(d.get("music", 0.6)), 0.0, 1.0)
	return true

func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"shake": shake, "flash": flash, "hitstop": hitstop, "master": master, "sfx": sfx, "music": music}, "\t"))

func _bus(name: String) -> int:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
	return i

func apply_audio() -> void:  # los buses "SFX" y "Music" cuelgan de Master
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(master, 0.0001)))
	AudioServer.set_bus_volume_db(_bus("SFX"), linear_to_db(maxf(sfx, 0.0001)))
	AudioServer.set_bus_volume_db(_bus("Music"), linear_to_db(maxf(music, 0.0001)))
