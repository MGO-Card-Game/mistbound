class_name ActorView
extends CharacterBody2D
## Shared lightweight view. Only the host drives CharacterBody2D movement.
## Drawing uses PixelArt sprites; names and state callouts go to the stage overlay.

const Art = preload("res://scripts/art/pixel_art.gd")

var kind: String = "player"
var display_name: String = "回收员"
var tint: Color = Color("7ce0cc")
var hp: float = 100.0
var max_hp: float = 100.0
var facing: Vector2 = Vector2.RIGHT
var target_position: Vector2
var simulated: bool = true
var local_player: bool = false
var slash_time: float = 0.0
var hurt_time: float = 0.0
var windup: float = 0.0
var radius: float = 15.0
var weapon_kind: String = "melee"
var burning: bool = false
var relic_charge: int = 0
var boss_state: String = "chase"
var telegraph_direction: Vector2 = Vector2.RIGHT
var telegraph_progress: float = 0.0
var telegraph_range: float = 360.0
var telegraph_radius: float = 115.0
var _clock: float = 0.0
var _last_position := Vector2.ZERO
var _stride := 0.0

func _ready() -> void:
	collision_layer = 2 if kind == "player" else 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	target_position = position
	_last_position = position
	_clock = randf() * 10.0

func _process(delta: float) -> void:
	_clock += delta
	slash_time = maxf(0.0, slash_time - delta)
	hurt_time = maxf(0.0, hurt_time - delta)
	if not simulated:
		if position.distance_to(target_position) > 250.0:
			position = target_position
		else:
			position = position.lerp(target_position, 1.0 - exp(-18.0 * delta))
	# Stride advances with distance travelled so walk cycles match speed on every peer.
	var moved := position.distance_to(_last_position)
	_stride = _stride + moved if moved > 0.2 else 0.0
	# Enemies carry no aim in snapshots; face the direction they travel.
	if kind != "player" and moved > 0.6 and absf(position.x - _last_position.x) > 0.4:
		facing = Vector2(signf(position.x - _last_position.x), 0.0)
	_last_position = position
	queue_redraw()


## Full-resolution text for the stage overlay.
func get_overlay_labels() -> Array:
	var labels: Array = []
	if kind == "player":
		labels.append({"position": position + Vector2(0, -62), "text": display_name,
			"color": Color("e9efe8") if local_player else Color("b8c8c2"), "size": 13})
	elif kind == "boss":
		var callout := ""
		var color := Color("ffb077")
		match boss_state:
			"charge_windup": callout = "冲锋蓄力"
			"slam_windup": callout = "震地蓄力"
			"recovery":
				callout = "过热"
				color = Color("ffd68a")
		if not callout.is_empty():
			labels.append({"position": position + Vector2(0, -radius - 72), "text": callout, "color": color, "size": 14})
	return labels


func _draw() -> void:
	_draw_shadow()
	if kind == "boss":
		_draw_boss_telegraph()
	if windup > 0.0 and kind != "boss":
		_draw_windup()
	match kind:
		"player": _draw_player()
		"slime": _draw_fog_mass()
		"guard": _draw_security_unit()
		_: _draw_warden()
	if burning and kind != "player":
		_draw_burning()
	if hp < max_hp or kind == "boss":
		_draw_health()
	if kind == "player" and local_player and relic_charge > 0:
		for index in range(3):
			_pixel_block(Vector2((index - 1) * 9 - 3, radius + 9), Vector2(2, 1), Color("9be8ed") if index < relic_charge else Color("38565d"))


func _pixel_block(offset: Vector2, size: Vector2, color: Color) -> void:
	draw_rect(Rect2((offset / Art.SCALE).round() * Art.SCALE, size * Art.SCALE), color)


