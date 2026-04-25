extends Control

const CarCatalog = preload("res://scripts/data/car_catalog.gd")
const UIPalette = preload("res://scripts/ui/ui_palette.gd")

signal screen_change_requested(screen_name: String, context: Dictionary)

var _garage_entries: Array[Dictionary] = []
var _roster_buttons: Array[Button] = []
var _selected_index := 0

@onready var _header_row: BoxContainer = $RootLayout/HeaderRow
@onready var _content_row: BoxContainer = $RootLayout/ContentRow
@onready var _header_tag: Label = $RootLayout/HeaderRow/HeaderTag
@onready var _back_button: Button = $RootLayout/HeaderRow/BackButton
@onready var _preview_stage: PanelContainer = $RootLayout/ContentRow/PreviewColumn/PreviewStage
@onready var _stats_card: PanelContainer = $RootLayout/ContentRow/PreviewColumn/StatsCard
@onready var _status_badge: PanelContainer = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/StageTopRow/StatusBadge
@onready var _status_value: Label = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/StageTopRow/StatusBadge/StatusPadding/StatusValue
@onready var _selected_role: Label = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/StageTopRow/SelectedRole
@onready var _selected_name: Label = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/SelectedName
@onready var _selected_description: Label = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/SelectedDescription
@onready var _preview_backdrop: ColorRect = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/PreviewArea/PreviewCar/PreviewBackdrop
@onready var _accent_stripe: ColorRect = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/PreviewArea/PreviewCar/AccentStripe
@onready var _body: ColorRect = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/PreviewArea/PreviewCar/Body
@onready var _cabin: ColorRect = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/PreviewArea/PreviewCar/Cabin
@onready var _roster_card: PanelContainer = $RootLayout/ContentRow/RosterCard
@onready var _roster_title: Label = $RootLayout/ContentRow/RosterCard/RosterPadding/RosterColumn/RosterTitle
@onready var _roster_list: VBoxContainer = $RootLayout/ContentRow/RosterCard/RosterPadding/RosterColumn/RosterList
@onready var _stats_title: Label = $RootLayout/ContentRow/PreviewColumn/StatsCard/StatsPadding/StatsColumn/StatsTitle
@onready var _stats_hint: Label = $RootLayout/ContentRow/PreviewColumn/StatsCard/StatsPadding/StatsColumn/StatsHint
@onready var _stat_list: VBoxContainer = $RootLayout/ContentRow/PreviewColumn/StatsCard/StatsPadding/StatsColumn/StatList


func _ready() -> void:
	_garage_entries = CarCatalog.get_prototype_cars()
	_apply_styles()
	_connect_actions()
	_build_roster_buttons()
	_render_selected_car()
	resized.connect(_update_layout)
	_update_layout()


func _apply_styles() -> void:
	UIPalette.apply_panel_style(_preview_stage, UIPalette.SURFACE_PANEL, UIPalette.ACCENT_ORANGE, 30, 2)
	UIPalette.apply_panel_style(_stats_card, UIPalette.SURFACE_CARD, UIPalette.ACCENT_GOLD, 24, 2)
	UIPalette.apply_panel_style(_roster_card, UIPalette.SURFACE_PANEL, UIPalette.ACCENT_CYAN, 30, 2)

	_header_tag.add_theme_color_override("font_color", UIPalette.ACCENT_ORANGE)
	_status_value.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_selected_name.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_selected_role.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_selected_description.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_roster_title.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_stats_title.add_theme_color_override("font_color", UIPalette.ACCENT_GOLD)
	_stats_hint.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)

	UIPalette.apply_button_style(
		_back_button,
		Color(0.164706, 0.2, 0.270588, 0.95),
		Color(0.235294, 0.286275, 0.372549, 1.0),
		Color(0.133333, 0.160784, 0.219608, 1.0)
	)


func _connect_actions() -> void:
	_back_button.pressed.connect(_on_back_pressed)


