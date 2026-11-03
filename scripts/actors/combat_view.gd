class_name CombatView
extends Node2D
## Cosmetic-only layer. Projectiles are snapshots; events never apply damage here.
## Everything is drawn in whole art pixels so it matches the low-resolution stage.

const Art = preload("res://scripts/art/pixel_art.gd")
const MAX_EFFECTS := 128
const MAX_PROJECTILES := 256
## 3x5 bitmap digits, one row string per line ('#' = lit).
const DIGITS := [
	["###", "#.#", "#.#", "#.#", "###"], [".#.", "##.", ".#.", ".#.", "###"],
	["###", "..#", "###", "#..", "###"], ["###", "..#", "###", "..#", "###"],
	["#.#", "#.#", "###", "..#", "..#"], ["###", "#..", "###", "..#", "###"],
	["###", "#..", "###", "#.#", "###"], ["###", "..#", ".#.", ".#.", ".#."],
	["###", "#.#", "###", "#.#", "###"], ["###", "#.#", "###", "..#", "###"],
]

var _projectiles: Dictionary = {}
var _effects: Array[Dictionary] = []
var _sequence := 0


func set_projectiles(entries: Array) -> void:
	var next: Dictionary = {}
	for entry in entries.slice(0, MAX_PROJECTILES):
		if not entry is Dictionary:
			continue
		var data: Dictionary = entry
		var id := str(data.get("id", ""))
		var point: Variant = data.get("position", Vector2.ZERO)
		var heading: Variant = data.get("direction", Vector2.RIGHT)
		if id.is_empty() or not point is Vector2 or not heading is Vector2:
			continue
		var position_value: Vector2 = point
		var direction: Vector2 = heading
		if not position_value.is_finite() or not direction.is_finite():
			continue
		var projectile: Dictionary = _projectiles.get(id, {"position": position_value})
		projectile["target"] = position_value
		projectile["direction"] = _normalized(direction)
		projectile["owner"] = int(data.get("owner", 0))
		next[id] = projectile
	_projectiles = next
	queue_redraw()


func play_event(event: Dictionary) -> void:
	var type := str(event.get("type", ""))
	if type not in ["hit", "chain", "shot", "slam", "charge"]:
		return
	_sequence += 1
	var effect: Dictionary = event.duplicate(true)
	effect["age"] = 0.0
	effect["seed"] = _sequence
	match type:
		"hit": effect["duration"] = 0.7
		"chain":
			effect["duration"] = 0.3
			effect["segments"] = _make_lightning(event.get("points", []), _sequence)
		"shot": effect["duration"] = 0.14
		"slam": effect["duration"] = 0.5
		"charge": effect["duration"] = 0.25
	if type != "chain":
		var point: Variant = event.get("position", Vector2.ZERO)
		if not point is Vector2 or not point.is_finite():
			return
		effect["position"] = point
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()
	_effects.append(effect)
	queue_redraw()


func clear_effects() -> void:
	_projectiles.clear()
	_effects.clear()
	queue_redraw()


func _process(delta: float) -> void:
	for projectile: Dictionary in _projectiles.values():
		var current: Vector2 = projectile.position
		var target: Vector2 = projectile.target
		projectile.position = current.lerp(target, 1.0 - exp(-30.0 * delta)) if current.distance_to(target) < 300.0 else target
	for index in range(_effects.size() - 1, -1, -1):
		_effects[index]["age"] = float(_effects[index].age) + delta
		if float(_effects[index].age) >= float(_effects[index].duration):
			_effects.remove_at(index)
	# Also clear the final frame after the last short-lived effect expires.
	queue_redraw()


func _draw() -> void:
	for projectile: Dictionary in _projectiles.values():
		_draw_projectile(projectile)
	for effect: Dictionary in _effects:
		var progress := clampf(float(effect.age) / float(effect.duration), 0.0, 1.0)
		match str(effect.type):
			"hit": _draw_hit(effect, progress)
			"chain": _draw_chain(effect, progress)
			"shot": _draw_shot(effect, progress)
			"slam": _draw_slam(effect, progress)
			"charge": _draw_charge(effect, progress)


func _draw_projectile(projectile: Dictionary) -> void:
	# A steel nail: bright head, dark shank, faint motion streak.
	var point: Vector2 = projectile.position
	var direction: Vector2 = projectile.direction
	draw_line(point - direction * 30, point - direction * 12, Color(Art.FOG_PALE, 0.25), 3.0)
	draw_line(point - direction * 12, point + direction * 6, Art.GRAY_LIGHT, 3.0)
	draw_line(point + direction * 6, point + direction * 12, Art.BONE, 3.0)
	_px(point - direction * 12, Vector2(1, 1), Art.STEEL)


