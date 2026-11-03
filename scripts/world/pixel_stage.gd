class_name PixelStage
extends Node
## Renders the world into a low-resolution SubViewport (1 px = PixelArt.SCALE world units)
## and upscales it with nearest filtering. The camera snaps to whole art pixels and the
## remainder shifts the upscaled image, so scrolling stays smooth without pixel shimmer.
## Text is drawn by a full-resolution overlay because CJK glyphs need real pixels.

const Art = preload("res://scripts/art/pixel_art.gd")
const FogShader = preload("res://scripts/world/fog.gdshader")

const MAX_LIGHTS := 24
const FOG := {
	"camp": {"color": Color("8aa39d"), "density": 0.26, "clear": 420.0, "ceiling": 0.45},
	"wilds": {"color": Color("7c9e96"), "density": 0.5, "clear": 330.0, "ceiling": 0.68},
	"mine": {"color": Color("120e0b"), "density": 0.62, "clear": 320.0, "ceiling": 0.72},
	"crypt": {"color": Color("171324"), "density": 0.6, "clear": 320.0, "ceiling": 0.72},
}

var viewport: SubViewport
var world_root: Node2D
var camera: Camera2D
var _display: TextureRect
var _overlay: Control
var _fog: Node2D
var _fog_material: ShaderMaterial
var _view_center := Vector2.ZERO
var _labels: Array = []
var _screen_size := Vector2.ZERO


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "PixelWorld"
	viewport.disable_3d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	viewport.add_child(world_root)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE / Art.SCALE
	viewport.add_child(camera)
	_fog = Node2D.new()
	_fog.name = "Fog"
	_fog.z_index = 1
	_fog_material = ShaderMaterial.new()
	_fog_material.shader = FogShader
	_fog_material.set_shader_parameter("art_pixel", Art.SCALE)
	_fog.material = _fog_material
	_fog.draw.connect(func() -> void: _fog.draw_rect(Rect2(-1400, -1000, 2800, 2000), Color.WHITE))
	viewport.add_child(_fog)
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_display = TextureRect.new()
	_display.texture = viewport.get_texture()
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_display)
	var labels_layer := CanvasLayer.new()
	labels_layer.layer = 1
	add_child(labels_layer)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_labels)
	labels_layer.add_child(_overlay)
	_resize()


## Moves the view toward `target` (world units) inside `limits`. `snap` skips smoothing.
func follow(target: Vector2, limits: Rect2, delta: float, snap: bool = false) -> void:
	_resize()
	var half := _screen_size * 0.5
	var goal := target
	if limits.size.x > _screen_size.x:
		goal.x = clampf(goal.x, limits.position.x + half.x, limits.end.x - half.x)
	else:
		goal.x = limits.get_center().x
	if limits.size.y > _screen_size.y:
		goal.y = clampf(goal.y, limits.position.y + half.y, limits.end.y - half.y)
	else:
		goal.y = limits.get_center().y
	_view_center = goal if snap else _view_center.lerp(goal, 1.0 - exp(-8.0 * delta))
	camera.position = (_view_center / Art.SCALE).round() * Art.SCALE
	var remainder := _view_center - camera.position
	_display.position = half - Vector2(viewport.size) * Art.SCALE * 0.5 - remainder


func screen_to_world(screen: Vector2) -> Vector2:
	return _view_center + screen - _screen_size * 0.5


func world_to_screen(world: Vector2) -> Vector2:
	return world - _view_center + _screen_size * 0.5


## Per-frame fog parameters: the local focus point, zone preset and light sources.
func update_fog(zone_id: String, focus: Vector2, lights: Array) -> void:
	var preset: Dictionary = FOG.get(zone_id, FOG["camp"])
	_fog_material.set_shader_parameter("focus", focus)
	_fog_material.set_shader_parameter("fog_color", preset.color)
	_fog_material.set_shader_parameter("density", preset.density)
	_fog_material.set_shader_parameter("clear_radius", preset.clear)
	_fog_material.set_shader_parameter("ceiling", preset.ceiling)
	var packed := PackedVector3Array()
	for light: Dictionary in lights.slice(0, MAX_LIGHTS):
		var point: Vector2 = light.position
		packed.append(Vector3(point.x, point.y, float(light.radius)))
	var count := packed.size()
	packed.resize(MAX_LIGHTS)
	_fog_material.set_shader_parameter("lights", packed)
	_fog_material.set_shader_parameter("light_count", count)


## World-anchored text: [{position, text, color, size, centered}].
func set_labels(labels: Array) -> void:
	_labels = labels
	_overlay.queue_redraw()


func _resize() -> void:
	var size := _display.get_viewport_rect().size if _display != null and _display.is_inside_tree() else Vector2(1280, 800)
	if size == _screen_size:
		return
	_screen_size = size
	# Two spare art pixels per side cover the sub-pixel shift; keep the size even.
	var pixels := Vector2i((size / Art.SCALE).ceil()) + Vector2i(4, 4)
	pixels += Vector2i(pixels.x % 2, pixels.y % 2)
	viewport.size = pixels
	_display.size = Vector2(pixels) * Art.SCALE


func _draw_labels() -> void:
	var font := Art.font()
	for label: Dictionary in _labels:
		var text := str(label.get("text", ""))
		if text.is_empty():
			continue
		var size := Art.font_size(int(label.get("size", 15)))
		var color: Color = label.get("color", Color.WHITE)
		var at := world_to_screen(label.get("position", Vector2.ZERO))
		if bool(label.get("centered", true)):
			at.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
		at = at.round()
		# A one-pixel hard outline keeps the pixel glyphs readable over fog and props.
		var outline := Color(Art.INK, color.a * 0.9)
		for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
			_overlay.draw_string(font, at + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline)
		_overlay.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