func _update_layout() -> void:
	var is_narrow := size.x < 1220.0
	_header_row.vertical = size.x < 980.0
	_content_row.vertical = false if size.x >= 1280.0 else is_narrow
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _header_row.vertical else 0
	_roster_card.custom_minimum_size = Vector2(280 if not _content_row.vertical else 0, 0)
	_roster_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _content_row.vertical else 0
	_preview_stage.custom_minimum_size = Vector2(0, 280 if size.y < 760.0 else 300)
	_selected_name.add_theme_font_size_override("font_size", 30 if is_narrow else 34)


func _build_roster_buttons() -> void:
	for child in _roster_list.get_children():
		child.queue_free()

	_roster_buttons.clear()

	for index in range(_garage_entries.size()):
		var entry: Dictionary = _garage_entries[index]
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.text = entry["name"]
		button.pressed.connect(_on_roster_button_pressed.bind(index))
		_roster_list.add_child(button)
		_roster_buttons.append(button)

	_refresh_roster_button_styles()


func _render_selected_car() -> void:
	var entry: Dictionary = _garage_entries[_selected_index]
	var accent_color: Color = entry["accent_color"]
	var badge_color: Color = accent_color if not entry["locked"] else Color(0.278431, 0.313726, 0.392157, 1.0)

	UIPalette.apply_panel_style(_status_badge, badge_color, accent_color, 18, 2)

	_status_value.text = entry["status_text"]
	_selected_role.text = entry["role"]
	_selected_name.text = entry["name"]
	_selected_description.text = entry["description"]
	_preview_backdrop.color = entry["body_color"].darkened(0.55)
	_accent_stripe.color = accent_color
	_body.color = entry["body_color"]
	_cabin.color = entry["cabin_color"]

	_rebuild_stat_rows(entry["stats"], accent_color)
	_refresh_roster_button_styles()


func _rebuild_stat_rows(stats: Dictionary, accent_color: Color) -> void:
	for child in _stat_list.get_children():
		child.queue_free()

	for stat_key in ["engine", "nitro", "tires", "transmission"]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var header := HBoxContainer.new()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var stat_name := Label.new()
		stat_name.text = _format_stat_name(stat_key)
		stat_name.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
		stat_name.add_theme_font_size_override("font_size", 16)
		stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var stat_value := Label.new()
		stat_value.text = "%d" % int(stats.get(stat_key, 0))
		stat_value.add_theme_color_override("font_color", accent_color)
		stat_value.add_theme_font_size_override("font_size", 16)

		var progress_bar := ProgressBar.new()
		progress_bar.show_percentage = false
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = int(stats.get(stat_key, 0))
		progress_bar.custom_minimum_size = Vector2(0, 18)
		UIPalette.apply_progress_bar_style(progress_bar, accent_color)

		header.add_child(stat_name)
		header.add_child(stat_value)
		row.add_child(header)
		row.add_child(progress_bar)
		_stat_list.add_child(row)


func _refresh_roster_button_styles() -> void:
	for index in range(_roster_buttons.size()):
		var entry: Dictionary = _garage_entries[index]
		var button := _roster_buttons[index]
		var accent_color: Color = entry["accent_color"]
		var is_selected := index == _selected_index

		if entry["locked"]:
			UIPalette.apply_button_style(
				button,
				Color(0.211765, 0.239216, 0.305882, 0.95),
				Color(0.266667, 0.301961, 0.380392, 1.0),
				Color(0.184314, 0.207843, 0.258824, 1.0)
			)
		elif is_selected:
			UIPalette.apply_button_style(
				button,
				accent_color.darkened(0.18),
				accent_color,
				accent_color.darkened(0.08)
			)
		else:
			UIPalette.apply_button_style(
				button,
				UIPalette.SURFACE_CARD,
				UIPalette.SURFACE_CARD_ALT,
				UIPalette.SURFACE_PANEL
			)

		button.text = entry["name"]


func _format_stat_name(stat_key: String) -> String:
	var labels := {
		"engine": "Двигатель",
		"nitro": "Нитро",
		"tires": "Шины",
		"transmission": "Трансмиссия",
	}
	return labels.get(stat_key, stat_key.capitalize())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_roster_button_pressed(index: int) -> void:
	_selected_index = index
	_render_selected_car()


func _on_back_pressed() -> void:
	screen_change_requested.emit("main_menu", {})
