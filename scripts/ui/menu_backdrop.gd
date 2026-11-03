class_name MenuBackdrop
extends Control
## Title-screen panorama: a recovery team walking toward a fogged facility skyline.
## Painted once at art resolution, upscaled with nearest filtering, fog drifts on top.

const Art = preload("res://scripts/art/pixel_art.gd")
const Canvas = preload("res://scripts/art/pixel_canvas.gd")
const FogShader = preload("res://scripts/world/fog.gdshader")

const ART_SIZE := Vector2i(427, 267)
const HORIZON := 168
const BEACON := Vector2i(84, 52)

var _picture: TextureRect
var _beacon: ColorRect
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture = TextureRect.new()
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() != "headless":
		_picture.texture = ImageTexture.create_from_image(_paint())
	add_child(_picture)
	var fog := ColorRect.new()
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FogShader
	material.set_shader_parameter("focus", Vector2(-100000, -100000))
	material.set_shader_parameter("fog_color", Color("6f918a"))
	material.set_shader_parameter("density", 0.34)
	material.set_shader_parameter("ceiling", 0.4)
	material.set_shader_parameter("art_pixel", float(Art.SCALE))
	material.set_shader_parameter("light_count", 0)
	material.set_shader_parameter("lights", PackedVector3Array())
	fog.material = material
	add_child(fog)
	_beacon = ColorRect.new()
	_beacon.color = Art.WARN_LIGHT
	_beacon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_beacon)


func _process(delta: float) -> void:
	_clock += delta
	if not is_visible_in_tree():
		return
	# Keep the blinking mast light glued to the covered, upscaled picture.
	var scale_factor := maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	var offset := (size - Vector2(ART_SIZE) * scale_factor) * 0.5
	_beacon.position = offset + Vector2(BEACON) * scale_factor
	_beacon.size = Vector2.ONE * scale_factor * 2.0
	_beacon.visible = fmod(_clock, 1.4) < 0.5


func _paint() -> Image:
	var c := Canvas.new(ART_SIZE.x, ART_SIZE.y, Art.NIGHT)
	# Sky: dithered bands from night to the fog glow above the horizon.
	var bands := [Color("0d1417"), Color("111b1e"), Color("152226"), Color("1b2b2e"), Color("223634"), Color("2b4440")]
	for index in range(bands.size()):
		var top := int(index * HORIZON / float(bands.size()))
		c.rect(0, top, ART_SIZE.x, HORIZON - top, bands[index])
		if index > 0:
			c.dither_rect(0, top - 2, ART_SIZE.x, 2, bands[index], index)
	# Far skyline.
	var far := Color("17221f")
	c.rect(0, HORIZON - 14, ART_SIZE.x, 14, far)
	for block in [Rect2i(18, 120, 40, 34), Rect2i(150, 128, 28, 26), Rect2i(196, 110, 54, 44), Rect2i(330, 124, 36, 30), Rect2i(380, 102, 22, 52)]:
		c.rect(block.position.x, block.position.y, block.size.x, block.size.y, far)
	_cooling_tower(c, 280, HORIZON - 14, far)
	for x in [214, 226, 238]:
		c.rect(x, 82 + (x % 3) * 6, 5, 40, far)
		c.rect(x - 1, 82 + (x % 3) * 6, 7, 2, Color("1e2b28"))
	_mast(c, BEACON.x + 1, BEACON.y + 2, HORIZON - 14, far)
	# Lit windows scattered across the dead skyline.
	for index in range(18):
		var at := Vector2i(20 + (index * 53) % 380, 112 + (index * 29) % 38)
		if c.image.get_pixel(at.x, at.y) == far:
			c.px(at.x, at.y, Art.LAMP if index % 4 != 0 else Art.FOG_LIGHT)
	# Thick fog bank swallowing the base of the facility.
	for y in range(HORIZON - 26, HORIZON + 12):
		var strength := 1.0 - absf(y - (HORIZON - 6)) / 20.0
		for x in range(ART_SIZE.x):
			if float((x * 7 + y * 13) % 17) / 17.0 < strength * 0.75:
				c.px(x, y, Color(Art.FOG, 0.55))
	# Near ground, road and fence.
	c.rect(0, HORIZON + 4, ART_SIZE.x, ART_SIZE.y - HORIZON - 4, Color("121a1c"))
	for y in range(HORIZON + 4, ART_SIZE.y):
		var t := float(y - HORIZON) / float(ART_SIZE.y - HORIZON)
		var half := int(6 + t * 90)
		c.hline(220 - half, 220 + half, y, Color("1b2326"))
		if y % 6 < 3:
			c.hline(220 - 1, 220 + int(t * 2), y, Color(Art.HAZARD, 0.5 * t))
	for x in range(0, ART_SIZE.x):
		var top := HORIZON + 22
		if x > 150 and x < 290:
			continue
		c.px(x, top, Art.SLATE)
		if (x + top) % 2 == 0:
			c.px(x, top + 2, Color(Art.SLATE, 0.6))
			c.px(x, top + 4, Color(Art.SLATE, 0.6))
		if x % 14 == 0:
			c.vline(x, top - 3, top + 8, Art.STEEL)
	c.rect(147, HORIZON + 14, 3, 18, Art.HAZARD)
	c.rect(291, HORIZON + 14, 3, 18, Art.HAZARD)
	# The recovery team, headlamps on, heading in.
	for member in [Vector2i(206, 236), Vector2i(222, 230), Vector2i(236, 238)]:
		_walker(c, member)
	return c.image


func _cooling_tower(c: Canvas, center: int, base: int, color: Color) -> void:
	for y in range(48):
		var t := float(y) / 47.0
		# Hyperboloid profile: the waist sits a little below mid-height.
		var half := int(13.0 + 10.0 * pow((t - 0.62) * 1.6, 2.0))
		c.hline(center - half, center + half, base - 48 + y, color)
	c.hline(center - 16, center + 16, base - 48, Color("22302c"))
	for index in range(6):
		c.px(center - 6 + index * 3, base - 52 - index % 2, Color(Art.FOG_LIGHT, 0.25))


func _mast(c: Canvas, x: int, top: int, base: int, color: Color) -> void:
	for y in range(top, base):
		var t := float(y - top) / float(base - top)
		var half := int(1 + t * 7)
		c.px(x - half, y, color)
		c.px(x + half, y, color)
		if y % 6 == 0:
			c.hline(x - half, x + half, y, color)
			c.line(Vector2i(x - half, y), Vector2i(x + half, mini(base, y + 6)), color)


func _walker(c: Canvas, foot: Vector2i) -> void:
	c.rect(foot.x - 1, foot.y - 7, 3, 5, Art.INK)
	c.rect(foot.x - 1, foot.y - 9, 3, 2, Art.INK)
	c.px(foot.x - 1, foot.y - 1, Art.INK)
	c.px(foot.x + 1, foot.y - 1, Art.INK)
	c.px(foot.x - 2, foot.y - 6, Art.RUST)
	c.px(foot.x + 1, foot.y - 8, Art.LAMP)
	# Headlamp beam reaching up the road.
	for step in range(1, 9):
		c.px(foot.x + 1 + int(step / 3.0), foot.y - 8 - step, Color(Art.LAMP, 0.35 - step * 0.035))
