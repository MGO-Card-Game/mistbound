class_name GameUI
extends CanvasLayer
## Presentation-only UI. The session controller owns gameplay and persistence.

signal solo_requested()
signal host_requested(port: int)
signal join_requested(address: String, port: int)
signal leave_requested()
signal equip_requested(item_id: String)
signal save_requested()

const Art = preload("res://scripts/art/pixel_art.gd")
const PixelUI = preload("res://scripts/ui/pixel_ui.gd")
const Backdrop = preload("res://scripts/ui/menu_backdrop.gd")

const INK := Color("0a0f11")
const PANEL := Color("141d21")
const PANEL_LIGHT := Color("1f2c31")
const LINE := Color("30434a")
const PAPER := Color("e9efe8")
const MUTED := Color("9aa8a2")
const GOLD := Color("f0c95a")
const TEAL := Color("9cc7bb")

var _root: Control
var _menu: Control
var _hud: Control
var _inventory_panel: PanelContainer
var _inventory_list: VBoxContainer
var _status: Label
var _address: LineEdit
var _port: SpinBox
var _zone: Label
var _session: Label
var _health: ProgressBar
var _health_text: Label
var _stats: Label
var _equipment: Label
var _relic: Label
var _objective: Label
var _interaction: Label
var _toast: Label
var _toast_time := 0.0
var _inventory_signature := ""
var _inventory: Array = []


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
	show_menu()


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time = maxf(0.0, _toast_time - delta)
		_toast.modulate.a = minf(_toast_time, 1.0)
		_toast.visible = _toast_time > 0.0 and not is_menu_open()


func show_menu(message: String = "") -> void:
	_menu.show()
	_hud.hide()
	_inventory_panel.hide()
	_toast.hide()
	set_status(message)


func show_game() -> void:
	_menu.hide()
	_hud.show()
	_inventory_panel.hide()
	_toast.offset_right = -22
	_root.get_viewport().gui_release_focus()


func set_status(message: String) -> void:
	_status.text = message


func is_menu_open() -> bool:
	return _menu.visible


func blocks_gameplay_input() -> bool:
	return _menu.visible or _inventory_panel.visible


func toggle_inventory() -> void:
	if is_menu_open():
		return
	_inventory_panel.visible = not _inventory_panel.visible
	_toast.offset_right = -450 if _inventory_panel.visible else -22
	if not _inventory_panel.visible:
		_root.get_viewport().gui_release_focus()


func notify(message: String) -> void:
	_toast.text = message
	_toast_time = 4.0
	_toast.modulate.a = 1.0
	_toast.visible = not is_menu_open()


