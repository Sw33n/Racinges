extends Control

const CarCatalog = preload("res://scripts/data/car_catalog.gd")
const UIPalette = preload("res://scripts/ui/ui_palette.gd")

signal screen_change_requested(screen_name: String, context: Dictionary)

const _PLAYER_LABELS := ["P1", "P2"]
const _PLAYER_ACCENTS := [
	Color(0.992157, 0.427451, 0.223529, 1.0),
	Color(0.215686, 0.870588, 0.909804, 1.0),
]

var _cars: Array[Dictionary] = []
var _player_states: Array[Dictionary] = []
var _player_panels: Array[Dictionary] = []
var _roster_rows: Array[Dictionary] = []

@onready var _header_row: BoxContainer = $RootLayout/HeaderRow
@onready var _title: Label = $RootLayout/HeaderRow/Title
@onready var _mode_badge: PanelContainer = $RootLayout/HeaderRow/ModeBadge
@onready var _mode_value: Label = $RootLayout/HeaderRow/ModeBadge/ModePadding/ModeValue
@onready var _menu_button: Button = $RootLayout/HeaderRow/MenuButton
@onready var _summary_label: Label = $RootLayout/SummaryLabel
@onready var _content_row: BoxContainer = $RootLayout/ContentRow
@onready var _player_one_card: PanelContainer = $RootLayout/ContentRow/PlayerOneCard
@onready var _roster_card: PanelContainer = $RootLayout/ContentRow/RosterCard
@onready var _roster_title: Label = $RootLayout/ContentRow/RosterCard/RosterPadding/RosterColumn/RosterTitle
@onready var _roster_hint: Label = $RootLayout/ContentRow/RosterCard/RosterPadding/RosterColumn/RosterHint
@onready var _roster_list: VBoxContainer = $RootLayout/ContentRow/RosterCard/RosterPadding/RosterColumn/RosterList
@onready var _player_two_card: PanelContainer = $RootLayout/ContentRow/PlayerTwoCard
@onready var _footer_row: BoxContainer = $RootLayout/FooterRow
@onready var _start_button: Button = $RootLayout/FooterRow/StartButton
@onready var _footer_hint: Label = $RootLayout/FooterRow/FooterHint


func _ready() -> void:
	_apply_styles()
	_connect_actions()
	_prepare_state()
	_build_player_panels()
	_build_roster_rows()
	_render_screen()
	resized.connect(_update_layout)
	_update_layout()


func _apply_styles() -> void:
	UIPalette.apply_panel_style(_mode_badge, UIPalette.SURFACE_CARD, UIPalette.ACCENT_CYAN, 18, 2)
	UIPalette.apply_panel_style(_player_one_card, UIPalette.SURFACE_PANEL, UIPalette.ACCENT_ORANGE, 28, 2)
	UIPalette.apply_panel_style(_roster_card, UIPalette.SURFACE_PANEL, UIPalette.ACCENT_GOLD, 28, 2)
	UIPalette.apply_panel_style(_player_two_card, UIPalette.SURFACE_PANEL, UIPalette.ACCENT_CYAN, 28, 2)

	_title.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_mode_value.add_theme_color_override("font_color", UIPalette.ACCENT_CYAN)
	_summary_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_roster_hint.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_footer_hint.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)

	_mode_value.text = "Split-screen"
	_summary_label.text = "Оба игрока могут выбрать любую машину из существующих в игре. Цветные метки на списке показывают текущие пики P1 и P2."
	_roster_title.visible = false
	_roster_hint.text = "W / S меняют выбор P1, стрелки вверх / вниз меняют выбор P2."
	_footer_hint.text = "Сначала оба игрока подтверждают готовность, после чего можно запускать заезд. Esc или кнопка сверху возвращают в главное меню."

	UIPalette.apply_button_style(
		_menu_button,
		Color(0.164706, 0.2, 0.270588, 0.95),
		Color(0.235294, 0.286275, 0.372549, 1.0),
		Color(0.133333, 0.160784, 0.219608, 1.0)
	)
	UIPalette.apply_button_style(
		_start_button,
		Color(0.223529, 0.486275, 0.286275, 0.95),
		UIPalette.ACCENT_GREEN,
		Color(0.184314, 0.615686, 0.286275, 1.0)
	)


