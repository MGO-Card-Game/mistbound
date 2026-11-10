extends RefCounted
class_name RecipeCatalog

## A blueprint, its recipe and the crafted item share one ID. `zone` is the
## facility whose guardian drops the blueprint. Order here is display order.
const RECIPES: Dictionary = {
	"hydraulic_cutter": {"coins": 40, "materials": {"scrap_metal": 10, "core_sample": 6}, "zone": "mine"},
	"rapid_nailer": {"coins": 40, "materials": {"scrap_metal": 10, "signal_coil": 6}, "zone": "crypt"},
}


static func get_recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})


static func blueprint_for_zone(zone_id: String) -> String:
	for id: String in RECIPES:
		if RECIPES[id].zone == zone_id:
			return id
	return ""
