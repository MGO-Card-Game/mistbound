extends RefCounted
## Custom-drawn HUD pieces that share the stage's art-pixel grid.

const Art = preload("res://scripts/art/pixel_art.gd")

const UNIT := 3


## Segmented bar. Lost value lingers as a pale ghost before draining, and the fill
## blinks once it falls under `alarm_ratio`.
class Meter extends Control:
	var maximum := 1.0
	var value := 1.0
	var fill := Color("7fc7a8")
	var back := Color("1b1012")
	var alarm_ratio := 0.0
	var _ghost := 1.0
	var _hold := 0.0
	var _clock := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## `snap` drops the ghost at once, for a fresh target rather than a loss.
	func set_amount(next: float, next_maximum: float, snap: bool = false) -> void:
		maximum = maxf(1.0, next_maximum)
		next = clampf(next, 0.0, maximum)
		if snap or next >= _ghost:
			_ghost = next
		elif next < value:
			_hold = 0.35
		value = next
		queue_redraw()

	func _process(delta: float) -> void:
		_clock += delta
		if _ghost > value:
			_hold -= delta
			if _hold <= 0.0:
				_ghost = maxf(value, _ghost - maximum * 0.9 * delta)
			queue_redraw()
		elif alarm_ratio > 0.0 and value / maximum <= alarm_ratio:
			queue_redraw()

	func _draw() -> void:
		var cells := maxi(1, int((size.x - UNIT * 2) / UNIT))
		var inner := Rect2(UNIT, UNIT, cells * UNIT, maxf(UNIT, size.y - UNIT * 2))
		draw_rect(Rect2(0, 0, inner.size.x + UNIT * 2, inner.size.y + UNIT * 2), Art.INK)
		draw_rect(inner, back)
		var lit := int(ceil(cells * value / maximum))
		var ghost := int(ceil(cells * _ghost / maximum))
		if ghost > lit:
			draw_rect(Rect2(inner.position + Vector2(lit * UNIT, 0), Vector2((ghost - lit) * UNIT, inner.size.y)), Art.BONE)
		var color := fill
		if alarm_ratio > 0.0 and value / maximum <= alarm_ratio:
			color = Art.WARN_LIGHT if fmod(_clock * 3.0, 1.0) < 0.5 else Art.WARN
		if lit > 0:
			draw_rect(Rect2(inner.position, Vector2(lit * UNIT, inner.size.y)), color)
			draw_rect(Rect2(inner.position, Vector2(lit * UNIT, UNIT)), color.lightened(0.25))
			# Dark seams every third art pixel make the fill read as cells.
			for cell in range(2, lit, 3):
				draw_rect(Rect2(inner.position + Vector2(cell * UNIT, 0), Vector2(UNIT, inner.size.y)), color.darkened(0.45))


## Framed icon cell. `cooldown` (0–1) shades the cell from the top while recharging.
class Slot extends Control:
	const CELL := 16

	var texture: Texture2D
	var accent := Color("30434a")
	var cooldown := 0.0
	var dimmed := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(CELL, CELL) * UNIT

	func set_icon(next: Texture2D, next_accent: Color, next_dimmed: bool = false) -> void:
		if texture == next and accent == next_accent and dimmed == next_dimmed:
			return
		texture = next
		accent = next_accent
		dimmed = next_dimmed
		queue_redraw()

	func set_cooldown(next: float) -> void:
		next = clampf(next, 0.0, 1.0)
		# Redraw only when the shade crosses a whole art pixel.
		if int(next * (CELL - 2)) != int(cooldown * (CELL - 2)) or (next > 0.0) != (cooldown > 0.0):
			queue_redraw()
		cooldown = next

	func _draw() -> void:
		var side := float(CELL * UNIT)
		draw_rect(Rect2(UNIT, 0, side - UNIT * 2, side), accent)
		draw_rect(Rect2(0, UNIT, side, side - UNIT * 2), accent)
		draw_rect(Rect2(UNIT, UNIT, side - UNIT * 2, side - UNIT * 2), Color("0f171a"))
		draw_rect(Rect2(UNIT, UNIT, side - UNIT * 2, UNIT), Color("0a0f11"))
		if texture != null:
			var at := ((Vector2(side, side) - texture.get_size()) * 0.5 / UNIT).round() * UNIT
			draw_texture(texture, at, Color(1, 1, 1, 0.35) if dimmed else Color.WHITE)
		if cooldown > 0.0:
			var rows := maxi(1, int(ceil(cooldown * (CELL - 2))))
			draw_rect(Rect2(UNIT, UNIT, side - UNIT * 2, rows * UNIT), Color(0.04, 0.06, 0.07, 0.78))