func _connect_actions() -> void:
	_menu_button.pressed.connect(_on_menu_pressed)
	_start_button.pressed.connect(_on_start_pressed)


func _prepare_state() -> void:
	_cars = CarCatalog.get_cars()
	var default_index := _find_car_index(String(CarCatalog.get_default_player_car().get("id", "urban_racer")), 0)
	var second_default := _find_secondary_default(default_index)

	_player_states = [
		{
			"selection_index": default_index,
			"ready": false,
		},
		{
			"selection_index": second_default,
			"ready": false,
		},
	]


func _find_car_index(car_id: String, fallback: int) -> int:
	for index in range(_cars.size()):
		if String(_cars[index].get("id", "")) == car_id:
			return index
	return fallback


func _find_secondary_default(primary_index: int) -> int:
	if _cars.size() <= 1:
		return primary_index

	var preferred_ids := ["dodge_challenger_srt", "toyota_ae86_trueno", "retro_sprint_80", "urban_racer", "bmw_m3_gtr"]
	for car_id in preferred_ids:
		var candidate := _find_car_index(car_id, primary_index)
		if candidate != primary_index:
			return candidate

	return (primary_index + 1) % _cars.size()


func _build_player_panels() -> void:
	_player_panels.clear()
	_player_panels.append(_build_player_panel(_player_one_card, 0))
	_player_panels.append(_build_player_panel(_player_two_card, 1))


func _build_player_panel(host: PanelContainer, player_index: int) -> Dictionary:
	for child in host.get_children():
		child.queue_free()

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 20)
	padding.add_theme_constant_override("margin_top", 20)
	padding.add_theme_constant_override("margin_right", 20)
	padding.add_theme_constant_override("margin_bottom", 20)
	host.add_child(padding)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	padding.add_child(column)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	column.add_child(top_row)

	var player_badge := PanelContainer.new()
	top_row.add_child(player_badge)

	var badge_padding := MarginContainer.new()
	badge_padding.add_theme_constant_override("margin_left", 14)
	badge_padding.add_theme_constant_override("margin_top", 8)
	badge_padding.add_theme_constant_override("margin_right", 14)
	badge_padding.add_theme_constant_override("margin_bottom", 8)
	player_badge.add_child(badge_padding)

	var badge_value := Label.new()
	badge_value.text = _PLAYER_LABELS[player_index]
	badge_value.add_theme_font_size_override("font_size", 18)
	badge_padding.add_child(badge_value)

	var ready_badge := PanelContainer.new()
	top_row.add_child(ready_badge)

	var ready_padding := MarginContainer.new()
	ready_padding.add_theme_constant_override("margin_left", 14)
	ready_padding.add_theme_constant_override("margin_top", 8)
	ready_padding.add_theme_constant_override("margin_right", 14)
	ready_padding.add_theme_constant_override("margin_bottom", 8)
	ready_badge.add_child(ready_padding)

	var ready_value := Label.new()
	ready_value.add_theme_font_size_override("font_size", 16)
	ready_padding.add_child(ready_value)

	var controls_label := Label.new()
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.add_theme_font_size_override("font_size", 16)
	controls_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	controls_label.text = "W / S — выбор, R — готовность" if player_index == 0 else "↑ / ↓ — выбор, M — готовность"
	column.add_child(controls_label)

	var preview_area := CenterContainer.new()
	preview_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_area.custom_minimum_size = Vector2(0, 180)
	column.add_child(preview_area)

	var preview_car := Control.new()
	preview_car.custom_minimum_size = Vector2(300, 150)
	preview_area.add_child(preview_car)

	var preview_backdrop := ColorRect.new()
	preview_backdrop.offset_left = 26.0
	preview_backdrop.offset_top = 26.0
	preview_backdrop.offset_right = 274.0
	preview_backdrop.offset_bottom = 134.0
	preview_car.add_child(preview_backdrop)

	var shadow := ColorRect.new()
	shadow.offset_left = 76.0
	shadow.offset_top = 120.0
	shadow.offset_right = 252.0
	shadow.offset_bottom = 134.0
	shadow.color = Color(0, 0, 0, 0.24)
	preview_car.add_child(shadow)

	var accent_stripe := ColorRect.new()
	accent_stripe.offset_left = 78.0
	accent_stripe.offset_top = 88.0
	accent_stripe.offset_right = 246.0
	accent_stripe.offset_bottom = 98.0
	preview_car.add_child(accent_stripe)

	var body := ColorRect.new()
	body.offset_left = 70.0
	body.offset_top = 72.0
	body.offset_right = 252.0
	body.offset_bottom = 118.0
	preview_car.add_child(body)

	var cabin := ColorRect.new()
	cabin.offset_left = 130.0
	cabin.offset_top = 52.0
	cabin.offset_right = 212.0
	cabin.offset_bottom = 86.0
	preview_car.add_child(cabin)

	var front_wheel := ColorRect.new()
	front_wheel.offset_left = 88.0
	front_wheel.offset_top = 112.0
	front_wheel.offset_right = 126.0
	front_wheel.offset_bottom = 144.0
	front_wheel.color = Color(0.0862745, 0.0980392, 0.12549, 1.0)
	preview_car.add_child(front_wheel)

	var rear_wheel := ColorRect.new()
	rear_wheel.offset_left = 196.0
	rear_wheel.offset_top = 112.0
	rear_wheel.offset_right = 234.0
	rear_wheel.offset_bottom = 144.0
	rear_wheel.color = Color(0.0862745, 0.0980392, 0.12549, 1.0)
	preview_car.add_child(rear_wheel)

	var selected_name := Label.new()
	selected_name.add_theme_font_size_override("font_size", 30)
	selected_name.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	column.add_child(selected_name)

	var selected_role := Label.new()
	selected_role.add_theme_font_size_override("font_size", 16)
	selected_role.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	column.add_child(selected_role)

	var selected_description := Label.new()
	selected_description.add_theme_font_size_override("font_size", 17)
	selected_description.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	selected_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(selected_description)

	var ready_button := Button.new()
	ready_button.text = "Подтвердить"
	ready_button.pressed.connect(_on_player_ready_button_pressed.bind(player_index))
	column.add_child(ready_button)

	badge_value.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_apply_player_badge_style(player_badge, player_index)
	UIPalette.apply_button_style(
		ready_button,
		Color(0.164706, 0.2, 0.270588, 0.95),
		_PLAYER_ACCENTS[player_index].darkened(0.16),
		_PLAYER_ACCENTS[player_index].darkened(0.06)
	)

	return {
		"player_badge": player_badge,
		"ready_badge": ready_badge,
		"ready_value": ready_value,
		"selected_name": selected_name,
		"selected_role": selected_role,
		"selected_description": selected_description,
		"preview_backdrop": preview_backdrop,
		"accent_stripe": accent_stripe,
		"body": body,
		"cabin": cabin,
		"ready_button": ready_button,
	}