func _draw_shadow() -> void:
	var width := radius + 8.0
	draw_set_transform(Vector2(0, radius * 0.75), 0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, width, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if local_player:
		draw_set_transform(Vector2(0, radius * 0.75), 0, Vector2(1.0, 0.4))
		draw_arc(Vector2.ZERO, width + 6.0, 0, TAU, 28, Color(0.6, 0.93, 0.8, 0.55), 4.0, false)
		draw_set_transform(Vector2.ZERO)


func _draw_sprite(sprite: String, foot: Vector2, flip: bool, tint_color: Color = Color.WHITE, alpha: float = 1.0) -> void:
	if hurt_time > 0.0 and fmod(hurt_time, 0.12) > 0.06:
		Art.draw(self, Art.silhouette(sprite), foot, flip, Color(1, 1, 1, alpha))
		return
	Art.draw(self, Art.texture(sprite), foot, flip, Color(1, 1, 1, alpha))
	var layer := Art.tint_layer(sprite)
	if layer != null:
		Art.draw(self, layer, foot, flip, Color(tint_color, alpha))


func _draw_player() -> void:
	var direction := _normalized(facing)
	var flip := direction.x < 0.0
	var frame := "player_idle"
	if _stride > 0.0:
		frame = "player_walk_a" if int(_stride / 22.0) % 2 == 0 else "player_walk_b"
	var foot := Vector2(0, radius - 2)
	var aiming_back := direction.y < -0.35
	# The tool is drawn behind the body when aiming away from the camera.
	if aiming_back:
		_draw_tool(direction)
	_draw_sprite(frame, foot, flip, tint)
	if not aiming_back:
		_draw_tool(direction)
	if slash_time > 0.0 and weapon_kind not in ["projectile", "ranged", "crossbow", "bow"]:
		var angle := direction.angle()
		var fade := clampf(slash_time / 0.18, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 78, angle - 0.9, angle + 0.9, 14, Color(1.0, 0.89, 0.61, fade), 6.0, false)
		draw_arc(Vector2.ZERO, 66, angle - 0.6, angle + 0.6, 10, Color(1.0, 0.97, 0.85, fade * 0.6), 3.0, false)


func _draw_tool(direction: Vector2) -> void:
	var ranged := weapon_kind in ["projectile", "ranged", "crossbow", "bow"]
	var sprite := "nailgun" if ranged else "crowbar"
	var tex := Art.texture(sprite)
	if tex == null:
		return
	var angle := direction.angle()
	var flash := clampf(slash_time / 0.18, 0.0, 1.0)
	if not ranged and slash_time > 0.0:
		# Swing from one side of the arc to the other.
		angle += lerpf(0.9, -0.9, 1.0 - flash)
	var hand := Vector2(direction.x * 6.0, -3.0)
	var recoil := -direction * flash * 6.0 if ranged else Vector2.ZERO
	var mirror := -1.0 if direction.x < 0.0 else 1.0
	var size := tex.get_size() * Art.SCALE
	var grip := Vector2(3.0, size.y * 0.5) if not ranged else Vector2(6.0, 12.0)
	draw_set_transform(((hand + recoil) / Art.SCALE).round() * Art.SCALE, angle, Vector2(1.0, mirror))
	draw_texture_rect(tex, Rect2(-grip, size), false)
	if ranged and slash_time > 0.0:
		var muzzle := Vector2(size.x - grip.x + 3.0, -3.0)
		draw_rect(Rect2(muzzle, Vector2(6, 3)), Color(1.0, 0.91, 0.65, flash))
		draw_rect(Rect2(muzzle + Vector2(3, -3), Vector2(3, 9)), Color(1.0, 0.8, 0.45, flash * 0.7))
	draw_set_transform(Vector2.ZERO)


func _draw_fog_mass() -> void:
	var wobble := sin(_clock * 3.0) * 0.08
	var foot := Vector2(0, radius - 3)
	draw_set_transform(foot, 0, Vector2(1.0 - wobble * 0.5, 1.0 + wobble))
	_draw_sprite("fog_mass", Vector2.ZERO, sin(_clock * 0.7) < 0.0, Color.WHITE, 0.88)
	draw_set_transform(Vector2.ZERO)
	# Loose wisps peel off and rise.
	for index in range(3):
		var age := fmod(_clock * 0.55 + index * 0.33, 1.0)
		var drift := Vector2(sin(_clock + index * 2.0) * 9.0 + (index - 1) * 12.0, -18.0 - age * 36.0)
		_pixel_block(drift, Vector2(1, 1), Color(Art.FOG_LIGHT, 0.6 * (1.0 - age)))


func _draw_security_unit() -> void:
	var bob := roundf(sin(_clock * 4.0) * 1.0) * Art.SCALE
	var foot := Vector2(0, radius - 1 + bob)
	var flip := facing.x < 0.0
	_draw_sprite("security_unit", foot, flip, Color.WHITE)
	# The visor eye sweeps while idle and locks red when winding up a strike.
	var top := foot.y - 14 * Art.SCALE
	var sweep := int(roundf((sin(_clock * 2.5) * 0.5 + 0.5) * 5.0))
	if windup > 0.0:
		_pixel_block(Vector2(-12, top + 18), Vector2(8, 1), Art.WARN_LIGHT)
	else:
		_pixel_block(Vector2(-12 + sweep * 3, top + 18), Vector2(3, 1), Art.WARN)
	# Hover jets flicker under the chassis.
	if fmod(_clock * 10.0, 1.0) < 0.6:
		_pixel_block(Vector2(-12, foot.y + 3 - bob), Vector2(2, 1), Color(Art.FOG_LIGHT, 0.6))
		_pixel_block(Vector2(6, foot.y + 3 - bob), Vector2(2, 1), Color(Art.FOG_LIGHT, 0.6))


func _draw_warden() -> void:
	var foot := Vector2(0, radius - 4)
	var hot := boss_state == "recovery"
	var shake := Vector2.ZERO
	if boss_state in ["charge_windup", "slam_windup"]:
		shake.x = roundf(sin(_clock * 40.0)) * Art.SCALE
	var modulate_color := Color(0.75, 0.68, 0.62) if hot else Color.WHITE
	if hurt_time > 0.0 and fmod(hurt_time, 0.12) > 0.06:
		Art.draw(self, Art.silhouette("warden"), foot + shake, facing.x < 0.0)
	else:
		Art.draw(self, Art.texture("warden"), foot + shake, facing.x < 0.0, modulate_color)
	var top := foot.y - 18 * Art.SCALE
	# Sensor bar: a scanning red slit, or a full alarm bar while telegraphing.
	if boss_state in ["charge_windup", "slam_windup", "charge", "slam"]:
		_pixel_block(Vector2(-27, top + 12) + shake, Vector2(18, 2), Art.WARN_LIGHT if fmod(_clock * 8.0, 1.0) < 0.5 else Art.WARN)
	elif not hot:
		var sweep := int(roundf((sin(_clock * 1.8) * 0.5 + 0.5) * 14.0))
		_pixel_block(Vector2(-24 + sweep * 3, top + 13) + shake, Vector2(3, 1), Art.WARN)
	if hot:
		# Overheated vents glow and vent smoke: the window to punish it.
		for x in [-30, 24]:
			_pixel_block(Vector2(x, top + 21), Vector2(2, 2), Art.LAMP_WARM if fmod(_clock * 6.0, 1.0) < 0.5 else Art.ORANGE)
		for index in range(4):
			var age := fmod(_clock * 0.9 + index * 0.25, 1.0)
			_pixel_block(Vector2((index - 1.5) * 12.0 + sin(_clock * 3.0 + index) * 6.0, top - age * 42.0), Vector2(2, 2), Color(Art.GRAY_LIGHT, 0.55 * (1.0 - age)))


func _draw_windup() -> void:
	draw_circle(Vector2.ZERO, 56, Color(0.94, 0.35, 0.27, 0.14))
	draw_arc(Vector2.ZERO, 56, 0, TAU, 28, Color("ee8864"), 3.0, false)


func _draw_health() -> void:
	var cells := 20 if kind == "boss" else 12
	var top := -radius - (40.0 if kind == "boss" else 33.0) - (6.0 if kind == "guard" else 0.0)
	if kind == "player":
		top = -radius - 45.0
	var left := -cells * Art.SCALE * 0.5
	var fill := int(ceil(cells * clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)))
	_pixel_block(Vector2(left - 3, top - 3), Vector2(cells + 2, 3), Art.INK)
	_pixel_block(Vector2(left, top), Vector2(cells, 1), Color("3a1d1a"))
	var color := Color("dfa474") if kind != "player" else Color("80c5b5")
	if kind == "boss":
		color = Art.WARN_LIGHT
	if fill > 0:
		_pixel_block(Vector2(left, top), Vector2(fill, 1), color)


