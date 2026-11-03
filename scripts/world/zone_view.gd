class_name ZoneView
extends Node2D
## Hand-authored area layouts and presentation. The session owns transitions and loot.
## Every peer builds the same static geometry from the zone ID. Static ground and props
## come from ZoneArt; this node only animates lights, portals and indicators on top.

const Art = preload("res://scripts/art/pixel_art.gd")
const ZoneArt = preload("res://scripts/world/zone_art.gd")

const WALK_RECT := Rect2(-880.0, -500.0, 1760.0, 1000.0)
const ZONE_TITLES := {
	"camp": "雾线前哨",
	"wilds": "外环雾区",
	"mine": "7 号采样井",
	"crypt": "回声声学实验室",
}
const ACCENTS := {
	"camp": Color("f0c95a"),
	"wilds": Color("9cc7bb"),
	"mine": Color("e8b46a"),
	"crypt": Color("b9a0f0"),
}
const MINE_CRYSTALS := [Vector2(-680, 300), Vector2(665, 275), Vector2(-730, -150), Vector2(715, -210), Vector2(-290, -390), Vector2(290, -400)]
const CRYPT_EMITTERS := [Vector2(-620, -350), Vector2(620, -350), Vector2(-620, 280), Vector2(620, 280)]

var zone_id: String = "camp"
var _portals: Array[Dictionary] = []
var _enemy_spawns: Array[Dictionary] = []
var _blockers: Array[Rect2] = []
var _spawn: Vector2 = Vector2(0.0, 180.0)
var _clock: float = 0.0


func _ready() -> void:
	if _portals.is_empty():
		build(zone_id)


func build(next_zone: String) -> void:
	zone_id = next_zone if ZONE_TITLES.has(next_zone) else "camp"
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_portals.clear()
	_enemy_spawns.clear()
	_blockers.clear()
	_clock = 0.0
	_spawn = Vector2(0.0, 280.0)
	match zone_id:
		"camp":
			_spawn = Vector2(0.0, 170.0)
			_add_portal("camp_to_wilds", "外环雾区", "wilds", Vector2(0.0, -340.0))
			_blockers.assign([
				Rect2(-570.0, -10.0, 210.0, 150.0),
				Rect2(360.0, -10.0, 210.0, 150.0),
				Rect2(-525.0, -295.0, 170.0, 105.0),
			])
		"wilds":
			_add_portal("wilds_to_camp", "雾线前哨", "camp", Vector2(0.0, 405.0))
			_add_portal("wilds_to_mine", "7 号采样井 · 回收任务", "mine", Vector2(-620.0, -285.0))
			_add_portal("wilds_to_crypt", "回声声学实验室 · 回收任务", "crypt", Vector2(620.0, -285.0))
			_blockers.assign([
				Rect2(-470.0, 65.0, 100.0, 75.0),
				Rect2(375.0, 65.0, 100.0, 75.0),
				Rect2(-65.0, -310.0, 130.0, 85.0),
			])
			_add_enemy(Vector2(-220.0, 95.0), "slime")
			_add_enemy(Vector2(240.0, 60.0), "slime")
			_add_enemy(Vector2(-430.0, -170.0), "slime")
			_add_enemy(Vector2(420.0, -170.0), "slime")
			_add_enemy(Vector2(-160.0, -165.0), "guard")
			_add_enemy(Vector2(190.0, -170.0), "guard")
		"mine":
			_add_portal("mine_to_wilds", "返回外环雾区", "wilds", Vector2(0.0, 405.0))
			_blockers.assign([
				Rect2(-550.0, 5.0, 150.0, 95.0),
				Rect2(420.0, 5.0, 150.0, 95.0),
				Rect2(-650.0, -305.0, 110.0, 75.0),
			])
			_add_enemy(Vector2(-230.0, 100.0), "slime")
			_add_enemy(Vector2(250.0, 80.0), "slime")
			_add_enemy(Vector2(-330.0, -110.0), "guard")
			_add_enemy(Vector2(330.0, -110.0), "guard")
			_add_enemy(Vector2(0.0, -255.0), "boss")
		"crypt":
			_add_portal("crypt_to_wilds", "返回外环雾区", "wilds", Vector2(0.0, 405.0))
			_blockers.assign([
				Rect2(-500.0, 10.0, 90.0, 130.0),
				Rect2(410.0, 10.0, 90.0, 130.0),
				Rect2(-500.0, -305.0, 90.0, 130.0),
				Rect2(410.0, -305.0, 90.0, 130.0),
			])
			_add_enemy(Vector2(-245.0, 95.0), "guard")
			_add_enemy(Vector2(245.0, 95.0), "guard")
			_add_enemy(Vector2(-250.0, -140.0), "slime")
			_add_enemy(Vector2(250.0, -140.0), "slime")
			_add_enemy(Vector2(0.0, -270.0), "boss")
	# Walls sit outside WALK_RECT; its interior remains identical on all peers.
	_add_collision(Rect2(-944.0, -564.0, 64.0, 1128.0))
	_add_collision(Rect2(880.0, -564.0, 64.0, 1128.0))
	_add_collision(Rect2(-880.0, -564.0, 1760.0, 64.0))
	_add_collision(Rect2(-880.0, 500.0, 1760.0, 64.0))
	for rect in _blockers:
		_add_collision(rect)
	queue_redraw()


