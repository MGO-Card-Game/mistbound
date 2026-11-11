class_name GameUI
extends CanvasLayer
## Presentation-only UI. The session controller owns gameplay and persistence.
## The HUD keeps to the screen corners so the middle of the view stays clear:
## location and messages top-left, progress and buttons top-right, the body
## (health, tools, carried materials) bottom-left, prompts along the bottom.

signal solo_requested()
signal host_requested(port: int)
signal join_requested(address: String, port: int)
signal leave_requested()
signal equip_requested(item_id: String)
signal craft_requested(recipe_id: String)
signal save_requested()

const Art = preload("res://scripts/art/pixel_art.gd")
const PixelUI = preload("res://scripts/ui/pixel_ui.gd")
const Backdrop = preload("res://scripts/ui/menu_backdrop.gd")
const Widgets = preload("res://scripts/ui/hud_widgets.gd")
const Catalog = preload("res://scripts/systems/item_catalog.gd")

const INK := Color("0a0f11")
const PANEL := Color("141d21")
const PANEL_LIGHT := Color("1f2c31")
const LINE := Color("30434a")
const PAPER := Color("e9efe8")
const MUTED := Color("9aa8a2")
const GOLD := Color("f0c95a")
const TEAL := Color("9cc7bb")
const GOOD := Color("9be08a")
const BAD := Color("ff7a5c")

const BRIEF_SECONDS := 10.0
const KEYS_SECONDS := 14.0
const FEED_SECONDS := 5.5
const FEED_LIMIT := 5
const PANEL_WIDTH := 410
const KEY_HELP := [["WASD", "移动"], ["左键", "攻击"], ["空格", "闪避"], ["Q", "切换武器"],
	["E", "交互 / 回收"], ["I", "装备箱"], ["Esc", "行动菜单"]]
const BOSS_CALLOUTS := {
	"charge_windup": ["冲锋蓄力", Color("ffb077")],
	"slam_windup": ["震地蓄力", Color("ffb077")],
	"charge": ["冲锋", Color("ff7a5c")],
	"slam": ["震地", Color("ff7a5c")],
	"recovery": ["过热 · 输出窗口", Color("ffd68a")],
}
## Message borders: losses read red, gains read gold, the rest stay quiet.
const FEED_BAD := ["丢失", "失败", "不足", "尚未", "扣除"]
const FEED_GOOD := ["入库", "制作完成", "已排除", "蓝图", "已保存"]

var _root: Control
var _menu: Control
var _hud: MarginContainer
var _inventory_panel: PanelContainer
var _inventory_list: VBoxContainer
var _crafting_panel: PanelContainer
var _crafting_list: VBoxContainer
var _status: Label
var _address: LineEdit
var _port: SpinBox
var _zone: Label
var _session: Label
var _brief: PanelContainer
var _brief_time := 0.0
var _objective: Label
var _feed: VBoxContainer
var _feed_entries: Array[Dictionary] = []
var _level: Label
var _xp: Control
var _coins: Label
var _boss: VBoxContainer
var _boss_name: Label
var _boss_state: Label
var _boss_meter: Control
var _haul_panel: PanelContainer
var _haul_row: HBoxContainer
var _haul_signature := ""
var _haul_text := ""
var _health: Control
var _health_text: Label
var _weapon_slot: Control
var _weapon_name: Label
var _relic_slot: Control
var _relic_name: Label
var _relic_note: Label
var _dash_slot: Control
var _dash_cd := 0.0
var _dash_max := 0.85
var _interaction_panel: PanelContainer
var _interaction: Label
var _keys: PanelContainer
var _keys_time := 0.0
var _pause: Control
var _pause_zone: Label
var _pause_objective: Label
var _pause_actions: VBoxContainer
var _pause_confirm: VBoxContainer
var _pause_warning: Label
var _hosting_others := false
var _coins_value := 0
var _inventory_signature := ""
var _inventory: Array = []
var _recipes_signature := ""
var _recipes: Array = []


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "Interface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.theme = _make_theme()
	add_child(_root)
	_build_menu()
	_build_hud()
	_build_inventory()
	_build_crafting()
	_build_pause()
	if DisplayServer.get_name() != "headless":
		var reticle := PixelUI.crosshair()
		Input.set_custom_mouse_cursor(reticle, Input.CURSOR_CROSS, Vector2(reticle.get_size() / 2))
	show_menu()


