class_name ZoneArt
extends RefCounted
## Bakes each area's static ground and props into one pixel image (1 px = PixelArt.SCALE
## world units). Props sit on the zone's collision rects; animated parts stay in ZoneView.

const Art = preload("res://scripts/art/pixel_art.gd")
const Canvas = preload("res://scripts/art/pixel_canvas.gd")

const ORIGIN := Vector2(-888.0, -504.0)
const IMAGE_SIZE := Vector2i(592, 336)
const TILE := 16

static var _baked: Dictionary = {}


static func texture(zone_id: String, blockers: Array = []) -> Texture2D:
	var key := zone_id + ":tex"
	if not _baked.has(key):
		_baked[key] = ImageTexture.create_from_image(bake(zone_id, blockers))
	return _baked[key]


static func bake(zone_id: String, blockers: Array = []) -> Image:
	if _baked.has(zone_id):
		return _baked[zone_id]
	var c := Canvas.new(IMAGE_SIZE.x, IMAGE_SIZE.y, Art.NIGHT)
	var rects: Array[Rect2i] = []
	for rect in blockers:
		if rect is Rect2:
			rects.append(_rect(rect))
	match zone_id:
		"wilds": _bake_wilds(c, rects)
		"mine": _bake_mine(c, rects)
		"crypt": _bake_crypt(c, rects)
		_: _bake_camp(c, rects)
	_baked[zone_id] = c.image
	return c.image


## World point → art pixel inside the baked image.
static func p(world: Vector2) -> Vector2i:
	var local := (world - ORIGIN) / Art.SCALE
	return Vector2i(floori(local.x), floori(local.y))


static func _rect(world: Rect2) -> Rect2i:
	var a := p(world.position)
	var b := p(world.end)
	return Rect2i(a, b - a)


static func _hash(x: int, y: int, salt: int) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 2147483647) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


# --- Tiles -------------------------------------------------------------------

static func _tile(kind: String, variant: int) -> Image:
	var key := "tile:%s:%d" % [kind, variant]
	if _baked.has(key):
		return _baked[key]
	var t := Canvas.new(TILE, TILE)
	var salt := variant * 31 + kind.hash()
	match kind:
		"slab":
			t.rect(0, 0, TILE, TILE, Color("3d4646"))
			_speckle(t, Color("464f4f"), Color("343c3c"), salt, 0.18)
			t.hline(0, TILE - 1, 0, Color("2b3232"))
			t.vline(0, 0, TILE - 1, Color("2b3232"))
			t.hline(1, TILE - 1, 1, Color("4a5353"))
			if variant % 3 == 1:
				t.line(Vector2i(3, 5), Vector2i(9, 9), Color("2e3535"))
				t.line(Vector2i(9, 9), Vector2i(12, 8), Color("2e3535"))
		"asphalt":
			t.rect(0, 0, TILE, TILE, Color("272b2d"))
			_speckle(t, Color("303537"), Color("1f2224"), salt, 0.22)
			if variant % 4 == 2:
				t.line(Vector2i(2, 12), Vector2i(7, 8), Color("1a1d1f"))
				t.line(Vector2i(7, 8), Vector2i(8, 3), Color("1a1d1f"))
		"gravel":
			t.rect(0, 0, TILE, TILE, Color("353a36"))
			_speckle(t, Color("454b44"), Color("2a2e2b"), salt, 0.35)
		"grass":
			t.rect(0, 0, TILE, TILE, Color("333a2d"))
			_speckle(t, Color("3b4433"), Color("2b3127"), salt, 0.3)
			for index in range(3 + variant % 3):
				var x := int(_hash(index, variant, salt) * 14) + 1
				var y := int(_hash(variant, index, salt) * 12) + 3
				t.px(x, y, Art.MOSS_LIGHT)
				t.px(x - 1, y - 1, Art.MOSS)
				t.px(x + 1, y - 2, Art.MOSS)
		"rock":
			t.rect(0, 0, TILE, TILE, Color("2e2a27"))
			_speckle(t, Color("3a3430"), Color("24211f"), salt, 0.3)
			if variant % 3 == 0:
				t.rect(4, 6, 5, 3, Color("3f3934"))
				t.hline(4, 8, 6, Color("4a433c"))
		"grate":
			t.rect(0, 0, TILE, TILE, Color("1d2224"))
			for y in range(1, TILE, 3):
				t.hline(0, TILE - 1, y, Color("4a5355"))
			for x in range(0, TILE, 8):
				t.vline(x, 0, TILE - 1, Color("5c6668"))
		"lab":
			t.rect(0, 0, TILE, TILE, Color("3a4049"))
			_speckle(t, Color("3f4650"), Color("353a42"), salt, 0.1)
			t.hline(0, TILE - 1, 0, Color("2a2f36"))
			t.vline(0, 0, TILE - 1, Color("2a2f36"))
			t.hline(0, TILE - 1, 8, Color("323840"))
			t.vline(8, 0, TILE - 1, Color("323840"))
			if variant % 5 == 3:
				t.rect(2, 2, 5, 5, Color("444b55"))
	_baked[key] = t.image
	return t.image


static func _speckle(t: Canvas, light: Color, dark: Color, salt: int, amount: float) -> void:
	for y in range(TILE):
		for x in range(TILE):
			var value := _hash(x, y, salt)
			if value < amount * 0.5:
				t.px(x, y, dark)
			elif value > 1.0 - amount * 0.5:
				t.px(x, y, light)