func get_spawn(index: int = 0) -> Vector2:
	# A short row prevents co-op arrivals from completely covering one another.
	return _spawn + Vector2(float(index % 4) * 45.0 - 45.0, float(index / 4) * 42.0)


func get_enemy_spawns() -> Array:
	return _enemy_spawns.duplicate(true)


func get_portals() -> Array:
	return _portals.duplicate(true)


func get_blockers() -> Array:
	return _blockers.duplicate()


func get_walk_rect() -> Rect2:
	return WALK_RECT


func get_title() -> String:
	return str(ZONE_TITLES.get(zone_id, "未知区域"))


func get_accent() -> Color:
	return ACCENTS.get(zone_id, ACCENTS["camp"])


## Text the stage overlays at full resolution: {position, text, color, size, centered}.
func get_labels() -> Array:
	var labels: Array = []
	var accent := get_accent()
	match zone_id:
		"camp":
			labels.append(_label(Vector2(-465, 168), "收容仓库", Color("b9d4cc"), 16))
			labels.append(_label(Vector2(465, 168), "维修间", Color("e3c39a"), 16))
			labels.append(_label(Vector2(-460, -172), "雾况观测站", Color("b4c4bd"), 15))
		"wilds":
			labels.append(_label(Vector2(0, -205), "断电信标", Color("9fb8ae"), 15))
		"mine":
			labels.append(_label(Vector2(0, -400), "采样井底", Color("cdb48a"), 15))
		"crypt":
			labels.append(_label(Vector2(0, -428), "第三收容室", Color("c4b5e6"), 15))
	for portal in _portals:
		labels.append(_label(portal.position + Vector2(0, 66), str(portal.label), accent, 16))
	labels.append(_label(Vector2(-850, 392), get_title(), Color(accent, 0.6), 24, false))
	var caption: String = "补给 · 整备 · 出发" if zone_id == "camp" else "搜索 · 规避 · 回收"
	if zone_id == "mine" or zone_id == "crypt":
		caption = "废弃设施 · 排除守卫者"
	labels.append(_label(Vector2(-850, 416), caption, Color(accent, 0.45), 13, false))
	return labels