func _process(delta: float) -> void:
	if _menu.visible:
		return
	for index in range(_feed_entries.size() - 1, -1, -1):
		var entry: Dictionary = _feed_entries[index]
		entry.time = float(entry.time) - delta
		entry.node.modulate.a = clampf(float(entry.time) / 0.6, 0.0, 1.0)
		if float(entry.time) <= 0.0:
			entry.node.queue_free()
			_feed_entries.remove_at(index)
	if _brief_time > 0.0:
		_brief_time = maxf(0.0, _brief_time - delta)
		_brief.modulate.a = minf(_brief_time, 1.0)
		_brief.visible = _brief_time > 0.0
	if _keys_time > 0.0:
		_keys_time = maxf(0.0, _keys_time - delta)
		_keys.modulate.a = minf(_keys_time, 1.0)
	_keys.visible = _keys_time > 0.0 and not blocks_gameplay_input()
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_dash_slot.set_cooldown(_dash_cd / _dash_max)


func show_menu(message: String = "") -> void:
	_menu.show()
	_hud.hide()
	_inventory_panel.hide()
	_crafting_panel.hide()
	_pause.hide()
	_clear_feed()
	set_status(message)
	_sync_cursor()


func show_game() -> void:
	_menu.hide()
	_hud.show()
	_inventory_panel.hide()
	_crafting_panel.hide()
	_pause.hide()
	_clear_feed()
	_brief_time = BRIEF_SECONDS
	_keys_time = KEYS_SECONDS
	_root.get_viewport().gui_release_focus()
	_sync_cursor()


func set_status(message: String) -> void:
	_status.text = message


func is_menu_open() -> bool:
	return _menu.visible


func blocks_gameplay_input() -> bool:
	return _menu.visible or _inventory_panel.visible or _crafting_panel.visible or _pause.visible


func toggle_inventory() -> void:
	if is_menu_open() or _pause.visible:
		return
	_crafting_panel.hide()
	_inventory_panel.visible = not _inventory_panel.visible
	if not _inventory_panel.visible:
		_root.get_viewport().gui_release_focus()
	_sync_cursor()


func is_crafting_open() -> bool:
	return _crafting_panel.visible


func open_crafting() -> void:
	if is_menu_open() or _pause.visible:
		return
	_inventory_panel.hide()
	_crafting_panel.show()
	_sync_cursor()


func close_crafting() -> void:
	_crafting_panel.hide()
	_root.get_viewport().gui_release_focus()
	_sync_cursor()


func is_pause_open() -> bool:
	return _pause.visible


## Esc backs out of whatever is open, innermost first, and otherwise opens the menu.
func handle_escape() -> void:
	if is_menu_open():
		return
	if _crafting_panel.visible:
		close_crafting()
	elif _inventory_panel.visible:
		toggle_inventory()
	elif _pause.visible and _pause_confirm.visible:
		_ask_leave(false)
	else:
		set_pause(not _pause.visible)


func set_pause(open: bool) -> void:
	if is_menu_open():
		return
	_inventory_panel.hide()
	_crafting_panel.hide()
	_ask_leave(false)
	_pause.visible = open
	if not open:
		_root.get_viewport().gui_release_focus()
	_sync_cursor()


func notify(message: String) -> void:
	if is_menu_open() or message.is_empty():
		return
	var border := LINE
	for word: String in FEED_GOOD:
		if message.contains(word):
			border = GOLD
	for word: String in FEED_BAD:
		if message.contains(word):
			border = BAD
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.92), border, 12, 7))
	chip.add_child(_wrapped_label(message, 12, PAPER, 276))
	_feed.add_child(chip)
	_feed_entries.append({"node": chip, "time": FEED_SECONDS + message.length() * 0.03})
	while _feed_entries.size() > FEED_LIMIT:
		_feed_entries.pop_front().node.queue_free()