## Lays tiles over a pixel rect; `pick` maps tile coords to a tile image.
static func _tile_fill(c: Canvas, area: Rect2i, pick: Callable) -> void:
	for ty in range(floori(float(area.position.y) / TILE), ceili(float(area.end.y) / TILE)):
		for tx in range(floori(float(area.position.x) / TILE), ceili(float(area.end.x) / TILE)):
			var tile: Image = pick.call(tx, ty)
			var at := Vector2i(tx * TILE, ty * TILE)
			var clip := Rect2i(at, Vector2i(TILE, TILE)).intersection(area)
			if clip.size.x > 0 and clip.size.y > 0:
				c.image.blit_rect(tile, Rect2i(clip.position - at, clip.size), clip.position)


## Organic patches of another material with dithered, irregular edges.
static func _patches(c: Canvas, area: Rect2i, kind: String, count: int, salt: int, min_radius: int, max_radius: int) -> void:
	for index in range(count):
		var center := Vector2i(area.position.x + int(_hash(index, salt, 5) * area.size.x), area.position.y + int(_hash(salt, index, 6) * area.size.y))
		var rx := min_radius + int(_hash(index, index, salt) * (max_radius - min_radius))
		var ry := maxi(4, int(rx * (0.45 + _hash(salt, salt, index) * 0.4)))
		var tile := _tile(kind, index % 6)
		for y in range(maxi(area.position.y, center.y - ry), mini(area.end.y, center.y + ry + 1)):
			for x in range(maxi(area.position.x, center.x - rx), mini(area.end.x, center.x + rx + 1)):
				var dx := float(x - center.x) / rx
				var dy := float(y - center.y) / ry
				var wobble := 0.85 + 0.3 * _hash(x >> 2, y >> 2, salt + index)
				var d := sqrt(dx * dx + dy * dy) / wobble
				if d < 0.78 or (d < 1.0 and (x + y) % 2 == 0 and _hash(x, y, salt) > (d - 0.78) * 4.0):
					c.image.set_pixel(x, y, tile.get_pixel(posmod(x, TILE), posmod(y, TILE)))


static func _walk_area() -> Rect2i:
	return _rect(Rect2(-880, -500, 1760, 1000))


# --- Shared props -------------------------------------------------------------

static func _shadow(c: Canvas, r: Rect2i, depth: int = 3) -> void:
	c.rect(r.position.x + depth, r.position.y + depth, r.size.x, r.size.y, Color(0, 0, 0, 0.35))


## A 3/4-view box building: roof on top, front wall below, outlined.
static func _box_building(c: Canvas, r: Rect2i, roof: Color, wall: Color, ribbed: bool = true) -> int:
	_shadow(c, r, 4)
	var roof_h := int(r.size.y * 0.58)
	c.rect(r.position.x, r.position.y, r.size.x, roof_h, roof)
	if ribbed:
		for x in range(r.position.x + 2, r.end.x - 1, 3):
			c.vline(x, r.position.y + 2, r.position.y + roof_h - 2, roof.darkened(0.18))
	c.hline(r.position.x + 1, r.end.x - 2, r.position.y + 1, roof.lightened(0.22))
	c.rect(r.position.x, r.position.y + roof_h, r.size.x, r.size.y - roof_h, wall)
	c.hline(r.position.x, r.end.x - 1, r.position.y + roof_h, wall.darkened(0.35))
	for x in range(r.position.x + 3, r.end.x - 2, 4):
		c.vline(x, r.position.y + roof_h + 2, r.end.y - 2, wall.darkened(0.12))
	c.frame(r.position.x, r.position.y, r.size.x, r.size.y, Art.INK)
	return r.position.y + roof_h


static func _hazard_band(c: Canvas, x: int, y: int, w: int, h: int) -> void:
	c.rect(x, y, w, h, Art.INK)
	for xx in range(x, x + w):
		for yy in range(y, y + h):
			if posmod(xx + yy, 6) < 3:
				c.px(xx, yy, Art.HAZARD)


static func _barrel(c: Canvas, at: Vector2i, body: Color) -> void:
	c.rect(at.x + 1, at.y + 2, 6, 3, Color(0, 0, 0, 0.3))
	c.rect(at.x, at.y - 6, 6, 8, body)
	c.ellipse(Vector2i(at.x + 3, at.y - 6), 3, 1, body.lightened(0.25))
	c.hline(at.x, at.x + 5, at.y - 3, body.darkened(0.3))
	c.frame(at.x, at.y - 7, 6, 9, Art.INK)


static func _crate(c: Canvas, at: Vector2i, size: int = 7) -> void:
	c.rect(at.x + 2, at.y + 2, size, size, Color(0, 0, 0, 0.3))
	c.rect(at.x, at.y, size, size, Art.RUST_LIGHT)
	c.line(at, at + Vector2i(size - 1, size - 1), Art.RUST)
	c.line(Vector2i(at.x + size - 1, at.y), Vector2i(at.x, at.y + size - 1), Art.RUST)
	c.frame(at.x, at.y, size, size, Art.INK)


static func _dead_tree(c: Canvas, at: Vector2i, height: int, salt: int) -> void:
	c.ellipse(at + Vector2i(2, 1), 5, 2, Color(0, 0, 0, 0.3))
	var trunk := Color("3b3530")
	c.rect(at.x - 1, at.y - height, 2, height + 1, trunk)
	for branch in range(3):
		var y := at.y - height + 2 + branch * int(height / 3.0)
		var side := 1 if (branch + salt) % 2 == 0 else -1
		var length := 3 + int(_hash(branch, salt, 9) * 4)
		c.line(Vector2i(at.x, y + 2), Vector2i(at.x + side * length, y - 1), trunk)
		c.px(at.x + side * length, y - 2, trunk.lightened(0.15))
	c.vline(at.x - 1, at.y - height, at.y, trunk.lightened(0.12))