func update_hud(state: Dictionary) -> void:
	_zone.text = str(state.get("zone_title", "雾线前哨"))
	_session.text = "%s  ·  %d / 4 人" % [str(state.get("mode", "单人行动")), int(state.get("player_count", 1))]
	var hp := float(state.get("hp", 100.0))
	var maximum := maxf(1.0, float(state.get("max_hp", 100.0)))
	_health.max_value = maximum
	_health.value = hp
	_health_text.text = "生命  %d / %d" % [int(hp), int(maximum)]
	_stats.text = "Lv.%d    经验 %d    报酬 %d" % [int(state.get("level", 1)), int(state.get("xp", 0)), int(state.get("coins", 0))]
	_equipment.text = "武器  ·  " + str(state.get("weapon_name", state.get("equipped_name", "破拆撬棍")))
	var relic_name := str(state.get("relic_name", "未装备"))
	if relic_name.is_empty():
		relic_name = "未装备"
	var charge := int(state.get("relic_charge", 0))
	_relic.text = "异常物  ·  " + relic_name + ("  /  蓄能 %d" % charge if charge > 0 else "")
	_relic.add_theme_color_override("font_color", TEAL if relic_name != "未装备" else MUTED)
	_objective.text = str(state.get("objective", "穿过雾区，找到废弃设施的入口。"))
	var interaction_text := str(state.get("interaction", ""))
	_interaction.text = "[ E ]  " + interaction_text
	_interaction.visible = not interaction_text.is_empty()
	var items: Array = state.get("inventory", [])
	var signature := JSON.stringify(items)
	if signature != _inventory_signature:
		_inventory_signature = signature
		_inventory = items.duplicate(true)
		_refresh_inventory()


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
	theme.set_stylebox("background", "ProgressBar", PixelUI.box(Color("1b1012"), INK, 0, 0, true))
	theme.set_stylebox("fill", "ProgressBar", PixelUI.bar(Color("7fc7a8")))
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
	var solo := _button("单人行动", 48)
	solo.add_theme_stylebox_override("normal", _box(GOLD, INK, 14, 10))
	solo.add_theme_stylebox_override("hover", _box(Color("f6da85"), INK, 14, 10))
	solo.add_theme_font_size_override("font_size", Art.font_size(24))
	solo.add_theme_color_override("font_color", INK)
	solo.add_theme_color_override("font_hover_color", INK)
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
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 16
	top.offset_bottom = 90
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.94), LINE, 18, 12))
	_hud.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var location := VBoxContainer.new()
	location.custom_minimum_size.x = 220
	location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(location)
	_zone = _label("雾线前哨", 21, PAPER)
	location.add_child(_zone)
	_session = _label("单人行动 · 1 / 4 人", 12, MUTED)
	location.add_child(_session)
	var vitals := VBoxContainer.new()
	vitals.custom_minimum_size.x = 210
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vitals)
	_health_text = _label("生命 100 / 100", 13, MUTED)
	vitals.add_child(_health_text)
	_health = ProgressBar.new()
	_health.custom_minimum_size = Vector2(210, 11)
	_health.show_percentage = false
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(_health)
	var character := VBoxContainer.new()
	character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character.add_theme_constant_override("separation", 1)
	row.add_child(character)
	_stats = _label("Lv.1    经验 0    报酬 0", 14, GOLD)
	character.add_child(_stats)
	_equipment = _label("武器 · 破拆撬棍", 12, MUTED)
	character.add_child(_equipment)
	_relic = _label("异常物 · 未装备", 12, MUTED)
	character.add_child(_relic)
	var inventory_button := _button("装备箱  I", 40)
	inventory_button.pressed.connect(toggle_inventory)
	row.add_child(inventory_button)
	var save := _button("保存", 40)
	save.pressed.connect(func() -> void: save_requested.emit())
	row.add_child(save)
	var leave := _button("离开", 40)
	leave.pressed.connect(func() -> void: leave_requested.emit())
	row.add_child(leave)
	var objective_panel := PanelContainer.new()
	objective_panel.position = Vector2(20, 105)
	objective_panel.custom_minimum_size.x = 315
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.88), LINE, 16, 12))
	_hud.add_child(objective_panel)
	var objective_box := VBoxContainer.new()
	objective_box.add_theme_constant_override("separation", 7)
	objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_child(objective_box)
	objective_box.add_child(_label("任务简报", 13, GOLD))
	_objective = _wrapped_label("穿过雾区，找到废弃设施的入口。", 14, PAPER, 285)
	objective_box.add_child(_objective)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -53
	bottom.offset_bottom = -16
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.9), LINE, 10, 8))
	_hud.add_child(bottom)
	var controls := _label("WASD  移动     左键  攻击     空格  闪避     Q  切换武器     E  交互     I / Esc  装备箱", 13, MUTED)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(controls)
	_interaction = _label("", 24, GOLD)
	_interaction.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_interaction.offset_top = -105
	_interaction.offset_bottom = -68
	_interaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction.add_theme_color_override("font_shadow_color", INK)
	_interaction.add_theme_constant_override("shadow_offset_x", 2)
	_interaction.add_theme_constant_override("shadow_offset_y", 2)
	_hud.add_child(_interaction)
	_toast = _label("", 24, PAPER)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 110
	_toast.offset_left = 355
	_toast.offset_right = -22
	_toast.offset_bottom = 165
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_shadow_color", INK)
	_toast.add_theme_constant_override("shadow_offset_x", 2)
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	_hud.add_child(_toast)


func _build_inventory() -> void:
	_inventory_panel = PanelContainer.new()
	_inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_inventory_panel.offset_left = -430
	_inventory_panel.offset_right = -20
	_inventory_panel.offset_top = 104
	_inventory_panel.offset_bottom = -66
	_inventory_panel.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.97), LINE, 20, 18))
	_root.add_child(_inventory_panel)
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
	box.add_child(_wrapped_label("联机时打开装备箱不会暂停世界。", 12, MUTED, 360))
	_inventory_panel.hide()


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


func _add_inventory_card(item: Dictionary, slot: String) -> void:
	var equipped := bool(item.get("equipped", false))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(PANEL_LIGHT, TEAL if equipped else LINE, 14, 12))
	_inventory_list.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)
	var name_text := str(item.get("name", item.get("id", "未知物品")))
	var count := int(item.get("count", 1))
	box.add_child(_wrapped_label("%s  ×%d" % [name_text, count], 17, GOLD, 300))
	box.add_child(_wrapped_label(str(item.get("description", "")), 13, MUTED, 300))
	var action_text := "装备武器" if slot == "weapon" else "装备异常物"
	if equipped:
		action_text = "已装备" if slot == "weapon" else "卸下异常物"
	var equip := _button(action_text, 34)
	equip.disabled = equipped and slot == "weapon"
	equip.pressed.connect(_emit_equip.bind("" if equipped and slot == "relic" else str(item.get("id", ""))))
	box.add_child(equip)


func _emit_equip(item_id: String) -> void:
	equip_requested.emit(item_id)


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


func _button(text: String, height: float = 42) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	return button


func _box(color: Color, border: Color, horizontal_padding: int = 14, vertical_padding: int = 10) -> StyleBoxTexture:
	return PixelUI.box(color, border, horizontal_padding, vertical_padding)