func update_hud(state: Dictionary) -> void:
	var zone_title := str(state.get("zone_title", "雾线前哨"))
	if zone_title != _zone.text:
		_zone.text = zone_title
		_brief_time = BRIEF_SECONDS
	var mode := str(state.get("mode", "单人行动"))
	var player_count := int(state.get("player_count", 1))
	_session.text = "%s  ·  %d / 4 人" % [mode, player_count]
	_hosting_others = mode == "房主" and player_count > 1
	_pause_zone.text = "%s  ·  %s" % [zone_title, _session.text]
	var hp := float(state.get("hp", 100.0))
	var maximum := maxf(1.0, float(state.get("max_hp", 100.0)))
	_health.set_amount(hp, maximum)
	_health_text.text = "%d / %d" % [int(ceil(hp)), int(maximum)]
	_level.text = "Lv.%d" % int(state.get("level", 1))
	_xp.set_amount(float(state.get("xp_into", 0)), float(state.get("xp_step", 40)), true)
	_coins_value = int(state.get("coins", 0))
	_coins.text = str(_coins_value)
	_weapon_slot.set_icon(_item_icon(str(state.get("weapon_id", "traveler_blade"))), LINE)
	_weapon_name.text = str(state.get("weapon_name", state.get("equipped_name", "破拆撬棍")))
	var relic_id := str(state.get("relic_id", ""))
	var charge := int(state.get("relic_charge", 0))
	if relic_id.is_empty():
		_relic_slot.set_icon(PixelUI.icon("canister", LINE), LINE, true)
		_relic_name.text = "未装备"
		_relic_note.text = "异常物"
	else:
		_relic_slot.set_icon(_item_icon(relic_id), _item_color(relic_id).darkened(0.35))
		_relic_name.text = str(state.get("relic_name", ""))
		_relic_note.text = "蓄能 %d / 3" % charge if charge > 0 else "异常物"
	_relic_name.add_theme_color_override("font_color", MUTED if relic_id.is_empty() else PAPER)
	_relic_note.add_theme_color_override("font_color", TEAL if charge > 0 else MUTED)
	_dash_max = maxf(0.05, float(state.get("dash_max", 0.85)))
	_dash_cd = float(state.get("dash_cd", 0.0))
	_objective.text = str(state.get("objective", "穿过雾区，找到废弃设施的入口。"))
	_pause_objective.text = _objective.text
	var interaction_text := str(state.get("interaction", ""))
	_interaction.text = interaction_text
	_interaction_panel.visible = not interaction_text.is_empty() and not blocks_gameplay_input()
	_update_boss(state.get("boss", {}))
	_update_haul(state.get("haul", []))
	var items: Array = state.get("inventory", [])
	var signature := JSON.stringify(items)
	if signature != _inventory_signature:
		_inventory_signature = signature
		_inventory = items.duplicate(true)
		_refresh_inventory()
	var recipes: Array = state.get("recipes", [])
	var recipes_signature := "%d:%s" % [_coins_value, JSON.stringify(recipes)]
	if recipes_signature != _recipes_signature:
		_recipes_signature = recipes_signature
		_recipes = recipes.duplicate(true)
		_refresh_crafting()
	# The party can be pulled away from the workbench while the panel is open.
	if _crafting_panel.visible and str(state.get("station", "")) != "workbench":
		close_crafting()


func _update_boss(boss: Dictionary) -> void:
	var fresh := not _boss.visible
	_boss.visible = not boss.is_empty()
	if boss.is_empty():
		return
	_boss_name.text = str(boss.get("name", "守卫者"))
	_boss_meter.set_amount(float(boss.get("hp", 0.0)), float(boss.get("max_hp", 1.0)), fresh)
	var callout: Array = BOSS_CALLOUTS.get(str(boss.get("state", "")), ["", PAPER])
	_boss_state.text = callout[0]
	_boss_state.add_theme_color_override("font_color", callout[1])


func _update_haul(haul: Array) -> void:
	var signature := JSON.stringify(haul)
	if signature == _haul_signature:
		return
	_haul_signature = signature
	for child in _haul_row.get_children():
		_haul_row.remove_child(child)
		child.queue_free()
	var parts: PackedStringArray = []
	for entry: Dictionary in haul:
		var item_id := str(entry.get("id", ""))
		_haul_row.add_child(_count_chip(item_id, "×%d" % int(entry.count), PAPER))
		parts.append("%s ×%d" % [str(entry.name), int(entry.count)])
	_haul_text = "、".join(parts)
	_haul_panel.visible = not haul.is_empty()


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = Art.font()
	theme.default_font_size = Art.font_size(12)
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", PAPER)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("normal", "Button", _box(Color("2a3a40"), INK, 14, 10))
	theme.set_stylebox("hover", "Button", _box(Color("35494f"), GOLD, 14, 10))
	theme.set_stylebox("pressed", "Button", PixelUI.box(Color("172226"), GOLD, 14, 10, true))
	theme.set_stylebox("disabled", "Button", _box(Color("1a2529"), INK, 14, 10))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "LineEdit", PixelUI.box(Color("0f171a"), INK, 12, 10, true))
	theme.set_stylebox("focus", "LineEdit", PixelUI.box(Color("0f171a"), TEAL, 12, 10, true))
	theme.set_color("font_color", "LineEdit", PAPER)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_stylebox("separator", "HSeparator", _separator())
	theme.set_constant("separation", "HSeparator", 12)
	return theme