static func _pole(c: Canvas, at: Vector2i, height: int) -> void:
	c.rect(at.x + 1, at.y, 4, 1, Color(0, 0, 0, 0.35))
	c.rect(at.x, at.y - height, 2, height + 1, Art.STEEL)
	c.vline(at.x, at.y - height, at.y, Art.GRAY_LIGHT)
	c.rect(at.x - 3, at.y - height, 8, 2, Art.SLATE)


static func _floodlight(c: Canvas, at: Vector2i) -> void:
	c.ellipse(at + Vector2i(1, 1), 3, 1, Color(0, 0, 0, 0.35))
	c.rect(at.x, at.y - 12, 2, 13, Art.STEEL)
	c.rect(at.x - 2, at.y - 15, 6, 4, Art.SLATE)
	c.hline(at.x - 1, at.x + 2, at.y - 12, Art.LAMP)
	c.frame(at.x - 2, at.y - 15, 6, 4, Art.INK)


static func _sandbags(c: Canvas, at: Vector2i, count: int) -> void:
	for index in range(count):
		var x := at.x + index * 5
		c.rect(x + 1, at.y + 2, 5, 3, Color(0, 0, 0, 0.3))
		c.ellipse(Vector2i(x + 2, at.y), 3, 2, Color("6d6550"))
		c.hline(x, x + 3, at.y - 1, Color("8a8066"))
	for index in range(count - 1):
		var x := at.x + index * 5 + 2
		c.ellipse(Vector2i(x + 2, at.y - 3), 3, 2, Color("7b7259"))
		c.hline(x, x + 3, at.y - 4, Color("958b70"))


static func _fence(c: Canvas, y: int, x0: int, x1: int, gap: Vector2i = Vector2i(-1, -1)) -> void:
	for x in range(x0, x1 + 1):
		if x >= gap.x and x <= gap.y:
			continue
		c.px(x, y - 6, Art.GRAY)
		c.px(x, y, Art.STEEL)
		if posmod(x, 2) == 0:
			c.px(x, y - 4, Color(Art.GRAY, 0.6))
			c.px(x, y - 2, Color(Art.GRAY, 0.6))
		else:
			c.px(x, y - 3, Color(Art.GRAY, 0.6))
			c.px(x, y - 1, Color(Art.GRAY, 0.6))
		if posmod(x, 12) == 0:
			c.vline(x, y - 8, y + 1, Art.GRAY_LIGHT)


static func _puddle(c: Canvas, at: Vector2i, rx: int, ry: int) -> void:
	c.ellipse(at, rx, ry, Color("1d2e30"))
	c.ellipse(at + Vector2i(0, -1), rx - 1, maxi(1, ry - 1), Color("223a3c"))
	c.hline(at.x - rx + 2, at.x - 1, at.y - 1, Color(Art.FOG_LIGHT, 0.35))


static func _rubble(c: Canvas, at: Vector2i, salt: int) -> void:
	for index in range(5):
		var offset := Vector2i(int(_hash(index, salt, 1) * 9) - 4, int(_hash(salt, index, 2) * 5) - 2)
		c.rect(at.x + offset.x, at.y + offset.y, 2, 2, Art.GRAY if index % 2 == 0 else Art.STEEL)


static func _dashes(c: Canvas, a: Vector2i, b: Vector2i, color: Color, dash: int = 4, gap: int = 4) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for step in range(steps + 1):
		if posmod(step, dash + gap) < dash:
			var point := Vector2(a).lerp(Vector2(b), float(step) / maxf(1.0, steps))
			c.px(roundi(point.x), roundi(point.y), color)


# --- Outpost ------------------------------------------------------------------

