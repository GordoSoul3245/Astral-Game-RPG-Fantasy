extends SceneTree
# Mide la punta de la caña en cada fotograma de pesca (el píxel crema más alto) y la guarda en data/rod_tips.json.
func _initialize() -> void:
	var dirs := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	var res := {}
	var over: Image = Image.create(128 * 6, 128 * 8, false, Image.FORMAT_RGBA8)
	over.fill(Color.WHITE)
	for anim: String in ["fish_cast", "fish_wait", "fish_reel"]:
		for d in 8:
			var list := []
			var n := 0
			while FileAccess.file_exists("res://art/hechicero/%s_%s_%02d.png" % [anim, dirs[d], n]):
				var img: Image = Image.load_from_file("res://art/hechicero/%s_%s_%02d.png" % [anim, dirs[d], n])
				img.convert(Image.FORMAT_RGBA8)
				var best := Vector2(-1, 999)
				for y in img.get_height():
					for x in img.get_width():
						var c: Color = img.get_pixel(x, y)
						if c.a > 0.9 and c.r > 0.8 and c.g > 0.7 and c.b > 0.45 and c.r - c.b < 0.5 and y < best.y:
							best = Vector2(x, y)
				list.append([best.x, best.y])
				if anim == "fish_wait" and n < 6:
					over.blend_rect(img, Rect2i(0, 0, 128, 128), Vector2i(n * 128, d * 128))
					for k in range(-2, 3):
						over.set_pixel(clampi(int(best.x) + k, 0, 127) + n * 128, clampi(int(best.y), 0, 127) + d * 128, Color.RED)
				n += 1
			res["%s_%s" % [anim, dirs[d]]] = list
	over.save_png("res://docs/previews/_tips.png")
	var f := FileAccess.open("res://data/rod_tips.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(res))
	quit()