func _separator() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PixelUI.hazard_strip()
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_menu)
	var background := ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(background)
	_menu.add_child(Backdrop.new())
	var top_rule := TextureRect.new()
	top_rule.texture = PixelUI.hazard_strip()
	top_rule.stretch_mode = TextureRect.STRETCH_TILE
	top_rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_rule.offset_bottom = 6
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(top_rule)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 32
	center.offset_top = 20
	center.offset_right = -32
	center.offset_bottom = -30
	_menu.add_child(center)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 44)
	center.add_child(columns)
	var intro_panel := PanelContainer.new()
	intro_panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.08, 0.09, 0.82), INK, 28, 24))
	columns.add_child(intro_panel)
	var intro := VBoxContainer.new()
	intro.custom_minimum_size.x = 470
	intro.add_theme_constant_override("separation", 15)
	intro_panel.add_child(intro)
	intro.add_child(_label("CO-OP RECOVERY RPG  /  开发原型", 13, TEAL))
	var logotype := TextureRect.new()
	logotype.texture = PixelUI.logotype("MISTBOUND", 6, PAPER, Color("2c4a46"))
	logotype.stretch_mode = TextureRect.STRETCH_KEEP
	logotype.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_child(logotype)
	intro.add_child(_label("雾区回收队", 29, GOLD))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	intro.add_child(spacer)
	intro.add_child(_wrapped_label("进去，找到它，活着带出来。", 23, PAPER, 450))
	intro.add_child(_wrapped_label("雾里的设施早已废弃，留下的东西却没有安静下来。\n组队进入，把异常物带回前哨。", 17, MUTED, 450))
	var features := VBoxContainer.new()
	features.add_theme_constant_override("separation", 16)
	features.add_theme_stylebox_override("panel", _box(PANEL, LINE))
	intro.add_child(features)
	features.add_child(_label("01   前哨雾区     从前哨出发，深入相连的雾区", 16, PAPER))
	features.add_child(_label("02   废弃设施     排除采样井与实验室的守卫者", 16, PAPER))
	features.add_child(_label("03   回收履历     回收异常物，保存回收员成长", 16, PAPER))
	intro.add_child(_wrapped_label("1–4 人小队协作  ·  装备成长  ·  随时保存", 13, MUTED, 450))
	var session_panel := PanelContainer.new()
	session_panel.custom_minimum_size.x = 378
	session_panel.add_theme_stylebox_override("panel", _box(PANEL, LINE, 25, 25))
	columns.add_child(session_panel)
	var session_box := VBoxContainer.new()
	session_box.add_theme_constant_override("separation", 13)
	session_panel.add_child(session_box)
	session_box.add_child(_label("开始任务", 24, PAPER))
	session_box.add_child(_label("独自进入雾区，或与队友一起出发。", 14, MUTED))
	var solo := _primary(_button("单人行动", 48))
	solo.add_theme_font_size_override("font_size", Art.font_size(24))
	solo.pressed.connect(func() -> void: solo_requested.emit())
	session_box.add_child(solo)
	session_box.add_child(HSeparator.new())
	var endpoint := HBoxContainer.new()
	endpoint.add_theme_constant_override("separation", 10)
	session_box.add_child(endpoint)
	var address_column := VBoxContainer.new()
	address_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	endpoint.add_child(address_column)
	address_column.add_child(_label("房主地址", 13, MUTED))
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "IP 或主机名"
	_address.custom_minimum_size.y = 43
	address_column.add_child(_address)
	var port_column := VBoxContainer.new()
	port_column.custom_minimum_size.x = 112
	endpoint.add_child(port_column)
	port_column.add_child(_label("UDP 端口", 13, MUTED))
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = 24570
	_port.custom_minimum_size.y = 43
	port_column.add_child(_port)
	var host := _button("创建好友房间", 45)
	host.pressed.connect(func() -> void: host_requested.emit(int(_port.value)))
	session_box.add_child(host)
	var join := _button("加入房间", 45)
	join.pressed.connect(_request_join)
	session_box.add_child(join)
	session_box.add_child(_wrapped_label("局域网可直接连接。\n公网直连需配置 UDP 端口映射。", 13, MUTED, 328))
	_status = _wrapped_label("", 14, GOLD, 328)
	_status.custom_minimum_size.y = 52
	session_box.add_child(_status)
	var footer := _label("PROTOTYPE 0.2    /    前哨雾区 · 废弃设施 · 回收履历", 12, MUTED)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -28
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(footer)


func _request_join() -> void:
	var address := _address.text.strip_edges()
	if address.is_empty():
		set_status("请输入房主的 IP 地址或主机名。")
		return
	set_status("正在连接房间……")
	join_requested.emit(address, int(_port.value))


func _build_hud() -> void:
	# Every cluster shares the full rect and shrinks into its own corner.
	_hud = MarginContainer.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_theme_constant_override("margin_left", 20)
	_hud.add_theme_constant_override("margin_right", 20)
	_hud.add_theme_constant_override("margin_top", 16)
	_hud.add_theme_constant_override("margin_bottom", 16)
	_root.add_child(_hud)
	_build_location()
	_build_boss()
	_build_progress()
	_build_body()
	_build_prompt()
	_build_keys()
	_pass_through(_hud)