static func _bake_camp(c: Canvas, blockers: Array[Rect2i]) -> void:
	var area := _walk_area()
	_tile_fill(c, area, func(tx: int, ty: int) -> Image: return _tile("slab", int(_hash(tx, ty, 11) * 6)))
	_patches(c, area, "gravel", 26, 11, 10, 26)
	# Main road north to the gate and the apron in front of the buildings.
	var road := _rect(Rect2(-60, -500, 120, 1000))
	_tile_fill(c, road, func(tx: int, ty: int) -> Image: return _tile("asphalt", posmod(tx * 7 + ty * 3, 6)))
	c.vline(road.position.x + 1, road.position.y, road.end.y, Color(Art.BONE, 0.5))
	c.vline(road.end.x - 2, road.position.y, road.end.y, Color(Art.BONE, 0.5))
	_dashes(c, Vector2i(road.get_center().x, road.position.y), Vector2i(road.get_center().x, road.end.y), Art.HAZARD, 5, 5)
	var apron := _rect(Rect2(-575, 140, 1150, 60))
	_tile_fill(c, apron, func(tx: int, ty: int) -> Image: return _tile("asphalt", posmod(tx * 5 + ty, 6)))
	c.hline(apron.position.x, apron.end.x, apron.position.y, Color(Art.HAZARD, 0.55))
	# Staging pad around the generator.
	var pad := p(Vector2(0, 85))
	c.disc(pad, 50, Color("434b49"))
	c.ring(pad, 50, Art.HAZARD)
	c.ring(pad, 47, Color(Art.HAZARD, 0.4))
	for index in range(16):
		var angle := TAU * index / 16.0
		var dir := Vector2(cos(angle), sin(angle))
		if index % 2 == 0:
			c.line(pad + Vector2i((dir * 44).round()), pad + Vector2i((dir * 48).round()), Color(Art.HAZARD, 0.7))
	_generator(c, p(Vector2(0, 50)))
	# Fence along the north edge, opened at the road.
	_fence(c, p(Vector2(0, -470)).y, area.position.x, area.end.x, Vector2i(road.position.x - 1, road.end.x + 1))
	c.rect(road.position.x - 4, p(Vector2(0, -470)).y - 10, 3, 11, Art.HAZARD)
	c.rect(road.end.x + 1, p(Vector2(0, -470)).y - 10, 3, 11, Art.HAZARD)
	if blockers.size() >= 3:
		_warehouse(c, blockers[0])
		_workshop(c, blockers[1])
		_observatory(c, blockers[2])
	for at in [Vector2(-155, -95), Vector2(155, -95), Vector2(-145, 260), Vector2(145, 260)]:
		_floodlight(c, p(at))
	_sandbags(c, p(Vector2(-300, 330)), 7)
	_sandbags(c, p(Vector2(200, 330)), 7)
	for at in [Vector2(-350, 120), Vector2(-332, 128), Vector2(600, 110), Vector2(318, -60)]:
		_barrel(c, p(at), Art.RUST_LIGHT if int(at.x) % 2 == 0 else Art.FOG_DARK.lightened(0.15))
	for at in [Vector2(-640, 160), Vector2(-616, 172), Vector2(330, 120), Vector2(590, -60)]:
		_crate(c, p(at))
	for index in range(9):
		_dead_tree(c, p(Vector2(-830 + (index % 2) * 60, -380 + index * 100)), 14 + index % 3 * 3, index)
		_dead_tree(c, p(Vector2(800 + (index % 2) * 40, -400 + index * 100)), 13 + (index + 1) % 3 * 3, index + 5)


static func _generator(c: Canvas, at: Vector2i) -> void:
	var r := Rect2i(at.x - 10, at.y - 6, 20, 11)
	_shadow(c, r, 2)
	c.rect(r.position.x, r.position.y, r.size.x, r.size.y, Color("4f6b55"))
	c.rect(r.position.x, r.position.y, r.size.x, 4, Color("6a8a70"))
	for x in range(r.position.x + 2, r.end.x - 6, 2):
		c.vline(x, r.position.y + 5, r.end.y - 2, Color("3a5040"))
	c.rect(r.end.x - 5, r.position.y + 5, 3, 3, Art.SLATE)
	c.frame(r.position.x, r.position.y, r.size.x, r.size.y, Art.INK)
	c.rect(at.x + 4, r.position.y - 4, 2, 4, Art.STEEL)
	c.line(Vector2i(r.position.x, at.y + 3), Vector2i(r.position.x - 14, at.y + 7), Art.SLATE_DARK)
	c.line(Vector2i(r.position.x - 14, at.y + 7), Vector2i(r.position.x - 26, at.y + 7), Art.SLATE_DARK)


static func _warehouse(c: Canvas, r: Rect2i) -> void:
	var wall_y := _box_building(c, r, Color("4d7069"), Color("38544f"))
	var door := Rect2i(r.get_center().x - 10, wall_y + 3, 20, r.end.y - wall_y - 3)
	c.rect(door.position.x, door.position.y, door.size.x, door.size.y, Color("2a3b38"))
	for y in range(door.position.y + 1, door.end.y, 2):
		c.hline(door.position.x + 1, door.end.x - 2, y, Color("324542"))
	_hazard_band(c, door.position.x, door.end.y - 2, door.size.x, 2)
	c.frame(door.position.x - 1, door.position.y - 1, door.size.x + 2, door.size.y + 1, Art.INK)
	# Containment placard.
	c.rect(r.position.x + 6, wall_y + 4, 9, 7, Art.HAZARD)
	c.frame(r.position.x + 6, wall_y + 4, 9, 7, Art.INK)
	c.disc(Vector2i(r.position.x + 10, wall_y + 7), 1, Art.INK)
	c.rect(r.end.x - 14, r.position.y + 4, 8, 5, Art.SLATE)
	c.frame(r.end.x - 14, r.position.y + 4, 8, 5, Art.INK)


static func _workshop(c: Canvas, r: Rect2i) -> void:
	var wall_y := _box_building(c, r, Color("8a5a35"), Color("6a4128"))
	var bay := Rect2i(r.position.x + 8, wall_y + 2, r.size.x - 30, r.end.y - wall_y - 2)
	c.rect(bay.position.x, bay.position.y, bay.size.x, bay.size.y, Color("1d1a18"))
	c.hline(bay.position.x, bay.end.x - 1, bay.position.y, Art.INK)
	# Workbench and tools visible through the open bay.
	c.rect(bay.position.x + 2, bay.end.y - 5, bay.size.x - 4, 3, Art.RUST_LIGHT)
	c.rect(bay.position.x + 4, bay.end.y - 8, 2, 3, Art.GRAY_LIGHT)
	c.rect(bay.position.x + 9, bay.end.y - 9, 4, 4, Art.WARN)
	c.rect(bay.position.x + 15, bay.end.y - 7, 6, 2, Art.STEEL)
	_hazard_band(c, bay.position.x, bay.end.y - 1, bay.size.x, 1)
	c.rect(r.end.x - 16, wall_y + 4, 10, 6, Art.BONE)
	c.hline(r.end.x - 15, r.end.x - 8, wall_y + 6, Art.WARN)
	c.hline(r.end.x - 15, r.end.x - 10, wall_y + 8, Art.SLATE)
	c.frame(r.end.x - 16, wall_y + 4, 10, 6, Art.INK)
	# Roof vent units.
	for x in [r.position.x + 10, r.position.x + 30]:
		c.rect(x, r.position.y + 5, 8, 6, Art.STEEL)
		c.hline(x + 1, x + 6, r.position.y + 7, Art.SLATE)
		c.frame(x, r.position.y + 5, 8, 6, Art.INK)


