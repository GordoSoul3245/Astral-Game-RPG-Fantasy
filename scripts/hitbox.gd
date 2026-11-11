extends RefCounted
# Hitboxes pegadas al sprite. Cada entidad tiene una elipse corporal por dirección, medida de sus PNG (silueta real,
# no un círculo genérico en el suelo; centrada en la masa de píxeles del sprite):
# {"c": centro relativo a los pies, "rx": semiancho, "ry": semialto}, en px de suelo (1 px de sprite = 1 px de suelo).
# Los golpes en el aire (tajos, proyectiles) se miden contra la elipse corporal; las explosiones en el suelo, contra
# su huella (la misma elipse aplastada por la vista isométrica). Una entidad sin sprite usa un círculo de `radius`.

const SQUASH := 0.6
const SPREAD := 2.2   # semiejes = 2.2 desviaciones de la masa de píxeles (una elipse llena es 2.0; el extra cubre cabeza, pies y armas)
const DIRS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]  # mismo orden que main.DIRS (pasos de 45° desde el este)

static var cache := {}

static func _image(path: String) -> Image:
	var img: Image = null
	if ResourceLoader.exists(path):
		img = (load(path) as Texture2D).get_image()
	elif FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null and img.is_compressed():
		img.decompress()
	return img

# Una elipse por dirección (reposo): un animal alargado es ancho de lado y estrecho de frente.
# template: ruta del PNG con %s = dirección; feet: píxel de los pies dentro del PNG. Devuelve {} si no hay arte.
static func measure(dirs: Array, template: String, feet: Vector2) -> Dictionary:
	var key := "%s|%s" % [template, feet]
	if cache.has(key):
		return cache[key]
	var out := {}
	for d: String in dirs:
		var e := _ellipse_of(template % d, feet)
		if not e.is_empty():
			out[d] = e
	cache[key] = out
	return out

static func _ellipse_of(path: String, feet: Vector2) -> Dictionary:
	var img := _image(path)
	if img == null:
		return {}
	var box := img.get_used_rect()  # solo se recorre la zona con píxeles (los sprites chicos se miden entero)
	var step := maxi(1, maxi(box.size.x, box.size.y) / 64)
	var cnt := 0
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for y in range(box.position.y, box.end.y, step):
		for x in range(box.position.x, box.end.x, step):
			if img.get_pixel(x, y).a > 0.3:
				cnt += 1
				sx += x
				sy += y
				sxx += float(x) * x
				syy += float(y) * y
	if cnt < 4:
		return {}
	var mx := sx / cnt
	var my := sy / cnt
	return {"c": Vector2(mx, my) - feet, "rx": sqrt(maxf(sxx / cnt - mx * mx, 1.0)) * SPREAD, "ry": sqrt(maxf(syy / cnt - my * my, 1.0)) * SPREAD}

static func _dir_name(e: Object) -> String:  # hacia dónde mira ahora: `facing` (texto) o `look` (vector)
	var f: Variant = e.get("facing")
	if f is String:
		return f
	var l: Variant = e.get("look")
	if l is Vector2 and l != Vector2.ZERO:
		return DIRS[posmod(roundi(l.angle() / (PI / 4.0)), 8)]
	return "S"

static func of(e: Object) -> Dictionary:
	var h: Variant = e.get("hit")
	if h is Dictionary and not h.is_empty():
		var d: Dictionary = h
		return d.get(_dir_name(e), d.values()[0])
	var r: Variant = e.get("radius")
	var rr: float = r if r != null else 10.0
	return {"c": Vector2(0, -rr), "rx": rr, "ry": rr}

static func center(e: Object) -> Vector2:  # centro del cuerpo en px de suelo (misma unidad que pos)
	return e.pos + of(e)["c"]

static func _edist(q: Vector2, rx: float, ry: float) -> float:  # distancia aproximada del punto q al borde de la elipse (0 dentro)
	var k := Vector2(q.x / rx, q.y / ry).length()
	return 0.0 if k <= 1.0 else q.length() * (1.0 - 1.0 / k)

static func dist(e: Object, p: Vector2) -> float:  # punto en el aire (px de suelo, ya elevado) -> cuerpo
	var b := of(e)
	return _edist(p - (e.pos + b["c"]), b["rx"], b["ry"])

static func foot_dist(e: Object, p: Vector2) -> float:  # punto sobre el suelo -> huella
	var b := of(e)
	return _edist(p - e.pos, b["rx"], b["rx"] * SQUASH)