func _draw_hit(effect: Dictionary, progress: float) -> void:
	var point: Vector2 = effect.position
	var color := Color("f0dfb6")
	var element := str(effect.get("element", "physical"))
	if element == "burn":
		color = Color("ffb36b")
	elif element == "chain":
		color = Color("a4eaff")
	if str(effect.get("target", "enemy")) == "player":
		color = Color("ff8f83")
	var alpha := 1.0 - progress
	if progress < 0.35:
		var spark_alpha := 1.0 - progress / 0.35
		for index in range(6):
			var direction := Vector2.from_angle(TAU * index / 6.0 + int(effect.seed) * 0.67)
			var reach := 6.0 + progress * 70.0
			_px(point + direction * reach, Vector2(1, 1), Color(color, spark_alpha))
			if progress < 0.15:
				_px(point + direction * reach * 0.5, Vector2(1, 1), Color(Art.BONE, spark_alpha))
	var damage := maxf(0.0, float(effect.get("damage", 0.0)))
	if damage > 0.0:
		var text := str(int(round(damage)))
		var cell := 1 if element == "burn" else 2
		var width := (text.length() * 4 - 1) * cell * Art.SCALE
		var drift := float(int(effect.seed) % 3 - 1) * 12.0
		var at := point + Vector2(drift - width / 2.0, -36.0 - progress * 30.0)
		_digits(text, at + Vector2(Art.SCALE, Art.SCALE), cell, Color(Art.INK, alpha * 0.9))
		_digits(text, at, cell, Color(color, alpha))


func _digits(text: String, at: Vector2, cell: int, color: Color) -> void:
	var origin := (at / Art.SCALE).round() * Art.SCALE
	for index in range(text.length()):
		var glyph: Array = DIGITS[int(text[index])]
		for y in range(5):
			var row: String = glyph[y]
			for x in range(3):
				if row[x] == "#":
					var offset := Vector2(index * 4 + x, y) * cell * Art.SCALE
					draw_rect(Rect2(origin + offset, Vector2.ONE * cell * Art.SCALE), color)


## Draws `size` art pixels at a world point snapped to the pixel grid.
func _px(world: Vector2, size: Vector2, color: Color) -> void:
	draw_rect(Rect2((world / Art.SCALE).round() * Art.SCALE, size * Art.SCALE), color)


func _draw_chain(effect: Dictionary, progress: float) -> void:
	var alpha := (1.0 - progress) * (0.85 + 0.15 * sin(progress * 35))
	for segment: PackedVector2Array in effect.get("segments", []):
		if segment.size() < 2:
			continue
		draw_polyline(segment, Color(0.31, 0.7, 1.0, alpha * 0.25), 9.0)
		draw_polyline(segment, Color(0.94, 1.0, 1.0, alpha), 3.0)
		draw_circle(segment[-1], 9 * (1.0 - progress), Color(0.7, 0.95, 1.0, alpha * 0.4))


func _draw_shot(effect: Dictionary, progress: float) -> void:
	var point: Vector2 = effect.position
	var direction := _event_direction(effect)
	var alpha := 1.0 - progress
	draw_line(point, point + direction * (18 + progress * 22), Color(1.0, 0.9, 0.61, alpha), 3.0)
	for side in [-1, 1]:
		_px(point + direction.rotated(0.6 * side) * (12 + progress * 14), Vector2(1, 1), Color(1.0, 0.9, 0.61, alpha))


func _draw_slam(effect: Dictionary, progress: float) -> void:
	var point: Vector2 = effect.position
	var radius := maxf(1.0, float(effect.get("radius", 115.0)))
	var alpha := 1.0 - progress
	var ring := radius * (0.35 + progress * 0.65)
	draw_circle(point, ring, Color(1.0, 0.55, 0.3, alpha * 0.08))
	draw_arc(point, ring, 0, TAU, 48, Color(1.0, 0.72, 0.46, alpha), 6.0 if alpha > 0.5 else 3.0, false)
	draw_arc(point, ring * 0.78, 0, TAU, 40, Color(1.0, 0.88, 0.66, alpha * 0.4), 3.0, false)
	# Debris chunks thrown outward by the impact.
	for index in range(10):
		var direction := Vector2.from_angle(TAU * index / 10.0 + 0.3)
		_px(point + direction * ring * (0.6 + 0.3 * float(index % 2)), Vector2(1, 1), Color(Art.GRAY_LIGHT if index % 2 == 0 else Art.ORANGE, alpha * 0.9))


func _draw_charge(effect: Dictionary, progress: float) -> void:
	var point: Vector2 = effect.position
	var direction := _event_direction(effect)
	var side := direction.orthogonal()
	var alpha := 1.0 - progress
	for index in range(5):
		var offset := side * (index - 2) * 13.0
		draw_line(point + offset - direction * progress * 40, point + offset - direction * (35 + progress * 110), Color(1.0, 0.68, 0.39, alpha * 0.6), 3.0)


func _make_lightning(raw_points: Variant, seed: int) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	if not raw_points is Array:
		return segments
	var points: Array[Vector2] = []
	for raw in raw_points.slice(0, 12):
		if raw is Vector2 and raw.is_finite():
			points.append(raw)
	for index in range(points.size() - 1):
		var start := points[index]
		var end := points[index + 1]
		var side := _normalized(end - start).orthogonal()
		var count := clampi(int(start.distance_to(end) / 24.0), 3, 12)
		var segment := PackedVector2Array([start])
		for step in range(1, count):
			var t := float(step) / count
			var displacement := sin(float(step * 9 + seed * 3 + index * 5)) * 9.0
			segment.append(start.lerp(end, t) + side * displacement)
		segment.append(end)
		segments.append(segment)
	return segments


func _event_direction(effect: Dictionary) -> Vector2:
	var direction: Variant = effect.get("direction", Vector2.RIGHT)
	return _normalized(direction) if direction is Vector2 else Vector2.RIGHT


func _normalized(direction: Vector2) -> Vector2:
	return direction.normalized() if direction.is_finite() and direction.length_squared() > 0.0001 else Vector2.RIGHT