static func _observatory(c: Canvas, r: Rect2i) -> void:
	var body := Rect2i(r.position.x, r.position.y + 8, r.size.x - 14, r.size.y - 8)
	var wall_y := _box_building(c, body, Color("5d6a66"), Color("454f4c"), false)
	for x in [body.position.x + 6, body.position.x + 22]:
		c.rect(x, wall_y + 3, 8, 6, Color("8fb7ad"))
		c.hline(x, x + 7, wall_y + 3, Art.FOG_PALE)
		c.frame(x - 1, wall_y + 2, 10, 8, Art.INK)
	c.rect(body.end.x - 12, wall_y + 2, 7, body.end.y - wall_y - 2, Art.SLATE_DARK)
	# Weather mast with a radar dish and wind cups.
	var mast_x := r.end.x - 7
	c.rect(mast_x, r.position.y - 4, 2, r.size.y + 4, Art.STEEL)
	for y in range(r.position.y, r.end.y, 4):
		c.line(Vector2i(mast_x - 2, y), Vector2i(mast_x + 3, y + 3), Art.GRAY)
	c.ellipse(Vector2i(mast_x - 4, r.position.y + 2), 5, 3, Art.GRAY_LIGHT)
	c.ellipse(Vector2i(mast_x - 4, r.position.y + 2), 3, 2, Art.GRAY)
	c.hline(mast_x - 3, mast_x + 5, r.position.y - 4, Art.INK)
	c.px(mast_x - 3, r.position.y - 5, Art.BONE)
	c.px(mast_x + 5, r.position.y - 5, Art.BONE)


# --- Outer fog zone -----------------------------------------------------------

static func _bake_wilds(c: Canvas, blockers: Array[Rect2i]) -> void:
	var area := _walk_area()
	_tile_fill(c, area, func(tx: int, ty: int) -> Image: return _tile("grass", int(_hash(tx, ty, 23) * 6)))
	_patches(c, area, "gravel", 34, 23, 8, 24)
	var trunk: Array = [p(Vector2(0, 520)), p(Vector2(0, 175))]
	var west: Array = [p(Vector2(0, 175)), p(Vector2(-160, -20)), p(Vector2(-620, -285))]
	var east: Array = [p(Vector2(0, 175)), p(Vector2(160, -20)), p(Vector2(620, -285))]
	for path in [trunk, west, east]:
		c.thick_line(path, Color("1f2224"), 30)
		c.thick_line(path, Color("292d2f"), 26)
	# Broken road edge and faded center markings.
	for index in range(160):
		var at := Vector2i(int(_hash(index, 3, 23) * IMAGE_SIZE.x), int(_hash(3, index, 23) * IMAGE_SIZE.y))
		if c.image.get_pixel(at.x, at.y).is_equal_approx(Color("292d2f")):
			c.rect(at.x, at.y, 2, 1, Color("333735"))
			c.px(at.x + 1, at.y + 1, Color("1b1e20"))
	for path in [trunk, west, east]:
		for index in range(path.size() - 1):
			_dashes(c, path[index], path[index + 1], Color(Art.BONE, 0.3), 4, 6)
	for at in [Vector2(-120, 320), Vector2(260, 260), Vector2(-420, -60), Vector2(470, -40), Vector2(80, -150)]:
		_puddle(c, p(at), 7 + int(at.x) % 3, 3)
	if blockers.size() >= 3:
		_wreck(c, blockers[0], Color("5b4a3c"), false)
		_wreck(c, blockers[1], Color("4b5a5c"), true)
		_beacon(c, blockers[2])
	_bunker(c, p(Vector2(-620, -285)), Color("6a6250"))
	_bunker(c, p(Vector2(620, -285)), Color("5a5e70"))
	_checkpoint(c, p(Vector2(0, 465)))
	# Utility poles along the roads with sagging cables between them.
	var poles: Array[Vector2i] = [p(Vector2(-100, 320)), p(Vector2(-230, 30)), p(Vector2(-450, -150)), p(Vector2(100, 320)), p(Vector2(230, 30)), p(Vector2(450, -150))]
	for index in range(poles.size()):
		_pole(c, poles[index], 20)
		if index % 3 != 2:
			_cable(c, poles[index] + Vector2i(1, -20), poles[index + 1] + Vector2i(1, -20))
	for index in range(12):
		_dead_tree(c, p(Vector2(-830 + (index % 3) * 40, -440 + index * 75)), 13 + index % 4 * 3, index)
		_dead_tree(c, p(Vector2(790 + (index % 2) * 50, -430 + index * 78)), 12 + index % 3 * 4, index + 3)
	for at in [Vector2(-370, 315), Vector2(420, 320), Vector2(-295, -385), Vector2(300, -380)]:
		_dead_tree(c, p(at), 18, int(at.x))
	for index in range(10):
		_rubble(c, p(Vector2(-700 + index * 150, -440 + (index % 3) * 330)), index)
	_barrel(c, p(Vector2(-300, 170)), Art.RUST)
	_barrel(c, p(Vector2(310, 180)), Art.HAZARD.darkened(0.3))
	_sign(c, p(Vector2(-60, 250)))