func _build_location() -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 6)
	_hud.add_child(column)
	_zone = _outlined(_label("雾线前哨", 24, PAPER))
	column.add_child(_zone)
	_session = _outlined(_label("单人行动  ·  1 / 4 人", 12, MUTED))
	column.add_child(_session)
	_brief = PanelContainer.new()
	_brief.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.88), LINE, 14, 10))
	column.add_child(_brief)
	var brief_box := VBoxContainer.new()
	brief_box.add_theme_constant_override("separation", 6)
	_brief.add_child(brief_box)
	brief_box.add_child(_label("任务简报", 12, GOLD))
	_objective = _wrapped_label("穿过雾区，找到废弃设施的入口。", 12, PAPER, 272)
	brief_box.add_child(_objective)
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 5)
	column.add_child(_feed)


func _build_boss() -> void:
	_boss = VBoxContainer.new()
	_boss.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_boss.add_theme_constant_override("separation", 5)
	_hud.add_child(_boss)
	var heading := HBoxContainer.new()
	_boss.add_child(heading)
	_boss_name = _outlined(_label("守卫者", 12, PAPER))
	_boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_boss_name)
	_boss_state = _outlined(_label("", 12, GOLD))
	heading.add_child(_boss_state)
	var meter := Widgets.Meter.new()
	meter.custom_minimum_size = Vector2(366, 18)
	meter.fill = Art.WARN_LIGHT
	meter.back = Color("2a1210")
	_boss_meter = meter
	_boss.add_child(meter)
	_boss.hide()


func _build_progress() -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", 8)
	_hud.add_child(row)
	var progress := PanelContainer.new()
	progress.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.9), LINE, 12, 8))
	row.add_child(progress)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	progress.add_child(stats)
	_level = _label("Lv.1", 12, GOLD)
	stats.add_child(_level)
	var xp := Widgets.Meter.new()
	xp.custom_minimum_size = Vector2(72, 12)
	xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp.fill = TEAL
	xp.back = Color("10181b")
	_xp = xp
	stats.add_child(xp)
	var gap := Control.new()
	gap.custom_minimum_size.x = 4
	stats.add_child(gap)
	stats.add_child(_icon_rect(PixelUI.icon("icon_coin", Color.WHITE, 2)))
	_coins = _label("0", 12, GOLD)
	stats.add_child(_coins)
	var inventory_button := _button("装备箱  I", 36)
	inventory_button.pressed.connect(toggle_inventory)
	row.add_child(inventory_button)
	var menu_button := _button("菜单  Esc", 36)
	menu_button.pressed.connect(func() -> void: set_pause(true))
	row.add_child(menu_button)


func _build_body() -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_SHRINK_END
	column.add_theme_constant_override("separation", 8)
	_hud.add_child(column)
	# What you carry is at risk until banked, so it sits with your health.
	_haul_panel = PanelContainer.new()
	_haul_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_haul_panel.add_theme_stylebox_override("panel", _box(Color(0.14, 0.11, 0.06, 0.92), Art.HAZARD, 12, 8))
	column.add_child(_haul_panel)
	var haul_box := VBoxContainer.new()
	haul_box.add_theme_constant_override("separation", 6)
	_haul_panel.add_child(haul_box)
	haul_box.add_child(_label("随身素材  ·  倒下或离开即丢失", 12, Art.HAZARD_LIGHT))
	_haul_row = HBoxContainer.new()
	_haul_row.add_theme_constant_override("separation", 14)
	haul_box.add_child(_haul_row)
	_haul_panel.hide()
	var vitals := PanelContainer.new()
	vitals.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.9), LINE, 14, 10))
	column.add_child(vitals)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	vitals.add_child(box)
	var health_row := HBoxContainer.new()
	box.add_child(health_row)
	var health_title := _label("生命", 12, MUTED)
	health_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(health_title)
	_health_text = _label("100 / 100", 12, PAPER)
	health_row.add_child(_health_text)
	var health := Widgets.Meter.new()
	health.custom_minimum_size = Vector2(300, 18)
	health.alarm_ratio = 0.3
	_health = health
	box.add_child(health)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	box.add_child(tools)
	_weapon_slot = Widgets.Slot.new()
	_weapon_name = _label("破拆撬棍", 12, PAPER)
	tools.add_child(_tool(_weapon_slot, _weapon_name, _label("Q 切换", 12, MUTED), 78))
	_relic_slot = Widgets.Slot.new()
	_relic_name = _label("未装备", 12, MUTED)
	_relic_note = _label("异常物", 12, MUTED)
	tools.add_child(_tool(_relic_slot, _relic_name, _relic_note, 78))
	_dash_slot = Widgets.Slot.new()
	_dash_slot.set_icon(PixelUI.icon("icon_dash"), LINE)
	tools.add_child(_tool(_dash_slot, _label("闪避", 12, PAPER), _label("空格", 12, MUTED), 26))


