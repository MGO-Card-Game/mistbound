class_name PixelUI
extends RefCounted
## Pixel-art UI pieces built at the stage's art scale, so panels share the world's grid.

const Art = preload("res://scripts/art/pixel_art.gd")
const Canvas = preload("res://scripts/art/pixel_canvas.gd")

const UNIT := 3
## 5x7 uppercase glyphs for the logotype ('#' = lit).
const GLYPHS := {
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}

static var _cache: Dictionary = {}


## Bevelled 9-slice panel with chamfered corners. `inset` flips the bevel (pressed/fields).
static func box(fill: Color, border: Color, padding_x: int = 14, padding_y: int = 10, inset: bool = false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _box_texture(fill, border, inset)
	style.set_texture_margin_all(3 * UNIT)
	style.content_margin_left = padding_x
	style.content_margin_right = padding_x
	style.content_margin_top = padding_y
	style.content_margin_bottom = padding_y
	return style


## Segmented bar fill: lit cells separated by dark seams every 3 art pixels.
static func bar(fill: Color) -> StyleBoxTexture:
	var key := "bar:" + fill.to_html()
	if not _cache.has(key):
		var c := Canvas.new(3, 3, fill)
		c.vline(2, 0, 2, fill.darkened(0.45))
		c.hline(0, 1, 0, fill.lightened(0.25))
		_cache[key] = _upscale(c.image)
	var style := StyleBoxTexture.new()
	style.texture = _cache[key]
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style


static func logotype(text: String, scale: int, face: Color, shade: Color) -> ImageTexture:
	var width := text.length() * 6 - 1
	var c := Canvas.new(width + 1, 8)
	for pass_index in range(2):
		for index in range(text.length()):
			var glyph: Array = GLYPHS.get(text[index], GLYPHS[" "])
			for y in range(7):
				var row: String = glyph[y]
				for x in range(5):
					if row[x] != "#":
						continue
					if pass_index == 0:
						c.px(index * 6 + x + 1, y + 1, shade)
					else:
						# Top rows catch the light; the rest fade toward the fog.
						c.px(index * 6 + x, y, face.lightened(0.18) if y < 2 else (face if y < 5 else face.darkened(0.18)))
	var image := c.image
	image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


## Diagonal hazard stripes, tiled horizontally.
static func hazard_strip() -> ImageTexture:
	if not _cache.has("hazard"):
		var c := Canvas.new(6, 2, Art.INK)
		for x in range(6):
			for y in range(2):
				if posmod(x + y, 6) < 3:
					c.px(x, y, Art.HAZARD)
		_cache["hazard"] = _upscale(c.image)
	return _cache["hazard"]


static func _box_texture(fill: Color, border: Color, inset: bool) -> ImageTexture:
	var key := "%s:%s:%s" % [fill.to_html(), border.to_html(), inset]
	if _cache.has(key):
		return _cache[key]
	var size := 8
	var c := Canvas.new(size, size, fill)
	var light := fill.lightened(0.1) if not inset else fill.darkened(0.3)
	var dark := fill.darkened(0.3) if not inset else fill.lightened(0.06)
	c.hline(1, size - 2, 1, light)
	c.vline(1, 1, size - 2, light)
	c.hline(2, size - 2, size - 2, dark)
	c.vline(size - 2, 2, size - 2, dark)
	c.frame(0, 0, size, size, border)
	for corner in [Vector2i(0, 0), Vector2i(size - 1, 0), Vector2i(0, size - 1), Vector2i(size - 1, size - 1)]:
		c.image.set_pixel(corner.x, corner.y, Color(0, 0, 0, 0))
	var texture := _upscale(c.image)
	_cache[key] = texture
	return texture


static func _upscale(image: Image) -> ImageTexture:
	var copy: Image = image.duplicate()
	copy.resize(image.get_width() * UNIT, image.get_height() * UNIT, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(copy)
