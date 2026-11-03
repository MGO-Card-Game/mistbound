class_name PixelArt
extends RefCounted
## Shared palette and character sprites. Sprites are text pixel maps rasterized once
## and cached; a PNG at res://assets/sprites/<name>.png replaces the generated one.

## World units per art pixel. The stage camera renders at 1 / SCALE.
const SCALE := 3.0
const OVERRIDE_DIR := "res://assets/sprites/"

const INK := Color("0a0f11")
const NIGHT := Color("0d1417")
const SLATE_DARK := Color("1b272b")
const SLATE := Color("30434a")
const STEEL := Color("4c5658")
const GRAY := Color("616b6b")
const GRAY_LIGHT := Color("9aa29c")
const BONE := Color("e9efe8")
const ASPHALT := Color("25292b")
const RUST_DARK := Color("4a2c22")
const RUST := Color("6e3f2a")
const RUST_LIGHT := Color("9a5a33")
const ORANGE := Color("c07a3e")
const HAZARD := Color("d9a63a")
const HAZARD_LIGHT := Color("f0c95a")
const FOG_DARK := Color("2c4a46")
const FOG := Color("5f938a")
const FOG_LIGHT := Color("9cc7bb")
const FOG_PALE := Color("d5ece4")
const MOSS_DARK := Color("2f3a2c")
const MOSS := Color("4f5a3e")
const MOSS_LIGHT := Color("6c7550")
const WARN_DARK := Color("8c2f2b")
const WARN := Color("d3483c")
const WARN_LIGHT := Color("ff7a5c")
const ANOMALY_DARK := Color("3d2f5c")
const ANOMALY := Color("7a5fb0")
const ANOMALY_LIGHT := Color("b9a0f0")
const LAMP := Color("ffd68a")
const LAMP_WARM := Color("ffb35c")

## Digits mark the tintable layer: '1' light, '2' mid, '3' dark.
const KEYS := {
	"k": INK, "K": SLATE_DARK, "s": SLATE, "S": STEEL, "g": GRAY, "G": GRAY_LIGHT, "w": BONE,
	"b": ASPHALT, "r": RUST, "R": RUST_LIGHT, "o": ORANGE, "y": HAZARD, "Y": HAZARD_LIGHT,
	"t": FOG_DARK, "T": FOG, "c": FOG_LIGHT, "C": FOG_PALE, "m": WARN_DARK, "e": WARN, "E": WARN_LIGHT,
	"p": ANOMALY, "P": ANOMALY_LIGHT, "l": LAMP,
	"1": Color(1, 1, 1), "2": Color(0.74, 0.74, 0.74), "3": Color(0.5, 0.5, 0.5),
}

const SPRITES := {
	# Recovery worker in a hooded hazard suit, gas mask and sample pack. Faces right.
	"player_idle": [
		"....kkkk....",
		"...k1111k...",
		"..k112111k..",
		"..k11kkkkkk.",
		".kk1kcCCTsk.",
		"krk1kTccTsk.",
		"krk11kSSSkkk",
		"krk12kkkkkSk",
		"krkk222222kk",
		"krk2yy2222k.",
		".kk22222232k",
		"..k2223222k.",
		"..k33kk33k..",
		"..k33kk33k..",
		"..kbbkkbbk..",
		"..kkk..kkk..",
	],
	"player_walk_a": [
		"....kkkk....",
		"...k1111k...",
		"..k112111k..",
		"..k11kkkkkk.",
		".kk1kcCCTsk.",
		"krk1kTccTsk.",
		"krk11kSSSkkk",
		"krk12kkkkkSk",
		"krkk222222kk",
		"krk2yy2222k.",
		".kk22222232k",
		"..k2223222k.",
		"..k33kk33k..",
		".k33k..k33k.",
		".kbbk..kbbk.",
		".kkk....kkk.",
	],
	"player_walk_b": [
		"....kkkk....",
		"...k1111k...",
		"..k112111k..",
		"..k11kkkkkk.",
		".kk1kcCCTsk.",
		"krk1kTccTsk.",
		"krk11kSSSkkk",
		"krk12kkkkkSk",
		"krkk222222kk",
		"krk2yy2222k.",
		".kk22222232k",
		"..k2223222k.",
		"..k33kk33k..",
		"...k3333k...",
		"...kbbbbk...",
		"...kkkkkk...",
	],
	# Fog mass: a drifting knot of condensed mist with two pale lights inside.
	"fog_mass": [
		".....kkkk.....",
		"...kkTTTTkk...",
		"..kTTccccTTk..",
		".kTcccCCcccTk.",
		".kTcttttttcTk.",
		"kTctCttttCtcTk",
		"kTcttttttttcTk",
		"kTTcttttttcTTk",
		".kTTccccccTTk.",
		"..kkTTTTTTkk..",
		"....kkkkkk....",
	],
	# Rogue security unit: squat hover chassis with a scanning visor.
	"security_unit": [
		"......kk......",
		"......kE......",
		"...kkkkkkkk...",
		"..kGGGGGGGGk..",
		".kGgggggggggk.",
		".kgKKKKKKKKgk.",
		".kgKKKKKKKKgk.",
		".kgKKKKKKKKgk.",
		".kGgggggggggk.",
		".kykykykykykk.",
		".kSSSSSSSSSSk.",
		"..kSkk..kkSk..",
		"..kbbk..kbbk..",
		"...kk....kk...",
	],
	# Facility warden: tracked heavy maintenance frame with a sensor bar.
	"warden": [
		"........kkkkkkkk........",
		".......kGGGGGGGGk.......",
		"......kGggggggggGk......",
		".....kGgKKKKKKKKgGk.....",
		"..kkkkgKKKKKKKKKKgkkkk..",
		".kSSSkgKKKKKKKKKKgkSSSk.",
		"kSGGSkGggggggggggGkSGGSk",
		"kSggSkykkyykkyykkykSggSk",
		"kSggSkyykkyykkyykkkSggSk",
		"kSSSSkGggggggggggGkSSSSk",
		".kkkkkgSSSSSSSSSSgkkkkk.",
		"..kRrkgSrrRRRRrrSgkrRk..",
		"..kRRkgSSSSSSSSSSgkRRk..",
		"..kkkkkgggggggggkkkkkk..",
		"...kbbbbbbk..kbbbbbbk...",
		"...kbkbkbbk..kbbkbkbk...",
		"...kbbbbbbk..kbbbbbbk...",
		"....kkkkkk....kkkkkk....",
	],
	# Containment canister; the glass core takes the anomaly's color.
	"canister": [
		"..kkkk..",
		".kGwwGk.",
		".kSSSSk.",
		".k1221k.",
		".k2112k.",
		".k1221k.",
		".k2112k.",
		".kSSSSk.",
		".kGyyGk.",
		"..kkkk..",
	],
	"supply_crate": [
		".kkkkkkkk.",
		"kRRRRRRRRk",
		"krkRRRRkrk",
		"krRkRRkRrk",
		"krRRkkRRrk",
		"krRkRRkRrk",
		"krkRRRRkrk",
		"kRRRRRRRRk",
		".kkkkkkkk.",
	],
	# Held tools. Grip sits near the left edge; drawing rotates them toward the aim.
	"crowbar": [
		".......kk.",
		"kkkkkkkEek",
		"kmeeeeeekk",
		"kkkkkkkk..",
	],
	"nailgun": [
		".kkkkkkkk...",
		"kYYyyyyykkkk",
		"kyyyyyyyGGGk",
		"kyykkkkkkkkk",
		"kbbk.kSSk...",
		"kbbk.kSSk...",
		"kkkk.kkkk...",
	],
}