func _tool(slot: Control, title: Label, note: Label, text_width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.add_child(slot)
	var text := VBoxContainer.new()
	text.custom_minimum_size.x = text_width
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 5)
	text.add_child(title)
	text.add_child(note)
	row.add_child(text)
	return row


func _build_prompt() -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.size_flags_vertical = Control.SIZE_SHRINK_END
	_hud.add_child(column)
	_interaction_panel = PanelContainer.new()
	_interaction_panel.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.92), GOLD, 12, 7))
	column.add_child(_interaction_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_interaction_panel.add_child(row)
	var keycap := PanelContainer.new()
	keycap.add_theme_stylebox_override("panel", _box(GOLD, INK, 10, 1))
	keycap.add_child(_label("E", 24, INK))
	row.add_child(keycap)
	_interaction = _label("", 24, GOLD)
	row.add_child(_interaction)
	_interaction_panel.hide()
	# Lift the prompt off the screen edge, closer to where the eyes are.
	var lift := Control.new()
	lift.custom_minimum_size.y = 44
	column.add_child(lift)


func _build_keys() -> void:
	_keys = PanelContainer.new()
	_keys.size_flags_horizontal = Control.SIZE_SHRINK_END
	_keys.size_flags_vertical = Control.SIZE_SHRINK_END
	_keys.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.82), LINE, 12, 9))
	_keys.add_child(_key_grid())
	_hud.add_child(_keys)


func _key_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 5)
	for pair: Array in KEY_HELP:
		grid.add_child(_label(pair[0], 12, GOLD))
		grid.add_child(_label(pair[1], 12, MUTED))
	return grid


## HUD clusters never take the mouse, so clicks land on the world behind them.
func _pass_through(node: Node) -> void:
	if node is Control and not node is BaseButton:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_pass_through(child)


func _side_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_WIDTH - 20
	panel.offset_right = -20
	panel.offset_top = 68
	panel.offset_bottom = -16
	panel.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.97), LINE, 20, 18))
	_root.add_child(panel)
	panel.hide()
	return panel


func _build_inventory() -> void:
	_inventory_panel = _side_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_inventory_panel.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title := _label("回收装备箱", 23, PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := _button("关闭  I / Esc", 34)
	close.pressed.connect(toggle_inventory)
	heading.add_child(close)
	box.add_child(_wrapped_label("一把武器，一件异常物。自由搭配你的作业方式。", 14, MUTED, 360))
	box.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_inventory_list = VBoxContainer.new()
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_inventory_list)
	box.add_child(_wrapped_label("打开装备箱不会暂停世界。", 12, MUTED, 360))


func _refresh_inventory() -> void:
	for child in _inventory_list.get_children():
		_inventory_list.remove_child(child)
		child.queue_free()
	if _inventory.is_empty():
		_inventory_list.add_child(_wrapped_label("装备箱暂时为空。离开前哨，回收你的第一件物品。", 15, MUTED, 340))
		return
	for slot: String in ["weapon", "relic"]:
		var heading := "武器 / 攻击方式" if slot == "weapon" else "异常物 / 被动效果"
		_inventory_list.add_child(_label(heading, 13, MUTED))
		var count_in_slot := 0
		for entry in _inventory:
			if not entry is Dictionary:
				continue
			var item: Dictionary = entry
			if str(item.get("slot", "weapon")) != slot:
				continue
			count_in_slot += 1
			_add_inventory_card(item, slot)
		if count_in_slot == 0:
			_inventory_list.add_child(_wrapped_label("进入废弃设施，回收你的第一件异常物。" if slot == "relic" else "尚未获得武器。", 14, MUTED, 300))
	_inventory_list.add_child(_label("素材 / 已入库", 13, MUTED))
	var stock := HFlowContainer.new()
	stock.add_theme_constant_override("h_separation", 18)
	stock.add_theme_constant_override("v_separation", 8)
	for entry in _inventory:
		if entry is Dictionary and str(entry.get("slot", "")) == "material":
			stock.add_child(_count_chip(str(entry.get("id", "")), "%s ×%d" % [str(entry.get("name", "")), int(entry.get("count", 0))], PAPER))
	if stock.get_child_count() == 0:
		stock.free()
		_inventory_list.add_child(_wrapped_label("尚无入库素材。在雾区采集，活着带回前哨。", 14, MUTED, 300))
	else:
		_inventory_list.add_child(stock)