## Light sources that thin the fog: {position, radius}.
func get_lights() -> Array:
	var points: Array = []
	var radius := 120.0
	match zone_id:
		"camp":
			points = [Vector2(-155, -95), Vector2(155, -95), Vector2(-145, 260), Vector2(145, 260), Vector2(0, 50)]
			radius = 200.0
		"wilds":
			points = [Vector2(-620, -330), Vector2(620, -330), _beacon_light()]
			radius = 110.0
		"mine":
			points = [Vector2(-280, 255), Vector2(280, 255), Vector2(-580, -380), Vector2(580, -380), Vector2(0, -255)]
			points.append_array(MINE_CRYSTALS)
			radius = 130.0
		"crypt":
			points = [Vector2(-270, 270), Vector2(270, 270), Vector2(-275, -330), Vector2(275, -330), Vector2(0, -270)]
			points.append_array(CRYPT_EMITTERS)
			radius = 130.0
	var lights: Array = []
	for point in points:
		lights.append({"position": point, "radius": radius})
	for portal in _portals:
		lights.append({"position": portal.position, "radius": 95.0})
	return lights


func _label(point: Vector2, text: String, color: Color, size: int, centered: bool = true) -> Dictionary:
	return {"position": point, "text": text, "color": color, "size": size, "centered": centered}


func _add_portal(id: String, label: String, target: String, point: Vector2) -> void:
	_portals.append({"id": id, "label": label, "target": target, "position": point, "radius": 92.0})


func _add_enemy(point: Vector2, kind: String) -> void:
	_enemy_spawns.append({"position": point, "kind": kind})