static func _cable(c: Canvas, a: Vector2i, b: Vector2i) -> void:
	var steps := maxi(1, absi(b.x - a.x))
	var last := a
	for step in range(1, steps + 1):
		var t := float(step) / steps
		var point := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t) + sin(t * PI) * 5.0))
		c.line(last, point, Color(Art.INK, 0.8))
		last = point


static func _wreck(c: Canvas, r: Rect2i, body: Color, facing_left: bool) -> void:
	_shadow(c, r, 3)
	var car := Rect2i(r.position.x + 1, r.position.y + 3, r.size.x - 2, r.size.y - 6)
	c.rect(car.position.x + 2, car.position.y, car.size.x - 4, car.size.y, body)
	c.rect(car.position.x, car.position.y + 3, car.size.x, car.size.y - 6, body)
	# Rust bloom and a caved-in roof.
	for index in range(18):
		var at := car.position + Vector2i(int(_hash(index, r.position.x, 4) * car.size.x), int(_hash(r.position.y, index, 4) * car.size.y))
		c.px(at.x, at.y, Art.RUST if index % 2 == 0 else Art.RUST_LIGHT)
	var glass_x := car.position.x + (4 if facing_left else car.size.x - 12)
	c.rect(glass_x, car.position.y + 3, 8, car.size.y - 6, Color("223234"))
	c.line(Vector2i(glass_x + 1, car.position.y + 4), Vector2i(glass_x + 6, car.end.y - 5), Color(Art.FOG_LIGHT, 0.5))
	c.rect(car.get_center().x - 5, car.position.y + 4, 10, car.size.y - 8, body.darkened(0.25))
	c.frame(car.position.x, car.position.y + 3, car.size.x, car.size.y - 6, Art.INK)
	for wheel in [Vector2i(car.position.x + 4, car.position.y + 1), Vector2i(car.end.x - 8, car.position.y + 1), Vector2i(car.position.x + 4, car.end.y - 3), Vector2i(car.end.x - 8, car.end.y - 3)]:
		c.rect(wheel.x, wheel.y, 4, 2, Art.INK)


static func _beacon(c: Canvas, r: Rect2i) -> void:
	var base := Rect2i(r.position.x + 6, r.position.y + 10, r.size.x - 12, r.size.y - 12)
	_box_building(c, base, Color("626b66"), Color("4a524e"), false)
	_hazard_band(c, base.position.x, base.end.y - 3, base.size.x, 2)
	# The toppled lattice mast lies across the slab.
	var top := Vector2i(base.position.x - 4, r.position.y + 2)
	var foot := Vector2i(base.get_center().x + 6, base.position.y + 6)
	c.line(top, foot, Art.STEEL)
	c.line(top + Vector2i(0, 3), foot + Vector2i(0, 3), Art.STEEL)
	var steps := 8
	for index in range(steps + 1):
		var at := Vector2(top).lerp(Vector2(foot), float(index) / steps)
		c.line(Vector2i(at.round()), Vector2i(at.round()) + Vector2i(0, 3), Art.GRAY_LIGHT)
	c.rect(foot.x - 2, foot.y - 2, 6, 7, Art.SLATE)
	c.frame(foot.x - 2, foot.y - 2, 6, 7, Art.INK)


static func _bunker(c: Canvas, portal: Vector2i, tone: Color) -> void:
	# Concrete entrance block sits behind (north of) the portal marker.
	var r := Rect2i(portal.x - 24, portal.y - 34, 48, 22)
	_box_building(c, r, tone, tone.darkened(0.3), false)
	c.rect(portal.x - 9, r.end.y - 9, 18, 9, Art.INK)
	c.rect(portal.x - 8, r.end.y - 8, 16, 8, Color("151a1c"))
	c.vline(portal.x, r.end.y - 8, r.end.y - 1, Art.SLATE)
	_hazard_band(c, portal.x - 10, r.end.y - 11, 20, 2)
	c.rect(r.position.x - 3, r.position.y + 4, 3, r.size.y - 4, tone.darkened(0.45))
	c.rect(r.end.x, r.position.y + 4, 3, r.size.y - 4, tone.darkened(0.45))


static func _checkpoint(c: Canvas, at: Vector2i) -> void:
	c.rect(at.x - 22, at.y - 3, 4, 5, Art.SLATE)
	c.frame(at.x - 22, at.y - 3, 4, 5, Art.INK)
	for x in range(at.x - 18, at.x + 12):
		c.px(x, at.y - 1, Art.WARN if posmod(x, 6) < 3 else Art.BONE)
		c.px(x, at.y, Art.INK)
	c.rect(at.x + 16, at.y - 3, 4, 5, Art.SLATE)
	c.frame(at.x + 16, at.y - 3, 4, 5, Art.INK)