func _build_crafting() -> void:
	_crafting_panel = _side_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_crafting_panel.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title := _label("维修间工作台", 23, PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := _button("关闭  E / Esc", 34)
	close.pressed.connect(close_crafting)
	heading.add_child(close)
	box.add_child(_wrapped_label("按蓝图用入库素材和报酬制作装备。蓝图由各设施的守卫者掉落。", 14, MUTED, 360))
	box.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_crafting_list = VBoxContainer.new()
	_crafting_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crafting_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_crafting_list)
	box.add_child(_wrapped_label("随身素材要先带回前哨入库，才能用于制作。", 12, MUTED, 360))


func _refresh_crafting() -> void:
	for child in _crafting_list.get_children():
		_crafting_list.remove_child(child)
		child.queue_free()
	for entry in _recipes:
		if not entry is Dictionary:
			continue
		var recipe: Dictionary = entry
		var recipe_id := str(recipe.get("id", ""))
		var unlocked := bool(recipe.get("unlocked", false))
		var owned := bool(recipe.get("owned", false))
		var box := _card(recipe_id, TEAL if owned else LINE, not unlocked, _crafting_list)
		box.add_child(_wrapped_label(str(recipe.get("name", "")), 17, GOLD if unlocked else MUTED, 250))
		if not unlocked:
			box.add_child(_wrapped_label("未获得蓝图 · 排除「%s」的守卫者后回收。" % str(recipe.get("source", "")), 13, MUTED, 250))
			continue
		box.add_child(_wrapped_label(str(recipe.get("description", "")), 13, MUTED, 250))
		# Each cost shows have/need in green or red, so a shortfall names itself.
		var costs := HFlowContainer.new()
		costs.add_theme_constant_override("h_separation", 14)
		costs.add_theme_constant_override("v_separation", 6)
		box.add_child(costs)
		var missing: PackedStringArray = []
		for cost: Dictionary in recipe.get("materials", []):
			var have := int(cost.have)
			var need := int(cost.need)
			costs.add_child(_count_chip(str(cost.get("id", "")), "%s %d/%d" % [str(cost.name), have, need], GOOD if have >= need or owned else BAD))
			if have < need:
				missing.append("%s ×%d" % [str(cost.name), need - have])
		var price := int(recipe.get("coins", 0))
		costs.add_child(_chip(PixelUI.icon("icon_coin", Color.WHITE, 2), "报酬 %d" % price, GOOD if _coins_value >= price or owned else BAD))
		if _coins_value < price:
			missing.append("报酬 %d" % (price - _coins_value))
		var action := "制作"
		if owned:
			action = "已拥有"
		elif not missing.is_empty():
			action = "还缺 " + "、".join(missing)
		var craft := _button(action, 34)
		craft.disabled = owned or not bool(recipe.get("affordable", false))
		craft.clip_text = true
		craft.pressed.connect(_emit_craft.bind(recipe_id))
		box.add_child(craft)


func _emit_craft(recipe_id: String) -> void:
	craft_requested.emit(recipe_id)


func _add_inventory_card(item: Dictionary, slot: String) -> void:
	var equipped := bool(item.get("equipped", false))
	var box := _card(str(item.get("id", "")), TEAL if equipped else LINE, false, _inventory_list)
	var name_text := str(item.get("name", item.get("id", "未知物品")))
	box.add_child(_wrapped_label(name_text, 17, GOLD, 250))
	box.add_child(_wrapped_label(str(item.get("description", "")), 13, MUTED, 250))
	var action_text := "装备武器" if slot == "weapon" else "装备异常物"
	if equipped:
		action_text = "已装备" if slot == "weapon" else "卸下异常物"
	var equip := _button(action_text, 34)
	equip.disabled = equipped and slot == "weapon"
	equip.pressed.connect(_emit_equip.bind("" if equipped and slot == "relic" else str(item.get("id", ""))))
	box.add_child(equip)


func _emit_equip(item_id: String) -> void:
	equip_requested.emit(item_id)


