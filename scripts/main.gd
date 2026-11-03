extends Node2D
## Composition root: presentation/input, authoritative simulation, transport, persistence.

const Simulation = preload("res://scripts/systems/world_simulation.gd")
const Session = preload("res://scripts/systems/game_session.gd")
const Interface = preload("res://scripts/ui/game_ui.gd")
const Catalog = preload("res://scripts/systems/item_catalog.gd")
const Stage = preload("res://scripts/world/pixel_stage.gd")

var simulation: Node2D
var session: Node
var ui: CanvasLayer
var stage: Node
var _input_timer: float = 0.0
var _hud_timer: float = 0.0
var _snap_view := true
var _view_epoch := -1

func _ready() -> void:
	get_tree().auto_accept_quit = false
	stage = Stage.new()
	stage.name = "Stage"
	add_child(stage)
	simulation = Simulation.new()
	simulation.name = "World"
	stage.world_root.add_child(simulation)
	session = Session.new()
	session.name = "Session"
	add_child(session)
	session.configure(simulation)
	ui = Interface.new()
	add_child(ui)
	ui.solo_requested.connect(func(): session.start_solo())
	ui.host_requested.connect(_host)
	ui.join_requested.connect(_join)
	ui.leave_requested.connect(func(): session.stop())
	ui.equip_requested.connect(func(id: String): session.action("equip", id))
	ui.save_requested.connect(func():
		if session.save_now():
			ui.notify("回收员档案已保存" if session.mode == "client" else "回收员档案和雾区记录已保存"))
	session.started.connect(func():
		ui.show_game()
		_update_hud()
		_snap_view = true)
	session.ended.connect(func(reason: String): ui.show_menu(reason))
	session.message.connect(func(text: String):
		if ui.is_menu_open():
			ui.set_status(text)
		else:
			ui.notify(text))
	_parse_arguments.call_deferred()

func _host(port: int) -> void:
	var error: Error = session.host(port)
	if error != OK:
		ui.set_status("创建失败：%s。端口可能已占用。" % error_string(error))

func _join(address: String, port: int) -> void:
	var error: Error = session.join(address, port)
	ui.set_status("正在连接 %s:%d …" % [address, port] if error == OK else "连接失败：" + error_string(error))

func _process(delta: float) -> void:
	if not session.active:
		return
	_input_timer += delta
	_hud_timer += delta
	var id: int = session.local_id
	if simulation.players.has(id):
		var actor: Node2D = simulation.players[id].actor
		# A zone change teleports the party; jump the view instead of gliding across.
		if simulation.epoch != _view_epoch:
			_view_epoch = simulation.epoch
			_snap_view = true
		stage.follow(actor.position, simulation.zone.get_walk_rect(), delta, _snap_view)
		_snap_view = false
		_update_stage(id)
		for drop in simulation.loot.values():
			drop.actor.visible = int(drop.owner) == id
		if _input_timer >= 0.033:
			_input_timer = 0.0
			var motion := Vector2.ZERO
			var attacking := false
			if not ui.blocks_gameplay_input():
				motion = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
				attacking = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control() == null
			session.send_input(motion, stage.screen_to_world(get_viewport().get_mouse_position()) - actor.position, attacking)
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_update_hud()

func _update_stage(local_id: int) -> void:
	var zone: Node2D = simulation.zone
	var labels: Array = zone.get_labels()
	var lights: Array = zone.get_lights()
	for id in simulation.players:
		if id != local_id:
			lights.append({"position": simulation.players[id].actor.position, "radius": 170.0})
	for child in simulation.actors.get_children():
		if child.visible and child.has_method("get_overlay_labels"):
			labels.append_array(child.get_overlay_labels())
	stage.set_labels(labels)
	stage.update_fog(simulation.current_zone, simulation.players[local_id].actor.position, lights)

func _unhandled_input(event: InputEvent) -> void:
	if not session.active or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_I, KEY_ESCAPE:
			ui.toggle_inventory()
		KEY_E:
			if not ui.blocks_gameplay_input():
				session.action("interact")
		KEY_SPACE:
			if not ui.blocks_gameplay_input():
				session.action("dash")
		KEY_Q:
			if not ui.blocks_gameplay_input():
				_switch_weapon()

func _switch_weapon() -> void:
	if not simulation.players.has(session.local_id):
		return
	var profile: Dictionary = simulation.players[session.local_id].profile
	var weapons: Array[String] = []
	for item in Catalog.all_items():
		if item.slot == "weapon" and int(profile.inventory.get(item.id, 0)) > 0:
			weapons.append(item.id)
	if weapons.size() > 1:
		var next: int = (weapons.find(str(profile.equipped_weapon)) + 1) % weapons.size()
		session.action("equip", weapons[next])

func _update_hud() -> void:
	var id: int = session.local_id
	if not simulation.players.has(id):
		return
	var player: Dictionary = simulation.players[id]
	var profile: Dictionary = player.profile
	var inventory: Array = []
	for item in Catalog.all_items():
		var count := int(profile.inventory.get(item.id, 0))
		if count > 0:
			inventory.append({"id": item.id, "name": item.display_name, "description": item.description,
				"count": count, "slot": item.slot,
				"equipped": profile.equipped_weapon == item.id or profile.equipped_relic == item.id})
	var objective: String
	match simulation.current_zone:
		"camp": objective = "Q 切换撬棍与射钉枪，I 查看装备和异常物。沿道路向北按 E 进入外环雾区。"
		"wilds": objective = "穿过外环雾区：西北通往 7 号采样井，东北通往回声声学实验室。由房主开启闸门。"
		_: objective = "避开守卫者的冲锋走廊和重击范围。回收异常物后在装备箱中装备，再执行一轮任务。"
	var weapon: Resource = Catalog.get_item(profile.equipped_weapon)
	var relic: Resource = Catalog.get_item(profile.equipped_relic)
	ui.update_hud({"zone_title": simulation.zone.get_title(), "mode": {"offline": "单人行动", "host": "房主", "client": "好友房间"}[session.mode],
		"player_count": simulation.players.size(), "hp": player.hp, "max_hp": player.max_hp,
		"coins": profile.coins, "level": mini(20, 1 + int(profile.xp) / 40), "xp": profile.xp,
		"weapon_name": weapon.display_name, "weapon_kind": weapon.weapon_kind,
		"relic_name": relic.display_name if relic != null else "未装备", "relic_charge": player.relic_charge,
		"equipped_name": weapon.display_name, "objective": objective,
		"interaction": simulation.interaction_for(id), "inventory": inventory, "boss_kills": simulation.world_data.get("boss_kills", 0)})

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if session != null:
			session.save_now()
		get_tree().quit()

func _parse_arguments() -> void:
	var port := 24570
	var args := OS.get_cmdline_user_args()
	for argument in args:
		if argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
	for argument in args:
		if argument == "--solo":
			session.start_solo()
		elif argument == "--host":
			_host(port)
		elif argument.begins_with("--join="):
			_join(argument.trim_prefix("--join="), port)