func _apply_player_badge_style(panel: PanelContainer, player_index: int) -> void:
	UIPalette.apply_panel_style(panel, _PLAYER_ACCENTS[player_index], _PLAYER_ACCENTS[player_index].lightened(0.1), 18, 2)


func _build_roster_rows() -> void:
	for child in _roster_list.get_children():
		child.queue_free()

	_roster_rows.clear()

	for index in range(_cars.size()):
		var entry := _cars[index]
		var row_root := Control.new()
		row_root.custom_minimum_size = Vector2(0, 86)
		row_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_roster_list.add_child(row_root)

		var row_panel := PanelContainer.new()
		row_panel.layout_mode = 1
		row_panel.anchors_preset = Control.PRESET_FULL_RECT
		row_panel.anchor_right = 1.0
		row_panel.anchor_bottom = 1.0
		row_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		row_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		row_root.add_child(row_panel)

		var row_padding := MarginContainer.new()
		row_padding.add_theme_constant_override("margin_left", 72)
		row_padding.add_theme_constant_override("margin_top", 14)
		row_padding.add_theme_constant_override("margin_right", 72)
		row_padding.add_theme_constant_override("margin_bottom", 14)
		row_panel.add_child(row_padding)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row_padding.add_child(row)

		var labels := VBoxContainer.new()
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.add_theme_constant_override("separation", 4)
		row.add_child(labels)

		var name_label := Label.new()
		name_label.text = String(entry.get("name", "Unknown"))
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
		labels.add_child(name_label)

		var subtitle_label := Label.new()
		subtitle_label.text = "Закрыта в гараже, но доступна в коопе" if bool(entry.get("locked", false)) else String(entry.get("role", ""))
		subtitle_label.add_theme_font_size_override("font_size", 14)
		subtitle_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		labels.add_child(subtitle_label)

		var marker_layer := Control.new()
		marker_layer.layout_mode = 1
		marker_layer.anchors_preset = Control.PRESET_FULL_RECT
		marker_layer.anchor_right = 1.0
		marker_layer.anchor_bottom = 1.0
		marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_panel.add_child(marker_layer)

		var left_marker_slot := Control.new()
		left_marker_slot.layout_mode = 1
		left_marker_slot.anchors_preset = Control.PRESET_FULL_RECT
		left_marker_slot.anchor_right = 1.0
		left_marker_slot.anchor_bottom = 1.0
		left_marker_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker_layer.add_child(left_marker_slot)

		var right_marker_slot := Control.new()
		right_marker_slot.layout_mode = 1
		right_marker_slot.anchors_preset = Control.PRESET_FULL_RECT
		right_marker_slot.anchor_right = 1.0
		right_marker_slot.anchor_bottom = 1.0
		right_marker_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker_layer.add_child(right_marker_slot)

		_roster_rows.append(
			{
				"panel": row_panel,
				"left_marker_slot": left_marker_slot,
				"right_marker_slot": right_marker_slot,
			}
		)