static func _sign(c: Canvas, at: Vector2i) -> void:
	c.rect(at.x, at.y - 10, 1, 11, Art.STEEL)
	var triangle := [Vector2i(at.x, at.y - 18), Vector2i(at.x - 5, at.y - 10), Vector2i(at.x + 5, at.y - 10)]
	for y in range(at.y - 18, at.y - 9):
		var span := int((y - (at.y - 18)) * 5.0 / 8.0)
		c.hline(at.x - span, at.x + span, y, Art.HAZARD)
	c.line(triangle[0], triangle[1], Art.INK)
	c.line(triangle[0], triangle[2], Art.INK)
	c.line(triangle[1], triangle[2], Art.INK)
	c.vline(at.x, at.y - 15, at.y - 13, Art.INK)
	c.px(at.x, at.y - 11, Art.INK)


# --- Sampling well ------------------------------------------------------------

static func _bake_mine(c: Canvas, blockers: Array[Rect2i]) -> void:
	var area := _walk_area()
	_tile_fill(c, area, func(tx: int, ty: int) -> Image: return _tile("rock", int(_hash(tx, ty, 37) * 6)))
	_patches(c, area, "gravel", 22, 37, 8, 20)
	# Darker cave margins with steel supports.
	for x in range(area.position.x, area.end.x):
		var depth := 8 + int(_hash(x / 4, 1, 37) * 7)
		c.rect(x, area.position.y, 1, depth, Color("1a1715"))
		c.px(x, area.position.y + depth, Color("3f3934"))
	for x in range(area.position.x + 20, area.end.x, 60):
		c.rect(x, area.position.y, 3, 26, Art.RUST)
		c.rect(x - 4, area.position.y + 2, 11, 3, Art.RUST_LIGHT)
		c.frame(x, area.position.y, 3, 26, Art.INK)
	var walkway := _rect(Rect2(-85, -330, 170, 830))
	_tile_fill(c, walkway, func(tx: int, ty: int) -> Image: return _tile("grate", 0))
	c.vline(walkway.position.x, walkway.position.y, walkway.end.y, Art.HAZARD)
	c.vline(walkway.end.x - 1, walkway.position.y, walkway.end.y, Art.HAZARD)
	var rail_a := p(Vector2(-32, 0)).x
	var rail_b := p(Vector2(32, 0)).x
	for y in range(walkway.position.y, walkway.end.y, 5):
		c.rect(rail_a - 3, y, rail_b - rail_a + 7, 2, Color("4a3b2d"))
	c.vline(rail_a, walkway.position.y, walkway.end.y, Art.GRAY_LIGHT)
	c.vline(rail_b, walkway.position.y, walkway.end.y, Art.GRAY_LIGHT)
	# Drill pad and sampling shaft where the warden waits.
	var pad := p(Vector2(0, -255))
	c.disc(pad, 45, Color("39342e"))
	c.ring(pad, 45, Art.HAZARD)
	c.ring(pad, 44, Art.INK)
	for index in range(24):
		if index % 2 == 0:
			var angle := TAU * index / 24.0
			c.line(pad + Vector2i((Vector2(cos(angle), sin(angle)) * 39).round()), pad + Vector2i((Vector2(cos(angle), sin(angle)) * 43).round()), Art.HAZARD)
	c.disc(pad, 9, Art.INK)
	c.disc(pad, 7, Color("120f0e"))
	c.ring(pad, 9, Art.STEEL)
	if blockers.size() >= 3:
		_drill_rig(c, blockers[0])
		_drill_rig(c, blockers[1])
		_supply_stack(c, blockers[2])
	for index in range(6):
		_rubble(c, p(Vector2(-600 + index * 240, 300 - (index % 2) * 520)), index + 40)
	for at in [Vector2(-680, 300), Vector2(665, 275), Vector2(-730, -150), Vector2(715, -210), Vector2(-290, -390), Vector2(290, -400)]:
		_crystal(c, p(at), Color("dcac65"))
	for at in [Vector2(-280, 255), Vector2(280, 255), Vector2(-580, -380), Vector2(580, -380)]:
		_floodlight(c, p(at))
	_hatch(c, p(Vector2(0, 465)))


static func _crystal(c: Canvas, at: Vector2i, color: Color) -> void:
	c.ellipse(at + Vector2i(1, 1), 8, 3, Color(0, 0, 0, 0.35))
	for shard: Vector2i in [Vector2i(-5, 9), Vector2i(0, 15), Vector2i(5, 10)]:
		var x := at.x + shard.x
		var height := shard.y
		for y in range(height):
			var half := 1 if y < 3 else 2
			c.hline(x - half, x + half, at.y - y, color.darkened(0.15) if shard.x != 0 else color)
		c.vline(x, at.y - height + 2, at.y - 1, color.lightened(0.3))
		c.px(x, at.y - height, color.lightened(0.45))
		c.vline(x - 2, at.y - height + 3, at.y, Art.INK)
		c.vline(x + 2, at.y - height + 3, at.y, Art.INK)


static func _drill_rig(c: Canvas, r: Rect2i) -> void:
	var wall_y := _box_building(c, r, Color("6f6a5c"), Color("514c41"))
	_hazard_band(c, r.position.x, wall_y - 2, r.size.x, 2)
	# Hopper chute and a tower drill rising from the deck.
	c.rect(r.position.x + 5, wall_y + 3, 12, r.end.y - wall_y - 4, Color("2f2b26"))
	c.frame(r.position.x + 5, wall_y + 3, 12, r.end.y - wall_y - 4, Art.INK)
	var tower := Vector2i(r.end.x - 14, r.position.y + 2)
	c.rect(tower.x, tower.y - 10, 6, 22, Art.RUST_LIGHT)
	for y in range(tower.y - 9, tower.y + 12, 4):
		c.line(Vector2i(tower.x, y), Vector2i(tower.x + 5, y + 3), Art.RUST)
	c.frame(tower.x, tower.y - 10, 6, 22, Art.INK)
	c.rect(tower.x - 2, tower.y - 12, 10, 3, Art.STEEL)


