extends SceneTree
## Deterministic rule tests using real simulation, session checkpoints, and files.
## Transport arrival order is injected at the two real snapshot receiver methods;
## actual ENet connectivity belongs to the separate network smoke test.

const Simulation = preload("res://scripts/systems/world_simulation.gd")
const Session = preload("res://scripts/systems/game_session.gd")
const Catalog = preload("res://scripts/systems/item_catalog.gd")
const Saves = preload("res://scripts/systems/save_store.gd")

var checks: int = 0
var failures: int = 0
var simulation: Node2D
var session: Node
var test_directory: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_override: String = OS.get_environment("MISTBOUND_SAVE_DIR")
	if original_override.is_empty() or not original_override.is_absolute_path() or original_override.contains("://"):
		push_error("Gameplay tests require MISTBOUND_SAVE_DIR set to an absolute test directory.")
		quit(2)
		return
	test_directory = original_override.path_join("gameplay-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()])
	OS.set_environment("MISTBOUND_SAVE_DIR", test_directory.path_join("host"))
	simulation = Simulation.new()
	root.add_child(simulation)
	session = Session.new()
	root.add_child(session)
	session.configure(simulation)
	session.set_process(false)
	session.set_physics_process(false)
	_check(session.start_solo() == OK, "Real session starts in isolated directory.")
	simulation.add_player(2, Catalog.sanitize_profile({"name": "队友"}))
	await physics_frame
	_test_input_validation()
	_test_portal_authority()
	_test_loot_equipment_and_disconnect()
	_test_dungeon_reentry()
	_test_respawn()
	_test_gathering_and_crafting()
	_test_snapshot_arrival_order()
	OS.set_environment("MISTBOUND_SAVE_DIR", test_directory.path_join("host"))
	session.stop()
	session.queue_free()
	simulation.queue_free()
	await process_frame
	OS.set_environment("MISTBOUND_SAVE_DIR", original_override)
	print("Gameplay tests: %s checks, %s failures. Isolated files: %s" % [checks, failures, test_directory])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _test_input_validation() -> void:
	simulation.set_input(1, Vector2(100, 0), Vector2(0, -20), true)
	var player: Dictionary = simulation.players[1]
	_check(player.move.is_equal_approx(Vector2.RIGHT), "Oversized movement cannot increase speed.")
	_check(player.aim.is_equal_approx(Vector2.UP), "Valid aim is normalized.")
	simulation.set_input(1, Vector2.ZERO, Vector2.ZERO, false)
	_check(player.move == Vector2.ZERO and not player.attack, "Zero movement releases movement and attack.")
	_check(player.aim == Vector2.UP, "Zero aim preserves the last valid facing.")
	simulation.set_input(1, Vector2(NAN, 0), Vector2.RIGHT, true)
	_check(player.move == Vector2.ZERO and player.aim == Vector2.UP and not player.attack, "NaN movement rejects the whole input.")
	simulation.set_input(1, Vector2.RIGHT, Vector2(INF, 0), true)
	_check(player.move == Vector2.ZERO and player.aim == Vector2.UP and not player.attack, "Non-finite aim rejects the whole input.")
	simulation.set_input(999, Vector2.RIGHT, Vector2.RIGHT, true)
	_check(simulation.players.size() == 2, "Unknown peer input cannot create a player.")


func _test_portal_authority() -> void:
	var original_epoch: int = simulation.epoch
	simulation.players[1].actor.position = Vector2.ZERO
	simulation.act(1, "interact")
	_check(simulation.current_zone == "camp" and simulation.epoch == original_epoch, "Distant host interaction cannot cross a portal.")
	var portal: Dictionary = _portal_to("wilds")
	if portal.is_empty():
		return
	simulation.players[2].actor.position = portal.position
	simulation.act(2, "interact")
	_check(simulation.current_zone == "camp" and simulation.epoch == original_epoch, "Guest at the portal cannot change the party's zone.")
	_cross_to("wilds")
	_check(simulation.epoch == original_epoch + 1, "Host crossing advances the zone epoch once.")
	_check(simulation.players[2].actor.position == simulation.zone.get_spawn(1), "Host crossing brings the guest to the new spawn.")
	_check("wilds" in Saves.load_world().visited, "Real session checkpoint saves exploration.")
	_cross_to("mine")


func _test_loot_equipment_and_disconnect() -> void:
	var boss_id: int = _find_enemy("boss")
	_check(boss_id != 0, "Mine contains a boss.")
	if boss_id == 0:
		return
	var old_kills: int = simulation.world_data.boss_kills
	var old_xp: int = simulation.get_profile(2).xp
	simulation.players[1].actor.position = simulation.enemies[boss_id].actor.position - Vector2(50, 0)
	simulation.set_input(1, Vector2.ZERO, Vector2.RIGHT, false)
	# Exercise the production attack/damage/death path without a timed AI duel.
	for strike: int in range(64):
		if not simulation.enemies.has(boss_id):
			break
		simulation.players[1].attack_cd = 0.0
		simulation._attack(1)
	_check(not simulation.enemies.has(boss_id), "Normal attack damage defeats the boss.")
	_check(simulation.world_data.boss_kills == old_kills + 1, "Boss defeat records one world kill.")
	_check(simulation.get_profile(2).xp > old_xp, "Party member receives shared experience.")
	_check(simulation.loot.size() == 2, "Boss creates one private drop per player.")
	var owned_ids: Dictionary = {}
	for id: int in simulation.loot:
		var drop: Dictionary = simulation.loot[id]
		owned_ids[int(drop.owner)] = id
		drop.actor.position = Vector2(-200, 0) if int(drop.owner) == 1 else Vector2(200, 0)
	_check(owned_ids.has(1) and owned_ids.has(2), "Drops have distinct player ownership.")
	if not owned_ids.has(1) or not owned_ids.has(2):
		return
	var before: Dictionary = simulation.get_profile(1)
	simulation.players[1].actor.position = simulation.loot[owned_ids[2]].actor.position
	simulation.act(1, "interact")
	_check(simulation.loot.has(owned_ids[2]) and simulation.get_profile(1) == before, "Host cannot claim the guest's nearby drop.")
	simulation.players[1].actor.position = simulation.loot[owned_ids[1]].actor.position
	simulation.act(1, "interact")
	var collected: Dictionary = simulation.get_profile(1)
	_check(not simulation.loot.has(owned_ids[1]) and collected.coins > before.coins, "Owned pickup consumes drop and grants coins.")
	_check(collected.inventory.get("ember_relic", 0) == 1, "Boss pickup grants the expected relic once.")
	_check(collected.blueprints == ["hydraulic_cutter"], "Boss pickup unlocks the facility blueprint on the character.")
	_check(simulation.players[1].haul == {"scrap_metal": 3} and not collected.inventory.has("scrap_metal"), "Dropped materials are carried, not banked.")
	simulation.act(1, "interact")
	_check(simulation.get_profile(1) == collected, "Repeated interaction cannot duplicate a consumed drop.")
	simulation.act(1, "equip", "storm_relic")
	_check(simulation.get_profile(1).equipped_relic == "", "Known but unowned relic is rejected.")
	simulation.act(1, "equip", "unknown")
	_check(simulation.get_profile(1).equipped_weapon == "traveler_blade" and simulation.get_profile(1).equipped_relic == "", "Unknown equipment is rejected.")
	simulation.act(1, "equip", "ember_relic")
	_check(simulation.get_profile(1).equipped_relic == "ember_relic" and simulation.get_profile(1).equipped_weapon == "traveler_blade", "Owned relic equips independently from the weapon.")
	_check(Saves.load_character() == simulation.get_profile(1), "Pickup and equipment checkpoint persist the real host profile.")
	simulation.remove_player(2)
	_check(not simulation.players.has(2) and not simulation.loot.has(owned_ids[2]), "Disconnect removes the player and their private loot.")


func _test_dungeon_reentry() -> void:
	var old_epoch: int = simulation.epoch
	var old_ids: Array = simulation.enemies.keys()
	var kills: int = simulation.world_data.boss_kills
	_cross_to("wilds")
	_cross_to("mine")
	_check(simulation.epoch == old_epoch + 2, "Leaving and reentering the dungeon advances epochs.")
	_check(simulation.enemies.size() == simulation.zone.get_enemy_spawns().size(), "Dungeon reentry restores its full encounter set.")
	var boss_id: int = _find_enemy("boss")
	_check(boss_id != 0 and not old_ids.has(boss_id), "Reentry creates a fresh boss entity.")
	if boss_id != 0:
		_check(simulation.enemies[boss_id].hp == simulation.enemies[boss_id].max_hp, "Respawned dungeon boss has full health.")
	_check(simulation.loot.is_empty(), "Old dungeon loot does not survive a new instance.")
	_check(simulation.world_data.boss_kills == kills, "Dungeon reset preserves long-term world progress.")


func _test_respawn() -> void:
	var enemy_id: int = _find_enemy("slime")
	_check(enemy_id != 0, "Respawn test has a normal attacker.")
	if enemy_id == 0:
		return
	for id: int in simulation.enemies:
		simulation.enemies[id].actor.position = Vector2(750, 400)
	var player: Dictionary = simulation.players[1]
	var enemy: Dictionary = simulation.enemies[enemy_id]
	player.actor.position = Vector2.ZERO
	player.hp = 1.0
	player.invulnerability = 0.0
	player.dash_time = 0.0
	simulation.set_input(1, Vector2.ZERO, Vector2.RIGHT, false)
	enemy.actor.position = Vector2(10, 0)
	enemy.state = "melee_windup"
	enemy.state_time = 0.44
	enemy.windup = 0.01
	var coins_before: int = player.profile.coins
	player.haul = {"scrap_metal": 4, "core_sample": 2}
	var banked_before: Dictionary = player.profile.inventory.duplicate(true)
	simulation.step(0.02)
	_check(player.hp == player.max_hp and player.actor.position == simulation.zone.get_spawn(0), "Lethal enemy strike respawns the player at the entrance.")
	_check(player.haul.is_empty() and player.profile.inventory == banked_before, "Death loses carried materials without touching banked items.")
	_check(player.profile.coins == maxi(0, coins_before - 5), "Death applies the bounded coin penalty.")
	_check(player.invulnerability > 0.0 and player.dash_time == 0.0, "Respawn protection does not activate a dash.")
	var spawn: Vector2 = player.actor.position
	simulation.step(0.05)
	_check(player.actor.velocity == Vector2.ZERO and player.actor.position.is_equal_approx(spawn), "Idle respawn protection causes no phantom movement.")
	enemy.actor.position = spawn + Vector2(10, 0)
	enemy.state = "melee_windup"
	enemy.state_time = 0.44
	enemy.windup = 0.01
	simulation.step(0.02)
	_check(player.hp == player.max_hp, "Respawn invulnerability blocks an immediate enemy strike.")
	simulation.step(1.3)
	enemy.state = "melee_windup"
	enemy.state_time = 0.44
	enemy.windup = 0.01
	simulation.step(0.02)
	_check(player.hp < player.max_hp, "Player takes damage after respawn invulnerability expires.")


func _test_gathering_and_crafting() -> void:
	var player: Dictionary = simulation.players[1]
	var nodes: Array = simulation.zone.get_resource_nodes()
	_check(nodes.size() == 4 and nodes[0].item_id == "core_sample", "Mine offers core sample gathering points.")
	if nodes.size() != 4:
		return
	player.haul = {}
	player.actor.position = nodes[0].position + Vector2(200, 0)
	simulation.act(1, "interact")
	_check(player.haul.is_empty(), "A distant gathering point cannot be harvested.")
	player.actor.position = nodes[0].position
	_check(simulation.interaction_for(1) == "采集 矿样", "Standing on a gathering point offers to harvest it.")
	simulation.act(1, "interact")
	_check(player.haul == {"core_sample": 2}, "Harvest adds the material to the carried haul.")
	simulation.act(1, "interact")
	_check(player.haul == {"core_sample": 2} and simulation.interaction_for(1) == "", "A gathering point yields once per player per visit.")
	_check(not Saves.load_character().inventory.has("core_sample"), "Carried materials are not written to the character save.")
	_cross_to("wilds")
	_cross_to("mine")
	_check(player.haul == {"core_sample": 2}, "Carried materials survive moving between fog zones.")
	for node: Dictionary in simulation.zone.get_resource_nodes():
		player.actor.position = node.position
		simulation.act(1, "interact")
	_check(player.haul == {"core_sample": 10}, "Reentry refills gathering points.")
	player.haul["scrap_metal"] = 11
	simulation.act(1, "craft", "hydraulic_cutter")
	_check(not player.profile.inventory.has("hydraulic_cutter"), "Crafting is impossible outside the outpost.")
	_cross_to("wilds")
	_cross_to("camp")
	var profile: Dictionary = player.profile
	_check(player.haul.is_empty() and profile.inventory.get("core_sample", 0) == 10 and profile.inventory.get("scrap_metal", 0) == 11, "Returning to the outpost banks the haul.")
	_check(Saves.load_character() == simulation.get_profile(1), "Banked materials are saved with the character.")
	profile.coins = 45
	simulation.act(1, "craft", "hydraulic_cutter")
	_check(not profile.inventory.has("hydraulic_cutter"), "Crafting requires standing at the workbench.")
	var bench: Dictionary = simulation.zone.get_stations()[0]
	player.actor.position = bench.position
	_check(simulation.station_for(1) == "workbench", "The outpost workbench is detected in range.")
	var before: Dictionary = simulation.get_profile(1)
	simulation.act(1, "craft", "unknown")
	_check(simulation.get_profile(1) == before, "An unknown recipe is rejected.")
	profile.inventory["signal_coil"] = 6
	before = simulation.get_profile(1)
	simulation.act(1, "craft", "rapid_nailer")
	_check(simulation.get_profile(1) == before, "A recipe without its blueprint is rejected even with materials.")
	profile.inventory.erase("signal_coil")
	profile.coins = 39
	before = simulation.get_profile(1)
	simulation.act(1, "craft", "hydraulic_cutter")
	_check(simulation.get_profile(1) == before, "Crafting without enough coins changes nothing.")
	profile.coins = 45
	profile.inventory["core_sample"] = 5
	before = simulation.get_profile(1)
	simulation.act(1, "craft", "hydraulic_cutter")
	_check(simulation.get_profile(1) == before, "Crafting without enough materials changes nothing.")
	profile.inventory["core_sample"] = 6
	simulation.act(1, "craft", "hydraulic_cutter")
	_check(profile.inventory.get("hydraulic_cutter", 0) == 1 and profile.coins == 5, "Crafting grants the item and charges coins.")
	_check(profile.inventory.get("scrap_metal", 0) == 1 and not profile.inventory.has("core_sample"), "Crafting consumes exactly the recipe materials.")
	_check(Saves.load_character() == simulation.get_profile(1), "Crafted item is saved with the character.")
	profile.coins = 100
	profile.inventory["scrap_metal"] = 20
	profile.inventory["core_sample"] = 20
	before = simulation.get_profile(1)
	simulation.act(1, "craft", "hydraulic_cutter")
	_check(simulation.get_profile(1) == before, "An owned item cannot be crafted twice.")
	simulation.act(1, "equip", "hydraulic_cutter")
	_check(profile.equipped_weapon == "hydraulic_cutter", "Crafted weapon can be equipped.")
	simulation.act(1, "equip", "scrap_metal")
	_check(profile.equipped_weapon == "hydraulic_cutter" and profile.equipped_relic == "ember_relic", "A material cannot be equipped.")
	simulation.act(1, "equip", "traveler_blade")


func _test_snapshot_arrival_order() -> void:
	simulation.add_player(2, Catalog.sanitize_profile({"name": "队友"}))
	var replica: Node2D = Simulation.new()
	root.add_child(replica)
	replica.reset(false)
	var receiver: Node = Session.new()
	root.add_child(receiver)
	receiver.configure(replica)
	receiver.set_process(false)
	receiver.set_physics_process(false)
	receiver.mode = "client"
	receiver.local_id = 2
	OS.set_environment("MISTBOUND_SAVE_DIR", test_directory.path_join("client"))
	var initial: Dictionary = simulation.snapshot()
	receiver._receive_checkpoint(initial)
	_check(receiver.active and replica.epoch == simulation.epoch, "Initial reliable snapshot activates the client replica.")
	simulation.players[2].profile.coins = 17
	var delayed_reliable: Dictionary = simulation.snapshot()
	simulation.players[2].profile.coins = 29
	var newer_unreliable: Dictionary = simulation.snapshot()
	receiver._receive_state(newer_unreliable)
	receiver._receive_checkpoint(delayed_reliable)
	_check(replica.get_profile(2).coins == 29, "Late reliable checkpoint cannot roll back a newer unreliable snapshot.")
	receiver._receive_checkpoint(simulation.snapshot())
	_check(Saves.load_character().coins == 29, "Fresh reliable checkpoint persists the client's own profile.")
	OS.set_environment("MISTBOUND_SAVE_DIR", test_directory.path_join("host"))
	_cross_to("wilds")
	var transition: Dictionary = simulation.snapshot()
	OS.set_environment("MISTBOUND_SAVE_DIR", test_directory.path_join("client"))
	receiver._receive_checkpoint(transition)
	_check(replica.current_zone == "wilds" and replica.epoch == simulation.epoch, "New epoch changes the client zone.")
	var stale_epoch: Dictionary = initial.duplicate(true)
	stale_epoch.sequence = int(transition.sequence) + 100
	receiver._receive_state(stale_epoch)
	_check(replica.current_zone == "wilds" and replica.epoch == simulation.epoch, "Older epoch is rejected even with a higher sequence.")
	simulation.players[2].profile.coins = 31
	simulation.players[2].haul = {"scrap_metal": 2}
	simulation.players[2].harvested = [1]
	var valid_next: Dictionary = simulation.snapshot()
	receiver._receive_state(valid_next)
	_check(replica.get_profile(2).coins == 31, "Rejected old epoch does not poison the sequence watermark.")
	_check(replica.players[2].haul == {"scrap_metal": 2} and replica.players[2].harvested == [1], "Carried haul and harvested points replicate to the client.")
	var duplicate: Dictionary = valid_next.duplicate(true)
	for data: Dictionary in duplicate.players:
		if int(data.id) == 2:
			data.profile.coins = 999
	receiver._receive_checkpoint(duplicate)
	_check(replica.get_profile(2).coins == 31, "Duplicate sequence cannot mutate state across channels.")
	_check(not FileAccess.file_exists(test_directory.path_join("client/world.json")), "Client checkpoints never overwrite a host world save.")
	receiver.stop()
	receiver.queue_free()
	replica.queue_free()
	OS.set_environment("MISTBOUND_SAVE_DIR", test_directory.path_join("host"))


func _portal_to(target: String) -> Dictionary:
	for portal: Dictionary in simulation.zone.get_portals():
		if portal.target == target:
			return portal
	_check(false, "Expected connected portal to " + target)
	return {}


func _cross_to(target: String) -> void:
	var portal: Dictionary = _portal_to(target)
	if portal.is_empty():
		return
	simulation.players[1].actor.position = portal.position
	simulation.act(1, "interact")
	_check(simulation.current_zone == target, "Nearby host can cross to " + target)


func _find_enemy(kind: String) -> int:
	for id: int in simulation.enemies:
		if simulation.enemies[id].kind == kind:
			return id
	return 0