## Fusion Pixel Font (OFL 1.1), drawn crisp only at multiples of its 12 px grid.
const FONT_PATH := "res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.otf.woff2"
const FONT_GRID := 12

static var _textures: Dictionary = {}
static var _font: Font


## Shared pixel font with antialiasing off and a system fallback for rare glyphs.
static func font() -> Font:
	if _font != null:
		return _font
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	if not ResourceLoader.exists(FONT_PATH):
		_font = fallback
		return _font
	var pixel: FontFile = load(FONT_PATH)
	pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel.hinting = TextServer.HINTING_NONE
	pixel.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	pixel.fallbacks = [fallback]
	_font = pixel
	return _font


## Snaps a requested size to the font's pixel grid: small text 12 px, headings 24 px.
static func font_size(requested: int) -> int:
	return FONT_GRID * clampi(roundi(requested / float(FONT_GRID) - 0.25), 1, 3)


## Base layer (everything except digits) of a sprite.
static func texture(sprite: String) -> Texture2D:
	return _layer(sprite, "base")


## Grayscale tint layer (digits only); draw it with the tint as modulate.
static func tint_layer(sprite: String) -> Texture2D:
	return _layer(sprite, "tint")


## Solid white silhouette of the whole sprite, used for hit flashes.
static func silhouette(sprite: String) -> Texture2D:
	return _layer(sprite, "flash")


static func sprite_size(sprite: String) -> Vector2:
	var rows: Array = SPRITES.get(sprite, [])
	return Vector2(str(rows[0]).length() if not rows.is_empty() else 0, rows.size())


## Draws a sprite with its bottom center at `foot` (world units), optionally mirrored.
static func draw(item: CanvasItem, tex: Texture2D, foot: Vector2, flip: bool = false, modulate: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var size := tex.get_size() * SCALE
	var origin := (foot / SCALE).round() * SCALE - Vector2(roundf(size.x / SCALE / 2.0) * SCALE, size.y)
	item.draw_texture_rect(tex, Rect2(origin + Vector2(size.x if flip else 0.0, 0.0), Vector2(-size.x if flip else size.x, size.y)), false, modulate)


static func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for sprite: String in SPRITES:
		var rows: Array = SPRITES[sprite]
		for index in range(rows.size()):
			var row := str(rows[index])
			if row.length() != str(rows[0]).length():
				problems.append("%s row %d is %d wide, expected %d" % [sprite, index, row.length(), str(rows[0]).length()])
			for character in row:
				if character != "." and not KEYS.has(character):
					problems.append("%s row %d uses unknown key '%s'" % [sprite, index, character])
	return problems


static func _layer(sprite: String, layer: String) -> Texture2D:
	var key := sprite + ":" + layer
	if _textures.has(key):
		return _textures[key]
	var override_path := OVERRIDE_DIR + sprite + ("" if layer == "base" else "_" + layer) + ".png"
	var result: Texture2D
	if ResourceLoader.exists(override_path):
		result = load(override_path)
	elif SPRITES.has(sprite):
		result = ImageTexture.create_from_image(_rasterize(SPRITES[sprite], layer))
	_textures[key] = result
	return result


static func _rasterize(rows: Array, layer: String) -> Image:
	var size := Vector2i(str(rows[0]).length(), rows.size())
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(rows.size()):
		var row := str(rows[y])
		for x in range(mini(row.length(), size.x)):
			var character := row[x]
			if not KEYS.has(character):
				continue
			var tinted := character in ["1", "2", "3"]
			if layer == "flash":
				image.set_pixel(x, y, Color.WHITE)
			elif (layer == "tint") == tinted:
				image.set_pixel(x, y, KEYS[character])
	return image
