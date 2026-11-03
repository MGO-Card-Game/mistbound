extends Node2D
## Personal drop marker: a containment canister for anomalies, a supply crate otherwise.

const Art = preload("res://scripts/art/pixel_art.gd")

var tint: Color = Color("e6be78")
var anomaly: bool = false
var _clock: float = 0.0

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
	var glow := tint if anomaly else Art.HAZARD_LIGHT
	draw_circle(Vector2.ZERO, 24.0 + pulse * 6.0, Color(glow, 0.08 + pulse * 0.06))
	draw_set_transform(Vector2(0, 9), 0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	var bob := roundf(sin(_clock * 3.0)) * Art.SCALE
	var foot := Vector2(0, 9 + (bob - Art.SCALE if anomaly else 0.0))
	if anomaly:
		Art.draw(self, Art.texture("canister"), foot)
		Art.draw(self, Art.tint_layer("canister"), foot, false, tint.lightened(0.15 + pulse * 0.25))
	else:
		Art.draw(self, Art.texture("supply_crate"), foot)
	# A rising pickup chevron marks it as yours.
	var rise := fmod(_clock * 1.2, 1.0)
	var top := Vector2(-3, -36 - rise * 12.0)
	for offset in [Vector2(-6, 0), Vector2(-3, -3), Vector2(0, -6), Vector2(3, -3), Vector2(6, 0)]:
		draw_rect(Rect2(((top + offset) / Art.SCALE).round() * Art.SCALE, Vector2.ONE * Art.SCALE), Color(glow, 0.9 * (1.0 - rise)))
