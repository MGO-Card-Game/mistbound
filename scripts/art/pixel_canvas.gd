class_name PixelCanvas
extends RefCounted
## Small raster painter for procedural pixel art. All coordinates are art pixels.

var image: Image
var width: int
var height: int


func _init(w: int, h: int, fill: Color = Color(0, 0, 0, 0)) -> void:
	width = w
	height = h
	image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	image.fill(fill)


func to_texture() -> ImageTexture:
	return ImageTexture.create_from_image(image)


func px(x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	if color.a >= 1.0:
		image.set_pixel(x, y, color)
	elif color.a > 0.0:
		image.set_pixel(x, y, image.get_pixel(x, y).blend(color))


func rect(x: int, y: int, w: int, h: int, color: Color) -> void:
	var area := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, width, height))
	if area.size.x <= 0 or area.size.y <= 0:
		return
	if color.a >= 1.0:
		image.fill_rect(area, color)
		return
	for yy in range(area.position.y, area.end.y):
		for xx in range(area.position.x, area.end.x):
			px(xx, yy, color)


func frame(x: int, y: int, w: int, h: int, color: Color) -> void:
	hline(x, x + w - 1, y, color)
	hline(x, x + w - 1, y + h - 1, color)
	vline(x, y, y + h - 1, color)
	vline(x + w - 1, y, y + h - 1, color)


func hline(x0: int, x1: int, y: int, color: Color) -> void:
	rect(mini(x0, x1), y, absi(x1 - x0) + 1, 1, color)


func vline(x: int, y0: int, y1: int, color: Color) -> void:
	rect(x, mini(y0, y1), 1, absi(y1 - y0) + 1, color)


func line(a: Vector2i, b: Vector2i, color: Color) -> void:
	# Bresenham keeps diagonals one pixel thick.
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var error := dx + dy
	var p := a
	while true:
		px(p.x, p.y, color)
		if p == b:
			return
		var e2 := 2 * error
		if e2 >= dy:
			error += dy
			p.x += sx
		if e2 <= dx:
			error += dx
			p.y += sy


func thick_line(points: Array, color: Color, thickness: int) -> void:
	for index in range(points.size() - 1):
		var a: Vector2i = points[index]
		var b: Vector2i = points[index + 1]
		var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for step in range(steps + 1):
			var t := float(step) / maxf(1.0, float(steps))
			var p := Vector2(a).lerp(Vector2(b), t)
			disc(Vector2i(roundi(p.x), roundi(p.y)), thickness >> 1, color)


func disc(center: Vector2i, radius: int, color: Color) -> void:
	for yy in range(-radius, radius + 1):
		var span := int(sqrt(float(radius * radius - yy * yy)) + 0.35)
		hline(center.x - span, center.x + span, center.y + yy, color)


func ring(center: Vector2i, radius: int, color: Color) -> void:
	var steps := maxi(16, radius * 7)
	var last := Vector2i(-99999, -99999)
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		var p := Vector2i(roundi(center.x + cos(angle) * radius), roundi(center.y + sin(angle) * radius))
		if p != last:
			px(p.x, p.y, color)
			last = p


func ellipse(center: Vector2i, rx: int, ry: int, color: Color) -> void:
	for yy in range(-ry, ry + 1):
		var t := 1.0 - float(yy * yy) / float(maxi(1, ry * ry))
		var span := int(rx * sqrt(maxf(0.0, t)) + 0.35)
		hline(center.x - span, center.x + span, center.y + yy, color)


## Checkerboard dithering; `phase` selects which half of the pattern is painted.
func dither_rect(x: int, y: int, w: int, h: int, color: Color, phase: int = 0) -> void:
	for yy in range(maxi(0, y), mini(height, y + h)):
		for xx in range(maxi(0, x), mini(width, x + w)):
			if (xx + yy + phase) % 2 == 0:
				px(xx, yy, color)


func blit(source: Image, x: int, y: int, flip: bool = false) -> void:
	for yy in range(source.get_height()):
		for xx in range(source.get_width()):
			var color := source.get_pixel(source.get_width() - 1 - xx if flip else xx, yy)
			if color.a > 0.0:
				px(x + xx, y + yy, color)


## Paints a text pixel map; characters missing from `palette` stay transparent.
func stamp(rows: PackedStringArray, palette: Dictionary, x: int, y: int) -> void:
	for yy in range(rows.size()):
		var row := rows[yy]
		for xx in range(row.length()):
			var key := row[xx]
			if palette.has(key):
				px(x + xx, y + yy, palette[key])
