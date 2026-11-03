extends SceneTree
## Pixel-map sanity: consistent row widths, known palette keys, and every sprite rasterizes.

const Art = preload("res://scripts/art/pixel_art.gd")
const ZoneArt = preload("res://scripts/world/zone_art.gd")
const Zone = preload("res://scripts/world/zone_view.gd")

var _failures := 0


func _initialize() -> void:
	for problem in Art.validate():
		_fail(problem)
	for sprite: String in Art.SPRITES:
		var base: Texture2D = Art.texture(sprite)
		var flash: Texture2D = Art.silhouette(sprite)
		if base == null or flash == null or Vector2(base.get_size()) != Art.sprite_size(sprite):
			_fail("sprite did not rasterize: " + sprite)
	for zone_id: String in ["camp", "wilds", "mine", "crypt"]:
		var view: Node2D = Zone.new()
		view.build(zone_id)
		var image: Image = ZoneArt.bake(zone_id, view.get_blockers())
		view.free()
		if image == null or image.get_size() != ZoneArt.IMAGE_SIZE:
			_fail("zone did not bake: " + zone_id)
	print("art: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