func _render_screen() -> void:
	for player_index in range(_player_panels.size()):
		_render_player_panel(player_index)
	_refresh_roster_rows()
	_refresh_start_state()


func _render_player_panel(player_index: int) -> void:
	if _cars.is_empty():
		return

	var panel_refs := _player_panels[player_index]
	var player_state := _player_states[player_index]
	var car := _cars[int(player_state["selection_index"])]
	var accent: Color = car.get("accent_color", _PLAYER_ACCENTS[player_index])
	var ready := bool(player_state.get("ready", false))

	panel_refs["selected_name"].text = String(car.get("name", "Unknown"))
	panel_refs["selected_role"].text = "Статус: %s" % ("готов" if ready else "не подтверждён")
	panel_refs["selected_description"].text = String(car.get("description", ""))
	panel_refs["preview_backdrop"].color = Color(car.get("body_color", Color(0.180392, 0.219608, 0.301961, 1.0))).darkened(0.56)
	panel_refs["accent_stripe"].color = accent
	panel_refs["body"].color = car.get("body_color", Color(1, 1, 1, 1))
	panel_refs["cabin"].color = car.get("cabin_color", Color(1, 1, 1, 1))
	panel_refs["ready_value"].text = "Готов" if ready else "Не готов"
	panel_refs["ready_value"].add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY if ready else UIPalette.TEXT_MUTED)
	panel_refs["ready_button"].text = "Снять готовность" if ready else "Подтвердить %s" % _PLAYER_LABELS[player_index]

	var badge_fill := accent.darkened(0.14) if ready else UIPalette.SURFACE_CARD
	var badge_border := accent if ready else Color(1, 1, 1, 0.08)
	UIPalette.apply_panel_style(panel_refs["ready_badge"], badge_fill, badge_border, 18, 2)


func _refresh_roster_rows() -> void:
	for index in range(_roster_rows.size()):
		var row_refs := _roster_rows[index]
		var left_slot: Control = row_refs["left_marker_slot"]
		var right_slot: Control = row_refs["right_marker_slot"]

		for slot in [left_slot, right_slot]:
			for badge in slot.get_children():
				slot.remove_child(badge)
				badge.queue_free()

		var selected_by_p1 := int(_player_states[0]["selection_index"]) == index
		var selected_by_p2 := int(_player_states[1]["selection_index"]) == index
		var border_color := Color(1, 1, 1, 0.08)
		var fill_color := UIPalette.SURFACE_CARD

		if selected_by_p1 or selected_by_p2:
			fill_color = UIPalette.SURFACE_CARD_ALT

		if selected_by_p1 and selected_by_p2:
			border_color = UIPalette.ACCENT_GOLD
		elif selected_by_p1:
			border_color = _PLAYER_ACCENTS[0]
		elif selected_by_p2:
			border_color = _PLAYER_ACCENTS[1]

		UIPalette.apply_panel_style(row_refs["panel"], fill_color, border_color, 22, 2)

		if selected_by_p1:
			left_slot.add_child(_create_player_marker(0, false))
		if selected_by_p2:
			right_slot.add_child(_create_player_marker(1, true))


