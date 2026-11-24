extends SceneTree
# La calibración está en Blender. Dibuja sus puntos sobre los sprites para revisar el sedal.
func _initialize() -> void:
	var tips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rod_tips.json"))
	var dirs := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	var size := 192
	var over := Image.create(size * 8, size * dirs.size(), false, Image.FORMAT_RGBA8)
	for d in dirs.size():
		var key := "fish_wait_" + dirs[d]
		for i in tips[key].size():
			var img := Image.load_from_file("res://art/hechicero/%s_%02d.png" % [key, i])
			var cell := Vector2i(i, d) * size
			over.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), cell)
			var point: Array = tips[key][i]
			var tip := Vector2i(roundi(point[0]), roundi(point[1])) + Vector2i(32, 32)
			assert(Rect2i(Vector2i.ZERO, img.get_size()).has_point(tip))
			over.fill_rect(Rect2i(cell + tip - Vector2i.ONE, Vector2i(3, 3)), Color.RED)
	over.save_png("res://docs/previews/_tips.png")
	quit()