## A bordered card with the item's icon on the left; returns the text column.
func _card(item_id: String, border: Color, dimmed: bool, parent: Control) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(PANEL_LIGHT, border, 12, 12))
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var slot := Widgets.Slot.new()
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.set_icon(_item_icon(item_id), border, dimmed)
	row.add_child(slot)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	row.add_child(box)
	return box


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL, LINE, 26, 22))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 380
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_label("行动菜单", 24, PAPER))
	_pause_zone = _label("", 12, MUTED)
	box.add_child(_pause_zone)
	box.add_child(HSeparator.new())
	_pause_actions = VBoxContainer.new()
	_pause_actions.add_theme_constant_override("separation", 12)
	box.add_child(_pause_actions)
	_pause_actions.add_child(_label("任务简报", 12, GOLD))
	_pause_objective = _wrapped_label("", 12, PAPER, 380)
	_pause_actions.add_child(_pause_objective)
	_pause_actions.add_child(_label("操作", 12, GOLD))
	_pause_actions.add_child(_key_grid())
	_pause_actions.add_child(HSeparator.new())
	var resume := _primary(_button("继续行动  Esc", 42))
	resume.pressed.connect(func() -> void: set_pause(false))
	_pause_actions.add_child(resume)
	var save := _button("保存档案", 40)
	save.pressed.connect(func() -> void:
		set_pause(false)
		save_requested.emit())
	_pause_actions.add_child(save)
	var leave := _button("返回主菜单", 40)
	leave.pressed.connect(func() -> void: _ask_leave(true))
	_pause_actions.add_child(leave)
	_pause_actions.add_child(_label("菜单打开时世界不会暂停。", 12, MUTED))
	# Leaving is never one click: it can end a room and drops whatever is carried.
	_pause_confirm = VBoxContainer.new()
	_pause_confirm.add_theme_constant_override("separation", 12)
	box.add_child(_pause_confirm)
	_pause_confirm.add_child(_label("确认返回主菜单？", 24, GOLD))
	_pause_warning = _wrapped_label("", 12, PAPER, 380)
	_pause_confirm.add_child(_pause_warning)
	var confirm := _button("确认离开", 42)
	confirm.add_theme_stylebox_override("normal", _box(Art.WARN_DARK, INK, 14, 10))
	confirm.add_theme_stylebox_override("hover", _box(Art.WARN, GOLD, 14, 10))
	confirm.pressed.connect(func() -> void: leave_requested.emit())
	_pause_confirm.add_child(confirm)
	var cancel := _button("取消  Esc", 40)
	cancel.pressed.connect(func() -> void: _ask_leave(false))
	_pause_confirm.add_child(cancel)
	_pause_confirm.hide()
	_pause.hide()


func _ask_leave(asking: bool) -> void:
	_pause_actions.visible = not asking
	_pause_confirm.visible = asking
	if not asking:
		return
	var lines: PackedStringArray = []
	if not _haul_text.is_empty():
		lines.append("随身素材还没入库，离开后会全部丢失：%s。" % _haul_text)
	if _hosting_others:
		lines.append("你是房主，离开会结束整个房间，队友将回到主菜单。")
	lines.append("回收员档案会在离开前自动保存。")
	_pause_warning.text = "\n".join(lines)
	_pause_warning.add_theme_color_override("font_color", BAD if lines.size() > 1 else PAPER)


func _clear_feed() -> void:
	for entry: Dictionary in _feed_entries:
		entry.node.queue_free()
	_feed_entries.clear()


## The reticle shows only while the mouse aims; menus and panels keep the arrow.
func _sync_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_default_cursor_shape(Input.CURSOR_ARROW if blocks_gameplay_input() else Input.CURSOR_CROSS)


func _item_color(item_id: String) -> Color:
	var item: Resource = Catalog.get_item(item_id)
	return item.color if item != null else Color.WHITE


func _item_icon(item_id: String, scale: int = PixelUI.UNIT) -> Texture2D:
	return PixelUI.item_icon(item_id, _item_color(item_id), scale)


func _icon_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Small icon with a caption, used for material counts and costs.
func _chip(texture: Texture2D, text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(_icon_rect(texture))
	row.add_child(_label(text, 12, color))
	return row


func _count_chip(item_id: String, text: String, color: Color) -> HBoxContainer:
	return _chip(_item_icon(item_id, 2), text, color)


func _label(text: String, size: int = 16, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", Art.font_size(size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrapped_label(text: String, size: int, color: Color, width: float) -> Label:
	var label := _label(text, size, color)
	label.custom_minimum_size.x = width
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Hard drop shadow for text that sits straight on the world with no panel behind it.
func _outlined(label: Label) -> Label:
	label.add_theme_color_override("font_shadow_color", INK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _button(text: String, height: float = 42) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	return button


## The one gold button on a screen: the action most players want.
func _primary(button: Button) -> Button:
	button.add_theme_stylebox_override("normal", _box(GOLD, INK, 14, 10))
	button.add_theme_stylebox_override("hover", _box(Color("f6da85"), INK, 14, 10))
	button.add_theme_stylebox_override("pressed", PixelUI.box(Color("d9a63a"), INK, 14, 10, true))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	return button


func _box(color: Color, border: Color, horizontal_padding: int = 14, vertical_padding: int = 10) -> StyleBoxTexture:
	return PixelUI.box(color, border, horizontal_padding, vertical_padding)