func _create_player_marker(player_index: int, attach_right: bool) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.layout_mode = 1
	if attach_right:
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.offset_left = -58.0
		badge.offset_top = 8.0
		badge.offset_right = -8.0
		badge.offset_bottom = 78.0
	else:
		badge.offset_left = 8.0
		badge.offset_top = 8.0
		badge.offset_right = 58.0
		badge.offset_bottom = 78.0
	UIPalette.apply_panel_style(badge, _PLAYER_ACCENTS[player_index], _PLAYER_ACCENTS[player_index].lightened(0.08), 16, 2)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 10)
	padding.add_theme_constant_override("margin_top", 8)
	padding.add_theme_constant_override("margin_right", 10)
	padding.add_theme_constant_override("margin_bottom", 8)
	badge.add_child(padding)

	var value := Label.new()
	value.text = _PLAYER_LABELS[player_index]
	value.add_theme_font_size_override("font_size", 15)
	value.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	padding.add_child(value)

	return badge


func _refresh_start_state() -> void:
	var can_start := _can_start_race()
	_start_button.disabled = not can_start
	_start_button.text = "Старт split-screen" if can_start else "Ждём готовность P1 и P2"


func _can_start_race() -> bool:
	return not _cars.is_empty() and bool(_player_states[0]["ready"]) and bool(_player_states[1]["ready"])


func _move_selection(player_index: int, direction: int) -> void:
	if _cars.is_empty():
		return

	var current_index := int(_player_states[player_index]["selection_index"])
	var new_index := wrapi(current_index + direction, 0, _cars.size())
	if new_index == current_index:
		return

	_player_states[player_index]["selection_index"] = new_index
	_player_states[player_index]["ready"] = false
	_render_screen()


func _toggle_ready(player_index: int) -> void:
	if _cars.is_empty():
		return

	_player_states[player_index]["ready"] = not bool(_player_states[player_index]["ready"])
	_render_screen()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.echo:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_menu_pressed()
		return

	if event.is_action_pressed("ui_accept") and _can_start_race():
		get_viewport().set_input_as_handled()
		_on_start_pressed()
		return

	if event.is_action_pressed("player_accelerate"):
		get_viewport().set_input_as_handled()
		_move_selection(0, -1)
		return

	if event.is_action_pressed("player_brake"):
		get_viewport().set_input_as_handled()
		_move_selection(0, 1)
		return

	if event.is_action_pressed("player_nitro"):
		get_viewport().set_input_as_handled()
		_toggle_ready(0)
		return

	if event.is_action_pressed("player_two_accelerate"):
		get_viewport().set_input_as_handled()
		_move_selection(1, -1)
		return

	if event.is_action_pressed("player_two_brake"):
		get_viewport().set_input_as_handled()
		_move_selection(1, 1)
		return

	if event.is_action_pressed("player_two_nitro"):
		get_viewport().set_input_as_handled()
		_toggle_ready(1)


func _update_layout() -> void:
	var is_narrow := size.x < 1280.0
	_header_row.vertical = size.x < 1040.0
	_content_row.vertical = is_narrow
	_footer_row.vertical = size.x < 980.0
	_menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _header_row.vertical else 0
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _footer_row.vertical else 0
	_title.add_theme_font_size_override("font_size", 36 if is_narrow else 42)


func _on_player_ready_button_pressed(player_index: int) -> void:
	_toggle_ready(player_index)


func _on_start_pressed() -> void:
	if not _can_start_race():
		return

	screen_change_requested.emit(
		"race_session",
		{
			"mode": "local_coop",
			"player_car_id": String(_cars[int(_player_states[0]["selection_index"])].get("id", "urban_racer")),
			"player_two_car_id": String(_cars[int(_player_states[1]["selection_index"])].get("id", "dodge_challenger_srt")),
		}
	)


func _on_menu_pressed() -> void:
	screen_change_requested.emit("main_menu", {})