func _add_collision(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	# Headless peers (tests, dedicated hosts) never need the baked raster.
	if DisplayServer.get_name() == "headless":
		return
	var tex := ZoneArt.texture(zone_id, _blockers)
	draw_texture_rect(tex, Rect2(ZoneArt.ORIGIN, Vector2(ZoneArt.IMAGE_SIZE) * Art.SCALE), false)
	match zone_id:
		"camp": _animate_camp()
		"wilds": _animate_wilds()
		"mine": _animate_mine()
		"crypt": _animate_crypt()
	for portal in _portals:
		_draw_portal(portal)


## Paints art pixels at integer offsets from a snapped world anchor.
func _pixels(anchor: Vector2, offsets: Array, color: Color) -> void:
	var origin := (anchor / Art.SCALE).floor() * Art.SCALE
	for offset: Vector2i in offsets:
		draw_rect(Rect2(origin + Vector2(offset) * Art.SCALE, Vector2.ONE * Art.SCALE), color)


func _glow(world: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	# Stepped rings read as pixel light pools once the stage downsamples them.
	for step in range(3):
		draw_circle(world, radius * (1.0 - step * 0.3), Color(color, 0.05 * strength * (step + 1)))


func _blink(rate: float, offset: float = 0.0) -> bool:
	return fmod(_clock * rate + offset, 1.0) < 0.5


func _animate_camp() -> void:
	var flicker := 0.85 + sin(_clock * 13.0) * 0.08 + sin(_clock * 7.3) * 0.07
	for point in [Vector2(-155, -95), Vector2(155, -95), Vector2(-145, 260), Vector2(145, 260)]:
		_glow(point + Vector2(0, 12), 80.0, Art.LAMP, flicker)
		_pixels(point + Vector2(0, -36), [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], Art.LAMP)
	_glow(Vector2(0, 50), 60.0, Color("9be08a"), 0.8)
	_pixels(Vector2(-24, 36), [Vector2i.ZERO], Color("9be08a") if _blink(1.6) else Art.FOG_DARK)
	_pixels(Vector2(-18, 36), [Vector2i.ZERO], Art.WARN_LIGHT if _blink(0.7, 0.3) else Art.WARN_DARK)
	# Exhaust puffs from the generator stack.
	for index in range(3):
		var age := fmod(_clock * 0.6 + index / 3.0, 1.0)
		_pixels(Vector2(15 + age * 18, 30 - age * 60), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], Color(Art.FOG_LIGHT, 0.45 * (1.0 - age)))


func _animate_wilds() -> void:
	var beacon := _beacon_light()
	if _blink(0.9):
		_glow(beacon, 40.0, Art.WARN, 1.4)
		_pixels(beacon, [Vector2i.ZERO, Vector2i(1, 0)], Art.WARN_LIGHT)
	for point in [Vector2(-620, -335), Vector2(620, -335)]:
		_glow(point, 46.0, Art.LAMP_WARM, 0.8 + sin(_clock * 3.0) * 0.2)
		_pixels(point, [Vector2i(-1, 0), Vector2i(0, 0)], Art.LAMP_WARM if _blink(1.2) else Art.RUST)


func _beacon_light() -> Vector2:
	if _blockers.size() < 3:
		return Vector2.ZERO
	return _blockers[2].get_center() + Vector2(24.0, -6.0)


func _animate_mine() -> void:
	for index in range(MINE_CRYSTALS.size()):
		var point: Vector2 = MINE_CRYSTALS[index]
		_glow(point + Vector2(0, -20), 58.0, Color("e8b46a"), 0.9 + sin(_clock * 1.7 + index) * 0.35)
		if fmod(_clock * 0.8 + index * 0.37, 1.0) < 0.12:
			_pixels(point + Vector2(-15 + index % 3 * 15, -40), [Vector2i.ZERO], Art.LAMP)
	for point in [Vector2(-280, 255), Vector2(280, 255), Vector2(-580, -380), Vector2(580, -380)]:
		_glow(point + Vector2(0, 12), 72.0, Art.LAMP_WARM, 0.9)
	# The sampling shaft breathes a faint amber pulse.
	_glow(Vector2(0, -255), 30.0 + sin(_clock * 2.0) * 4.0, Color("e8b46a"), 1.2)


func _animate_crypt() -> void:
	for rect in _blockers:
		var base := Vector2(rect.end.x - 27, rect.position.y + rect.size.y * 0.62)
		for row in range(5):
			var on := _blink(0.5 + row * 0.37, rect.position.x * 0.01 + row * 0.21)
			var color := Art.ANOMALY_LIGHT if row % 2 == 0 else Color("7ce0a0")
			_pixels(base + Vector2(0, row * 9), [Vector2i.ZERO], color if on else Art.INK)
	for index in range(CRYPT_EMITTERS.size()):
		var point: Vector2 = CRYPT_EMITTERS[index] + Vector2(0, -39)
		var pulse := 0.5 + 0.5 * sin(_clock * 2.4 + index * 1.3)
		_glow(point, 40.0 + pulse * 18.0, Art.ANOMALY_LIGHT, 0.8 + pulse)
		# Expanding sound rings from each emitter.
		var ring := fmod(_clock * 0.5 + index * 0.25, 1.0)
		draw_arc(point, 20.0 + ring * 70.0, 0.0, TAU, 24, Color(Art.ANOMALY_LIGHT, 0.35 * (1.0 - ring)), 3.0, false)
	for point in [Vector2(-270, 270), Vector2(270, 270), Vector2(-275, -330), Vector2(275, -330)]:
		_glow(point, 74.0, Art.FOG_PALE, 0.7)
	var chamber := fmod(_clock * 0.35, 1.0)
	draw_arc(Vector2(0, -270), 30.0 + chamber * 120.0, 0.0, TAU, 40, Color(Art.ANOMALY_LIGHT, 0.3 * (1.0 - chamber)), 3.0, false)


func _draw_portal(portal: Dictionary) -> void:
	var at: Vector2 = portal.position
	var accent := get_accent()
	var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
	_glow(at, 70.0, accent, 0.5 + pulse * 0.6)
	# Corner brackets of the extraction plate breathe in and out.
	var half := 14 - int(pulse * 2.0)
	var brackets: Array = []
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for step in range(4):
				brackets.append(Vector2i(sx * (half - step), sy * half))
				brackets.append(Vector2i(sx * half, sy * (half - step)))
	_pixels(at, brackets, accent)
	# Marching chevrons point the way the gate leads.
	var direction := -1 if at.y < 0.0 else 1
	for row in range(3):
		var lit := fmod(_clock * 1.8 - row / 3.0, 1.0) < 0.4
		var chevron: Array = []
		for x in range(-3, 4):
			chevron.append(Vector2i(x, direction * (row * 3 - 4 + (3 - absi(x)))))
		_pixels(at, chevron, Color(accent, 0.95 if lit else 0.3))