func _draw_boss_telegraph() -> void:
	var progress := clampf(telegraph_progress, 0.0, 1.0)
	var direction := _normalized(telegraph_direction)
	var pulse := 0.72 + sin(_clock * 11.0) * 0.18
	if boss_state == "charge_windup":
		var width := maxf(1.0, telegraph_radius)
		var length := maxf(1.0, telegraph_range)
		draw_set_transform(Vector2.ZERO, direction.angle())
		draw_rect(Rect2(0, -width, length, width * 2), Color(0.95, 0.36, 0.22, 0.13))
		draw_rect(Rect2(0, -width, length * progress, width * 2), Color(1.0, 0.48, 0.25, 0.19))
		draw_rect(Rect2(0, -width, length, width * 2), Color(1.0, 0.61, 0.36, pulse), false, 3.0)
		for index in range(1, 5):
			var x := length * float(index) / 5.0
			draw_polyline(PackedVector2Array([Vector2(x - 9, -9), Vector2(x, 0), Vector2(x - 9, 9)]), Color(1.0, 0.71, 0.45, pulse), 3.0)
		draw_set_transform(Vector2.ZERO)
	elif boss_state == "slam_windup":
		var size := maxf(1.0, telegraph_radius)
		draw_circle(Vector2.ZERO, size, Color(0.93, 0.29, 0.22, 0.11))
		draw_circle(Vector2.ZERO, size * progress, Color(0.96, 0.38, 0.24, 0.14))
		draw_arc(Vector2.ZERO, size, 0, TAU, 48, Color(1.0, 0.56, 0.37, pulse), 3.0, false)
		draw_arc(Vector2.ZERO, size * maxf(0.08, progress), 0, TAU, 40, Color(1.0, 0.72, 0.43, 0.8), 3.0, false)
		for index in range(12):
			var radial := Vector2.from_angle(TAU * index / 12.0)
			draw_line(radial * (size - 6), radial * (size + 6), Color("e9a178"), 3.0)
	elif boss_state == "charge":
		draw_set_transform(Vector2.ZERO, direction.angle())
		for index in range(3):
			var y := (index - 1) * radius * 0.65
			draw_line(Vector2(-radius, y), Vector2(-radius - 65 - index * 12, y), Color(1.0, 0.67, 0.37, 0.5), 3.0)
		draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2.ZERO, radius + 6, Color(1.0, 0.58, 0.2, 0.18))
	elif boss_state == "slam":
		draw_circle(Vector2.ZERO, telegraph_radius, Color(1.0, 0.45, 0.18, 0.12))
		draw_arc(Vector2.ZERO, telegraph_radius, 0, TAU, 48, Color("ffd39a"), 3.0, false)
	elif boss_state == "recovery":
		draw_arc(Vector2.ZERO, radius + 9, 0, TAU, 24, Color(1.0, 0.84, 0.54, 0.45), 3.0, false)


func _draw_burning() -> void:
	for index in range(3):
		var base := Vector2((index - 1) * radius * 0.6, -radius * 0.6)
		var height := 2 + int(roundf(sin(_clock * 13.0 + index * 2.1) + 1.0))
		_pixel_block(base, Vector2(2, 1), Art.WARN)
		_pixel_block(base + Vector2(0, -height * Art.SCALE), Vector2(1, height), Color(1.0, 0.55, 0.2, 0.9))
		_pixel_block(base + Vector2(3, -Art.SCALE), Vector2(1, 1), Art.LAMP)


func _normalized(direction: Vector2) -> Vector2:
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