static func _supply_stack(c: Canvas, r: Rect2i) -> void:
	_shadow(c, r, 3)
	for row in range(2):
		for col in range(3):
			_crate(c, Vector2i(r.position.x + 2 + col * 11, r.position.y + 4 + row * 10), 10)
	_barrel(c, Vector2i(r.end.x - 7, r.end.y - 1), Art.HAZARD.darkened(0.25))


static func _hatch(c: Canvas, at: Vector2i) -> void:
	c.rect(at.x - 12, at.y - 6, 24, 10, Art.SLATE)
	c.frame(at.x - 12, at.y - 6, 24, 10, Art.INK)
	for x in range(at.x - 10, at.x + 10, 3):
		c.vline(x, at.y - 4, at.y + 1, Art.STEEL)
	_hazard_band(c, at.x - 12, at.y + 4, 24, 2)


# --- Acoustic lab -------------------------------------------------------------

static func _bake_crypt(c: Canvas, blockers: Array[Rect2i]) -> void:
	var area := _walk_area()
	_tile_fill(c, area, func(tx: int, ty: int) -> Image: return _tile("lab", int(_hash(tx, ty, 51) * 6)))
	# Acoustic wedge panels line the walls.
	for x in range(area.position.x, area.end.x, 4):
		for y in range(0, 10):
			var shade := Art.ANOMALY_DARK.darkened(0.3) if (x / 4 + y / 3) % 2 == 0 else Art.ANOMALY_DARK
			c.rect(x, area.position.y + y, 4, 1, shade)
		c.px(x + 1, area.position.y + 10, Art.INK)
	var corridor := _rect(Rect2(-100, -330, 200, 830))
	_tile_fill(c, corridor, func(tx: int, ty: int) -> Image: return _tile("grate", 1))
	c.vline(corridor.position.x, corridor.position.y, corridor.end.y, Art.ANOMALY)
	c.vline(corridor.end.x - 1, corridor.position.y, corridor.end.y, Art.ANOMALY)
	# Cable trays running into the chamber.
	for offset: int in [-24, 24]:
		var x := corridor.get_center().x + offset
		c.vline(x, corridor.position.y, corridor.end.y, Art.INK)
		c.vline(x + 1, corridor.position.y, corridor.end.y, Color("26303a"))
	# Anechoic chamber floor: concentric damping rings.
	var chamber := p(Vector2(0, -270))
	c.disc(chamber, 52, Color("2b2a3a"))
	for radius in [52, 44, 36]:
		c.ring(chamber, radius, Art.ANOMALY if radius == 52 else Art.ANOMALY_DARK.lightened(0.15))
	for index in range(16):
		var angle := TAU * index / 16.0
		var dir := Vector2(cos(angle), sin(angle))
		c.line(chamber + Vector2i((dir * 37).round()), chamber + Vector2i((dir * 51).round()), Color(Art.ANOMALY_LIGHT, 0.35))
	c.disc(chamber, 6, Art.ANOMALY_DARK)
	c.ring(chamber, 6, Art.ANOMALY_LIGHT)
	for r in blockers:
		_resonance_column(c, r)
	_hatch(c, p(Vector2(0, 465)))
	for at in [Vector2(-620, -350), Vector2(620, -350), Vector2(-620, 280), Vector2(620, 280)]:
		_emitter(c, p(at))
	for at in [Vector2(-270, 270), Vector2(270, 270), Vector2(-275, -330), Vector2(275, -330)]:
		var lamp := p(at)
		c.rect(lamp.x - 4, lamp.y - 2, 9, 4, Art.SLATE)
		c.hline(lamp.x - 3, lamp.x + 3, lamp.y - 1, Art.FOG_PALE)
		c.frame(lamp.x - 4, lamp.y - 2, 9, 4, Art.INK)


static func _resonance_column(c: Canvas, r: Rect2i) -> void:
	var wall_y := _box_building(c, r, Color("4f4e64"), Color("3a3a4c"), false)
	for y in range(r.position.y + 3, wall_y - 2, 3):
		c.hline(r.position.x + 3, r.end.x - 4, y, Color("5d5b75"))
	# Rack front with vent slots; ZoneView animates the indicator LEDs.
	c.rect(r.position.x + 4, wall_y + 2, r.size.x - 8, r.end.y - wall_y - 4, Color("23232f"))
	for y in range(wall_y + 4, r.end.y - 3, 3):
		c.hline(r.position.x + 6, r.end.x - 10, y, Color("34344a"))
	c.frame(r.position.x + 4, wall_y + 2, r.size.x - 8, r.end.y - wall_y - 4, Art.INK)


static func _emitter(c: Canvas, at: Vector2i) -> void:
	c.ellipse(at + Vector2i(1, 2), 7, 2, Color(0, 0, 0, 0.35))
	c.rect(at.x - 5, at.y - 3, 10, 5, Art.SLATE)
	c.frame(at.x - 5, at.y - 3, 10, 5, Art.INK)
	c.rect(at.x - 1, at.y - 12, 2, 9, Art.STEEL)
	c.ellipse(Vector2i(at.x, at.y - 13), 4, 2, Art.ANOMALY)
	c.hline(at.x - 2, at.x + 2, at.y - 14, Art.ANOMALY_LIGHT)
